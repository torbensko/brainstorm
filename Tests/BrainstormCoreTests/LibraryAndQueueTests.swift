import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import BrainstormCore

struct Fixture: Sendable {
    let root: URL
    let library: LibraryStore
    let assets: AssetStore
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-test-\(UUID())")
        library = try LibraryStore(url: root.appendingPathComponent("library.sqlite"))
        assets = try AssetStore(root: root.appendingPathComponent("Images"))
    }
    func batch(count: Int = 4) async throws -> GenerationBatch {
        let project = Project(title: "Test", prompt: "An orange circle")
        try await library.saveProject(project)
        let id = UUID()
        return GenerationBatch(id: id, projectID: project.id, prompt: project.prompt, resolvedPrompt: project.prompt,
                               settings: GenerationSettings(provider: .openAI, model: "gpt-image-2.5-flare"), jobs: (0..<count).map { GenerationJob(batchID: id, position: $0) })
    }
}

func testPNG() throws -> Data {
    let context = try #require(CGContext(data: nil, width: 24, height: 24, bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

struct TestCredentials: CredentialStore {
    func credential(for provider: ProviderID) async throws -> ProviderCredential { .apiKey("test-key") }
}

actor RecordingProvider: ImageProvider {
    var active = 0
    var maximumActive = 0
    var calls = 0
    var referenceCounts: [Int] = []
    let delay: Duration
    let failFirst: Bool
    let ignoreCancellation: Bool
    init(delay: Duration = .milliseconds(60), failFirst: Bool = false, ignoreCancellation: Bool = false) {
        self.delay = delay; self.failFirst = failFirst; self.ignoreCancellation = ignoreCancellation
    }
    func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput {
        calls += 1; let call = calls
        active += 1; maximumActive = max(maximumActive, active); referenceCounts.append(references.count)
        defer { active -= 1 }
        do { try await Task.sleep(for: delay) } catch { if !ignoreCancellation { throw error } }
        if failFirst && call == 1 { throw BrainstormError.response("One intentional failure") }
        return ImageOutput(data: try testPNG(), requestID: "test-\(call)", inputTokens: 10, outputTokens: 100)
    }
    func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String { "Refined: \(prompt)" }
}

func waitUntil(_ condition: @escaping @Sendable () async throws -> Bool) async throws {
    for _ in 0..<250 {
        if try await condition() { return }
        try await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("Timed out waiting for queue state")
    throw BrainstormError.response("Test timed out")
}

@Test func queueBoundsConcurrencyAndPersistsEveryImage() async throws {
    let fixture = try Fixture()
    let provider = RecordingProvider()
    let queue = GenerationQueue(library: fixture.library, assets: fixture.assets, credentials: TestCredentials(),
                                providers: ProviderRegistry(providers: [.openAI: provider]), concurrency: 2)
    let batch = try await fixture.batch(count: 6)
    try await queue.submit(batch)
    try await waitUntil { try await fixture.library.batch(id: batch.id)?.isActive == false }
    let result = try #require(try await fixture.library.batch(id: batch.id))
    #expect(result.completedCount == 6)
    #expect(await provider.maximumActive == 2)
    #expect(result.jobs.allSatisfy { $0.requestID != nil && $0.outputTokens == 100 })
    let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    #expect(try await reopened.snapshot().assets.count == 6)
    #expect(try await reopened.batch(id: batch.id)?.completedCount == 6)
    let files = try await fixture.library.snapshot().assets
    for asset in files { #expect(FileManager.default.fileExists(atPath: fixture.assets.url(for: asset).path)) }
}

@Test func oneFailureDoesNotLoseSiblingsAndRetryOnlyRequestsOneImage() async throws {
    let fixture = try Fixture()
    let provider = RecordingProvider(failFirst: true)
    let queue = GenerationQueue(library: fixture.library, assets: fixture.assets, credentials: TestCredentials(), providers: ProviderRegistry(providers: [.openAI: provider]))
    let batch = try await fixture.batch()
    try await queue.submit(batch)
    try await waitUntil { try await fixture.library.batch(id: batch.id)?.isActive == false }
    let failed = try #require(try await fixture.library.batch(id: batch.id)?.jobs.first { $0.status == .failed })
    #expect(try await fixture.library.batch(id: batch.id)?.completedCount == 3)
    try await queue.retry(failed.id)
    try await waitUntil { try await fixture.library.batch(id: batch.id)?.completedCount == 4 }
    #expect(await provider.calls == 5)
    #expect(try await fixture.library.batch(id: batch.id)?.jobs.first { $0.id == failed.id }?.attempts == 2)
}

@Test func cancellationDiscardsLateResponsesAndAllowsFurtherWork() async throws {
    let fixture = try Fixture()
    let provider = RecordingProvider(delay: .milliseconds(150), ignoreCancellation: true)
    let queue = GenerationQueue(library: fixture.library, assets: fixture.assets, credentials: TestCredentials(), providers: ProviderRegistry(providers: [.openAI: provider]), concurrency: 1)
    let batch = try await fixture.batch(count: 2)
    try await queue.submit(batch)
    try await waitUntil { await provider.calls == 1 }
    try await queue.cancel(batch.jobs[0].id)
    try await waitUntil { try await fixture.library.batch(id: batch.id)?.isActive == false }
    let saved = try #require(try await fixture.library.batch(id: batch.id))
    #expect(saved.jobs[0].status == .cancelled)
    #expect(saved.jobs[0].assetID == nil)
    #expect(saved.jobs[1].status == .succeeded)
    #expect(try await fixture.library.snapshot().assets.count == 1)
}

@Test func restartPreservesSuccessAndMarksUnfinishedWorkInterrupted() async throws {
    let fixture = try Fixture()
    let batch = try await fixture.batch(count: 3)
    try await fixture.library.addBatch(batch)
    try await fixture.library.startJob(batch.jobs[0].id)
    let output = ImageOutput(data: try testPNG())
    let asset = try await fixture.assets.save(data: output.data, projectID: batch.projectID, name: "Finished.png")
    #expect(try await fixture.library.finishJob(batch.jobs[0].id, asset: asset, result: output))
    try await fixture.library.startJob(batch.jobs[1].id)
    let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    try await reopened.recoverInterrupted()
    let saved = try #require(try await reopened.batch(id: batch.id))
    #expect(saved.jobs.map(\.status) == [.succeeded, .interrupted, .interrupted])
    #expect(saved.jobs[0].assetID == asset.id)
}

@Test func referencesAreOrderedAndCannotLeakBetweenProjects() async throws {
    let fixture = try Fixture()
    let initial = try await fixture.batch(count: 1)
    let first = try await fixture.assets.save(data: testPNG(), projectID: initial.projectID, name: "Selected.png")
    let second = try await fixture.assets.save(data: testPNG(), projectID: initial.projectID, name: "Reference.png")
    try await fixture.library.addAsset(first); try await fixture.library.addAsset(second)
    let id = UUID()
    let batch = GenerationBatch(id: id, projectID: initial.projectID, prompt: "Make it green", resolvedPrompt: "Make it green",
                                parentAssetID: second.id, referenceIDs: [second.id, first.id], settings: GenerationSettings(provider: .openAI, model: "gpt-image-2.5-flare"), jobs: [GenerationJob(batchID: id, position: 0)])
    try await fixture.library.addBatch(batch)
    #expect(try await fixture.library.batch(id: id)?.referenceIDs == [second.id, first.id])
    let foreign = Project(title: "Another concept", referenceIDs: [first.id])
    await #expect(throws: (any Error).self) { try await fixture.library.saveProject(foreign) }
    #expect(try await fixture.library.snapshot().projects.count == 1)
}

@Test func deletingProjectCleansRelatedDatabaseRows() async throws {
    let fixture = try Fixture()
    let batch = try await fixture.batch(count: 1)
    let asset = try await fixture.assets.save(data: testPNG(), projectID: batch.projectID, name: "Reference.png")
    try await fixture.library.addAsset(asset)
    var project = try #require(try await fixture.library.snapshot().projects.first)
    project.parentAssetID = asset.id; project.referenceIDs = [asset.id]
    try await fixture.library.saveProject(project)
    let id = UUID()
    let edit = GenerationBatch(id: id, projectID: project.id, prompt: "Edit", resolvedPrompt: "Edit", parentAssetID: asset.id,
                               referenceIDs: [asset.id], settings: GenerationSettings(provider: .openAI, model: "gpt-image-2.5-flare"), jobs: [GenerationJob(batchID: id, position: 0)])
    try await fixture.library.addBatch(edit)
    try await fixture.library.deleteProject(project.id)
    let snapshot = try await fixture.library.snapshot()
    #expect(snapshot.projects.isEmpty && snapshot.assets.isEmpty && snapshot.batches.isEmpty)
}

@Test func invalidImageIsRejectedAndPromptHistoryIsBounded() async throws {
    let fixture = try Fixture()
    await #expect(throws: (any Error).self) { try await fixture.assets.save(data: Data("bad image".utf8), projectID: UUID(), name: "bad.png") }
    #expect(throws: (any Error).self) { try PromptBuilder.imagePrompt(" ", parentPrompt: nil) }
    #expect(throws: (any Error).self) { try PromptBuilder.imagePrompt("change", parentPrompt: String(repeating: "a", count: 31_000)) }
    let prompt = try PromptBuilder.imagePrompt("Make the sun blue", parentPrompt: "A red sun over the sea")
    #expect(prompt.contains("first attached image"))
    #expect(prompt.contains("Make the sun blue"))
}

@Test func cancelledQueuedJobCannotBeClaimed() async throws {
    let fixture = try Fixture()
    let batch = try await fixture.batch(count: 1)
    try await fixture.library.addBatch(batch)
    try await fixture.library.cancelJob(batch.jobs[0].id)
    #expect(try await fixture.library.startJob(batch.jobs[0].id) == false)
    let saved = try #require(try await fixture.library.batch(id: batch.id))
    #expect(saved.jobs[0].status == .cancelled && saved.jobs[0].attempts == 0)
}

@Test func importedReferenceSurvivesMovingItsSource() async throws {
    let fixture = try Fixture()
    let batch = try await fixture.batch(count: 1)
    let source = fixture.root.appendingPathComponent("reference.png")
    try testPNG().write(to: source)
    let asset = try await fixture.assets.importFile(source, projectID: batch.projectID, name: "Original reference.png")
    try await fixture.library.addAsset(asset)
    try FileManager.default.removeItem(at: source)
    let reference = try await fixture.assets.reference(asset)
    #expect(!reference.data.isEmpty && reference.mimeType == "image/png")
    #expect(asset.name == "Original reference.png")
    #expect(FileManager.default.fileExists(atPath: fixture.assets.url(for: asset, thumbnail: true).path))
}

actor RateLimitedProvider: ImageProvider {
    private(set) var calls = 0
    func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput {
        calls += 1
        if calls == 1 { throw ProviderHTTPError(status: 429, message: "Rate limited", retryAfter: 0, mayRetry: true) }
        return ImageOutput(data: try testPNG())
    }
    func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String { prompt }
}

@Test func rateLimitedJobRetriesWithoutDuplicatingItsSlot() async throws {
    let fixture = try Fixture()
    let provider = RateLimitedProvider()
    let queue = GenerationQueue(library: fixture.library, assets: fixture.assets, credentials: TestCredentials(), providers: ProviderRegistry(providers: [.openAI: provider]))
    let batch = try await fixture.batch(count: 1)
    try await queue.submit(batch)
    try await waitUntil { try await fixture.library.batch(id: batch.id)?.completedCount == 1 }
    let saved = try #require(try await fixture.library.batch(id: batch.id))
    #expect(saved.jobs.count == 1 && saved.jobs[0].attempts == 2)
    #expect(await provider.calls == 2)
}
