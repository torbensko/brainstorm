import Foundation
import Testing
@testable import BrainstormCore

actor FakeCodex: CodexRPC {
    private struct Input: Decodable { let threadId: String; let input: [CodexInput] }
    nonisolated let events: AsyncStream<CodexEvent>
    private let continuation: AsyncStream<CodexEvent>.Continuation
    var accountType = "chatgpt"
    var supportsImages = true
    var hold = false
    var missingImage = false
    var quotaFailure = false
    var calls: [(String, Data)] = []
    init() {
        let stream = AsyncStream<CodexEvent>.makeStream()
        events = stream.stream; continuation = stream.continuation
    }
    func configure(account: String = "chatgpt", supportsImages: Bool = true, hold: Bool = false, missingImage: Bool = false, quotaFailure: Bool = false) {
        accountType = account; self.supportsImages = supportsImages; self.hold = hold; self.missingImage = missingImage; self.quotaFailure = quotaFailure
    }
    func request<P: Encodable & Sendable, R: Decodable & Sendable>(_ method: String, _ params: P, as: R.Type) async throws -> R {
        let data = try JSONEncoder().encode(params)
        calls.append((method, data))
        func result<T: Encodable>(_ value: T) throws -> R { try JSONDecoder().decode(R.self, from: JSONEncoder().encode(value)) }
        switch method {
        case "account/read": return try result(CodexAccountResponse(account: CodexAccount(type: accountType, email: nil, planType: "pro")))
        case "modelProvider/capabilities/read": return try result(CodexCapabilities(imageGeneration: supportsImages))
        case "thread/start": return try result(CodexThreadResponse(thread: CodexThreadReference(id: UUID().uuidString)))
        case "turn/start":
            let value = try JSONDecoder().decode(Input.self, from: data)
            let id = UUID().uuidString
            if !hold {
                let textOnly = value.input.first?.text?.hasPrefix("Rewrite") == true
                let item = CodexItem(type: textOnly ? "agentMessage" : "imageGeneration", id: "item-1",
                                     status: quotaFailure ? "failed" : "completed",
                                     result: textOnly || missingImage || quotaFailure ? nil : try testPNG().base64EncodedString(),
                                     savedPath: nil, text: textOnly ? "A concise revised design brief." : nil,
                                     failure: quotaFailure ? CodexImageFailure(type: "usageLimitExceeded", resetsAt: nil) : nil)
                // These can arrive before turn/start's RPC response in the real server.
                continuation.yield(.item(value.threadId, item))
                continuation.yield(.turn(value.threadId, CodexTurn(id: id, status: "completed", items: [], error: nil)))
            }
            return try result(CodexTurnResponse(turn: CodexTurn(id: id, status: "inProgress", items: [], error: nil)))
        case "account/login/start": return try result(CodexLogin(type: "chatgpt", loginId: "login", authUrl: "https://auth.openai.com/authorize"))
        default: return try result(CodexEmpty())
        }
    }
    func stop() { continuation.yield(.stopped("Connection lost")) }
    func close() {}
    func methodCount(_ method: String) -> Int { calls.filter { $0.0 == method }.count }
}

func subscriptionFixture(_ rpc: FakeCodex, timeout: Duration = .seconds(3)) -> (CodexSubscription, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-codex-test-\(UUID())")
    return (CodexSubscription(rpc: rpc, workRoot: root, turnTimeout: timeout), root)
}

@Test func subscriptionRejectsAPIKeyAuthenticationBeforeStartingATurn() async throws {
    let rpc = FakeCodex(); await rpc.configure(account: "apiKey")
    let (provider, _) = subscriptionFixture(rpc)
    await #expect(throws: BrainstormError.self) {
        try await provider.generate(prompt: "Poster", references: [], settings: GenerationSettings(), credential: .chatGPT)
    }
    #expect(await rpc.methodCount("thread/start") == 0)
    await provider.shutdown()
}

@Test func subscriptionImageEventsPreserveReferencesAndCleanTemporaryCopies() async throws {
    let rpc = FakeCodex(); let (provider, root) = subscriptionFixture(rpc)
    let png = try testPNG()
    let output = try await provider.generate(prompt: "Edit selected image", references: [ImageReference(data: png, mimeType: "image/png"), ImageReference(data: png, mimeType: "image/png")], settings: GenerationSettings(), credential: .chatGPT)
    #expect(output.data == png)
    #expect(output.requestID != nil)
    let call = try #require(await rpc.calls.first { $0.0 == "turn/start" })
    struct Input: Decodable { let input: [CodexInput] }
    let values = try JSONDecoder().decode(Input.self, from: call.1).input
    #expect(values.count == 3)
    #expect(values[1].path?.hasSuffix("reference-1.png") == true)
    #expect(values[2].path?.hasSuffix("reference-2.png") == true)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    await provider.shutdown()
}

@Test func subscriptionAllowsIndependentConcurrentImageTurns() async throws {
    let rpc = FakeCodex(); let (provider, _) = subscriptionFixture(rpc)
    async let first = provider.generate(prompt: "First", references: [], settings: GenerationSettings(), credential: .chatGPT)
    async let second = provider.generate(prompt: "Second", references: [], settings: GenerationSettings(), credential: .chatGPT)
    let outputs = try await [first, second]
    #expect(outputs[0].requestID != outputs[1].requestID)
    #expect(await rpc.methodCount("thread/start") == 2)
    await provider.shutdown()
}

@Test func subscriptionPromptRefinementNeverRequestsAnImage() async throws {
    let rpc = FakeCodex(); let (provider, _) = subscriptionFixture(rpc)
    let text = try await provider.refinePrompt("A poster", direction: "Shorter", references: [], credential: .chatGPT)
    #expect(text == "A concise revised design brief.")
    let call = try #require(await rpc.calls.first { $0.0 == "thread/start" })
    struct Thread: Decodable { let developerInstructions: String }
    #expect(try JSONDecoder().decode(Thread.self, from: call.1).developerInstructions.contains("Never generate images"))
    await provider.shutdown()
}

@Test func subscriptionCancellationInterruptsOnlyItsOwnTurn() async throws {
    let rpc = FakeCodex(); await rpc.configure(hold: true)
    let (provider, _) = subscriptionFixture(rpc)
    let task = Task { try await provider.generate(prompt: "Image", references: [], settings: GenerationSettings(), credential: .chatGPT) }
    try await waitUntil { await rpc.methodCount("turn/start") == 1 }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    try await waitUntil { await rpc.methodCount("turn/interrupt") == 1 }
    await provider.shutdown()
}

@Test func subscriptionTimeoutAndDisconnectFailPendingRequests() async throws {
    let rpc = FakeCodex(); await rpc.configure(hold: true)
    let (provider, _) = subscriptionFixture(rpc, timeout: .milliseconds(100))
    await #expect(throws: BrainstormError.self) {
        try await provider.generate(prompt: "Image", references: [], settings: GenerationSettings(), credential: .chatGPT)
    }
    let task = Task { try await provider.generate(prompt: "Image", references: [], settings: GenerationSettings(), credential: .chatGPT) }
    try await waitUntil { await rpc.methodCount("turn/start") == 2 }
    await rpc.stop()
    await #expect(throws: BrainstormError.self) { try await task.value }
    await provider.shutdown()
}

@Test func subscriptionQuotaAndEmptyResultsNeverFallBackToAPI() async throws {
    for quota in [false, true] {
        let rpc = FakeCodex(); await rpc.configure(missingImage: !quota, quotaFailure: quota)
        let (provider, _) = subscriptionFixture(rpc)
        do {
            _ = try await provider.generate(prompt: "Image", references: [], settings: GenerationSettings(), credential: .chatGPT)
            Issue.record("Expected a failed image")
        } catch {
            #expect(error.localizedDescription.contains(quota ? "allowance" : "no generated image"))
        }
        #expect(await rpc.methodCount("turn/start") == 1)
        await provider.shutdown()
    }
}

@Test func subscriptionAndAPIAuthenticationCannotBeInterchanged() async throws {
    #expect(throws: BrainstormError.self) { try ProviderCredential.chatGPT.apiKey }
    #expect(CodexAppServer.environment(["OPENAI_API_KEY": "secret", "CODEX_API_KEY": "secret", "PATH": "/bin"]) == ["PATH": "/bin"])
    let rpc = FakeCodex(); let (provider, _) = subscriptionFixture(rpc)
    await #expect(throws: BrainstormError.self) {
        try await provider.generate(prompt: "Image", references: [], settings: GenerationSettings(), credential: .apiKey("secret"))
    }
    #expect(await rpc.methodCount("turn/start") == 0)
    await provider.shutdown()
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["BRAINSTORM_LIVE_SUBSCRIPTION_TEST"] == "1"))
func liveSubscriptionImageEditAndPromptRefinement() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-live-\(UUID())")
    let provider = CodexSubscription(workRoot: root)
    let status = try await provider.status()
    #expect(status.connected && status.imageGeneration)
    let text = try await provider.refinePrompt("Teal circle, ivory background", direction: "Make the brief precise in one sentence", references: [], credential: .chatGPT)
    #expect(!text.isEmpty)
    let reference = try Data(contentsOf: URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["BRAINSTORM_LIVE_REFERENCE"])))
    let output = try await provider.generate(prompt: "Edit the first attached image. Change the teal circle to warm terracotta. Preserve the ivory background and simple layout.", references: [ImageReference(data: reference, mimeType: "image/png")], settings: GenerationSettings(), credential: .chatGPT)
    let assetStore = try AssetStore(root: root.appendingPathComponent("result"))
    let asset = try await assetStore.save(data: output.data, projectID: UUID(), name: "Subscription edit.png")
    #expect(asset.width > 0 && asset.height > 0)
    print("Subscription image verified: \(assetStore.url(for: asset).path)")
    await provider.shutdown()
}
