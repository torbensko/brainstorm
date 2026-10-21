import Foundation
import Testing
@testable import BrainstormCore

actor StubTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    let result: HTTPResult
    init(_ json: String, status: Int = 200, retryAfter: Double? = nil) {
        result = HTTPResult(data: Data(json.utf8), status: status, requestID: "req-123", retryAfter: retryAfter)
    }
    func send(_ request: URLRequest) async throws -> HTTPResult { requests.append(request); return result }
}

@Test func openAIGenerationUsesOneImagePerJobAndPreservesUsage() async throws {
    let stub = StubTransport(#"{"data":[{"b64_json":"aW1hZ2U="}],"usage":{"input_tokens":12,"output_tokens":34}}"#)
    let provider = OpenAIProvider(client: ProviderClient(transport: stub))
    let output = try await provider.generate(prompt: "A poster", references: [], settings: GenerationSettings(), apiKey: "secret")
    let request = try #require(await stub.requests.first)
    #expect(request.url?.path == "/v1/images/generations")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["n"] as? Int == 1)
    #expect(json["quality"] as? String == "low")
    #expect(json["images"] == nil)
    #expect(output.inputTokens == 12 && output.outputTokens == 34 && output.requestID == "req-123")
}

@Test func openAIEditingSendsSelectedImageFirstAndAdditionalAttachments() async throws {
    let stub = StubTransport(#"{"data":[{"b64_json":"aW1hZ2U="}]}"#)
    let provider = OpenAIProvider(client: ProviderClient(transport: stub))
    let references = [ImageReference(data: Data("selected".utf8), mimeType: "image/png"), ImageReference(data: Data("reference".utf8), mimeType: "image/jpeg")]
    _ = try await provider.generate(prompt: "Edit", references: references, settings: GenerationSettings(), apiKey: "secret")
    let request = try #require(await stub.requests.first)
    #expect(request.url?.path == "/v1/images/edits")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let images = try #require(json["images"] as? [[String: String]])
    #expect(images.map { $0["image_url"] } == references.map(\.dataURL))
    #expect(json["input_fidelity"] == nil)
}

@Test func promptRefinementParsesResponsesOutputAndNeverCallsImagesAPI() async throws {
    let stub = StubTransport(#"{"output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"A clearer brief"}]}]}"#)
    let provider = OpenAIProvider(client: ProviderClient(transport: stub))
    let output = try await provider.refinePrompt("A brief", direction: "Clearer", references: [], apiKey: "secret")
    #expect(output == "A clearer brief")
    #expect(await stub.requests.first?.url?.path == "/v1/responses")
    let body = try #require(await stub.requests.first?.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["store"] as? Bool == false)
}

@Test func quotaErrorsAreNotAutomaticallyRetried() async throws {
    let stub = StubTransport(#"{"error":{"message":"No credits","code":"insufficient_quota"}}"#, status: 429)
    do {
        _ = try await OpenAIProvider(client: ProviderClient(transport: stub)).generate(prompt: "A", references: [], settings: GenerationSettings(), apiKey: "key")
        Issue.record("Expected a quota failure")
    } catch let error as ProviderHTTPError {
        #expect(!error.mayRetry)
        #expect(error.localizedDescription == "No credits")
    }
}

@Test func rateLimitCarriesRetryAfter() async throws {
    let stub = StubTransport(#"{"error":{"message":"Slow down","code":"rate_limit_exceeded"}}"#, status: 429, retryAfter: 12)
    do {
        _ = try await OpenAIProvider(client: ProviderClient(transport: stub)).generate(prompt: "A", references: [], settings: GenerationSettings(), apiKey: "key")
        Issue.record("Expected a rate limit")
    } catch let error as ProviderHTTPError {
        #expect(error.mayRetry && error.retryAfter == 12)
    }
}

@Test func geminiSkipsThoughtImagesAndUsesStandaloneReferenceTurns() async throws {
    let stub = StubTransport(#"{"candidates":[{"content":{"parts":[{"thought":true,"inlineData":{"mimeType":"image/png","data":"dGhvdWdodA=="}},{"inlineData":{"mimeType":"image/png","data":"ZmluYWw="}}]}}]}"#)
    let provider = GeminiProvider(client: ProviderClient(transport: stub))
    let settings = GenerationSettings(provider: .gemini, model: "gemini-nano-banana-2.1", shape: .portrait, quality: .standard)
    let result = try await provider.generate(prompt: "Edit", references: [ImageReference(data: Data("reference".utf8), mimeType: "image/png")], settings: settings, apiKey: "secret")
    #expect(String(data: result.data, encoding: .utf8) == "final")
    let request = try #require(await stub.requests.first)
    #expect(request.url?.query == nil)
    #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let contents = try #require(json["contents"] as? [[String: Any]])
    #expect(contents.count == 1 && contents[0]["role"] as? String == "user")
    let config = try #require(json["generationConfig"] as? [String: Any])
    let imageConfig = try #require(config["imageConfig"] as? [String: String])
    #expect(imageConfig["imageSize"] == "2K" && imageConfig["aspectRatio"] == "2:3")
}

@Test func emptyImageResponseFailsClearly() async throws {
    let stub = StubTransport(#"{"data":[]}"#)
    await #expect(throws: (any Error).self) {
        try await OpenAIProvider(client: ProviderClient(transport: stub)).generate(prompt: "A", references: [], settings: GenerationSettings(), apiKey: "key")
    }
}
