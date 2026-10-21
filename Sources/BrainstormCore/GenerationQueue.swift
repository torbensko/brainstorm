import Foundation

public enum QueueEvent: Sendable { case changed, error(String) }

public actor GenerationQueue {
    public nonisolated let events: AsyncStream<QueueEvent>
    private let continuation: AsyncStream<QueueEvent>.Continuation
    private let library: LibraryStore
    private let assets: AssetStore
    private let credentials: any CredentialStore
    private let providers: ProviderRegistry
    private var concurrency: Int
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledIDs: Set<UUID> = []
    private var pumping = false

    public init(library: LibraryStore, assets: AssetStore, credentials: any CredentialStore,
                providers: ProviderRegistry = ProviderRegistry(), concurrency: Int = 3) {
        self.library = library; self.assets = assets; self.credentials = credentials
        self.providers = providers; self.concurrency = max(1, min(6, concurrency))
        let stream = AsyncStream<QueueEvent>.makeStream(bufferingPolicy: .bufferingNewest(20))
        events = stream.stream; continuation = stream.continuation
    }
    public func prepare() async throws {
        try await library.recoverInterrupted()
        continuation.yield(.changed)
    }
    public func submit(_ batch: GenerationBatch) async throws {
        _ = try await credentials.credential(for: batch.settings.provider)
        _ = try providers.provider(batch.settings.provider)
        try await library.addBatch(batch)
        continuation.yield(.changed)
        await pump()
    }
    public func cancel(_ id: UUID) async throws {
        cancelledIDs.insert(id)
        try await library.cancelJob(id)
        tasks[id]?.cancel()
        continuation.yield(.changed)
        await pump()
    }
    public func retry(_ id: UUID) async throws {
        guard tasks[id] == nil else { throw BrainstormError.invalid("This request is still stopping. Try again in a moment.") }
        cancelledIDs.remove(id)
        try await library.retryJob(id)
        continuation.yield(.changed)
        await pump()
    }
    public func setConcurrency(_ value: Int) async {
        concurrency = max(1, min(6, value))
        await pump()
    }
    private func pump() async {
        guard !pumping else { return }
        pumping = true
        defer { pumping = false }
        do {
            while tasks.count < concurrency,
                  let (batch, job) = try await library.nextQueued(excluding: Set(tasks.keys)) {
                guard try await library.startJob(job.id), !cancelledIDs.contains(job.id) else { continue }
                tasks[job.id] = Task { await self.execute(batch: batch, job: job) }
                continuation.yield(.changed)
            }
        } catch { continuation.yield(.error(error.localizedDescription)) }
    }
    private func execute(batch: GenerationBatch, job: GenerationJob) async {
        var createdAsset: Asset?
        var committed = false
        do {
            try Task.checkCancellation()
            let provider = try providers.provider(batch.settings.provider)
            let credential = try await credentials.credential(for: batch.settings.provider)
            let storedReferences = try await library.assets(ids: batch.referenceIDs)
            var references: [ImageReference] = []
            for asset in storedReferences { references.append(try await assets.reference(asset)) }
            let output = try await request(provider: provider, batch: batch, job: job, references: references, credential: credential)
            try Task.checkCancellation()
            let asset = try await assets.save(data: output.data, projectID: batch.projectID,
                                               name: "\(PromptBuilder.title(from: batch.prompt)) — \(job.position + 1).png")
            createdAsset = asset
            try Task.checkCancellation()
            committed = try await library.finishJob(job.id, asset: asset, result: output)
        } catch {
            do {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError {
                    try await library.cancelJob(job.id)
                } else {
                    try await library.failJob(job.id, message: error.localizedDescription)
                }
            } catch { continuation.yield(.error("Could not save the request status: \(error.localizedDescription)")) }
        }
        if let createdAsset, !committed {
            do { try await assets.remove(createdAsset) }
            catch { continuation.yield(.error("Could not remove an unused image: \(error.localizedDescription)")) }
        }
        tasks[job.id] = nil
        cancelledIDs.remove(job.id)
        continuation.yield(.changed)
        await pump()
    }
    private func request(provider: any ImageProvider, batch: GenerationBatch, job: GenerationJob,
                         references: [ImageReference], credential: ProviderCredential) async throws -> ImageOutput {
        var retries = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await provider.generate(prompt: batch.resolvedPrompt, references: references, settings: batch.settings, credential: credential)
            } catch let error as ProviderHTTPError where error.mayRetry && retries < 2 {
                let delay = max(1, error.retryAfter ?? (pow(2, Double(retries + 1)) + Double.random(in: 0...1)))
                // Long rate limits and ambiguous failures require an explicit retry, avoiding duplicate spend.
                guard delay <= 60 else { throw error }
                try await Task.sleep(for: .seconds(delay))
                try Task.checkCancellation()
                retries += 1
                try await library.recordRetry(job.id)
            }
        }
    }
}
