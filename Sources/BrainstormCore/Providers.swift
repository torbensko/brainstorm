import Foundation

public struct ImageReference: Sendable {
    public let data: Data
    public let mimeType: String
    public init(data: Data, mimeType: String) { self.data = data; self.mimeType = mimeType }
    var dataURL: String { "data:\(mimeType);base64,\(data.base64EncodedString())" }
}

public struct ImageOutput: Sendable {
    public let data: Data
    public let requestID: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public init(data: Data, requestID: String? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.data = data; self.requestID = requestID; self.inputTokens = inputTokens; self.outputTokens = outputTokens
    }
}

public protocol ImageProvider: Sendable {
    func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput
    func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String
}

public struct HTTPResult: Sendable {
    public let data: Data
    public let status: Int
    public let requestID: String?
    public let retryAfter: TimeInterval?
    public init(data: Data, status: Int, requestID: String? = nil, retryAfter: TimeInterval? = nil) {
        self.data = data; self.status = status; self.requestID = requestID; self.retryAfter = retryAfter
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResult
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 240
        configuration.timeoutIntervalForResource = 360
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }
    public func send(_ request: URLRequest) async throws -> HTTPResult {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BrainstormError.response("No HTTP response received.") }
        let retryHeader = http.value(forHTTPHeaderField: "retry-after")
        let retryAfter: TimeInterval?
        if let seconds = retryHeader.flatMap(TimeInterval.init) { retryAfter = seconds }
        else if let retryHeader {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
            retryAfter = formatter.date(from: retryHeader).map { max(0, $0.timeIntervalSinceNow) }
        } else { retryAfter = nil }
        return HTTPResult(data: data, status: http.statusCode, requestID: http.value(forHTTPHeaderField: "x-request-id"), retryAfter: retryAfter)
    }
}

public struct ProviderHTTPError: LocalizedError, Sendable {
    public let status: Int
    public let message: String
    public let retryAfter: TimeInterval?
    public let mayRetry: Bool
    public var errorDescription: String? { message }
}

public struct ProviderClient: Sendable {
    private struct ErrorBody: Decodable { struct Detail: Decodable { let message: String; let code: String? }; let error: Detail }
    private struct MessageBody: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
    let transport: any HTTPTransport
    public init(transport: any HTTPTransport = URLSessionTransport()) { self.transport = transport }
    func post<Body: Encodable & Sendable>(_ body: Body, to url: URL, apiKey: String, provider: ProviderID) async throws -> HTTPResult {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider == .openAI ? "Bearer \(apiKey)" : apiKey,
                         forHTTPHeaderField: provider == .openAI ? "Authorization" : "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(body)
        if provider == .gemini, let size = request.httpBody?.count, size > 20_000_000 {
            throw BrainstormError.invalid("These references exceed Gemini’s inline request limit. Use fewer or smaller images.")
        }
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            let error = try? JSONDecoder().decode(ErrorBody.self, from: response.data)
            let message = error?.error.message ?? (try? JSONDecoder().decode(MessageBody.self, from: response.data).error.message)
            let detail = String((message ?? "\(provider.title) returned HTTP \(response.status).").prefix(800))
            throw ProviderHTTPError(status: response.status, message: detail, retryAfter: response.retryAfter,
                                    mayRetry: response.status == 429 && error?.error.code != "insufficient_quota" && error?.error.code != "billing_hard_limit_reached")
        }
        return response
    }
}

public struct OpenAIProvider: ImageProvider {
    private let client: ProviderClient
    public init(client: ProviderClient = ProviderClient()) { self.client = client }
    public func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput {
        struct ImageInput: Encodable, Sendable { let image_url: String }
        struct Request: Encodable, Sendable {
            let model: String; let prompt: String; let size: String; let quality: String
            let n = 1; let output_format = "png"; let images: [ImageInput]?
        }
        struct Response: Decodable {
            struct Item: Decodable { let b64_json: String? }
            struct Usage: Decodable { let input_tokens: Int?; let output_tokens: Int? }
            let data: [Item]; let usage: Usage?
        }
        try settings.validate()
        guard references.count <= ProviderID.openAI.maximumReferences else { throw BrainstormError.invalid("OpenAI supports at most 16 reference images.") }
        let body = Request(model: settings.model, prompt: prompt, size: settings.shape.openAISize,
                           quality: settings.quality.openAIValue, images: references.isEmpty ? nil : references.map { ImageInput(image_url: $0.dataURL) })
        let path = references.isEmpty ? "generations" : "edits"
        let response = try await client.post(body, to: URL(string: "https://api.openai.com/v1/images/\(path)")!, apiKey: try credential.apiKey, provider: .openAI)
        let decoded = try JSONDecoder().decode(Response.self, from: response.data)
        guard let base64 = decoded.data.first?.b64_json, let image = Data(base64Encoded: base64), !image.isEmpty else {
            throw BrainstormError.response("OpenAI returned no image. Try a more specific prompt.")
        }
        return ImageOutput(data: image, requestID: response.requestID, inputTokens: decoded.usage?.input_tokens, outputTokens: decoded.usage?.output_tokens)
    }
    public func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String {
        struct Part: Encodable, Sendable { let type: String; var text: String?; var image_url: String? }
        struct Message: Encodable, Sendable { let role = "user"; let content: [Part] }
        struct Request: Encodable, Sendable { let model = ProviderID.openAI.textModel; let instructions: String; let input: [Message]; let store = false }
        struct Response: Decodable {
            struct Output: Decodable {
                struct Part: Decodable { let type: String; let text: String? }
                let type: String; let content: [Part]?
            }
            let output: [Output]
        }
        var content = [Part(type: "input_text", text: "Current brief:\n\(prompt)\n\nRequested revision:\n\(direction)")]
        content += references.map { Part(type: "input_image", image_url: $0.dataURL) }
        let response = try await client.post(Request(instructions: refinementInstructions, input: [Message(content: content)]),
                                             to: URL(string: "https://api.openai.com/v1/responses")!, apiKey: try credential.apiKey, provider: .openAI)
        let decoded = try JSONDecoder().decode(Response.self, from: response.data)
        let result = decoded.output.filter { $0.type == "message" }.flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw BrainstormError.response("OpenAI returned no revised prompt.") }
        return result
    }
}

private let refinementInstructions = """
You edit image-generation briefs. Return only a complete, standalone revised prompt, without quotation marks or commentary.
Preserve the user's intent, exact required wording, and constraints. Apply their requested revision.
Use attached images as reference context when supplied. Do not invent requirements or generate an image.
"""

public struct GeminiProvider: ImageProvider {
    private let client: ProviderClient
    public init(client: ProviderClient = ProviderClient()) { self.client = client }
    private struct Part: Codable, Sendable {
        struct InlineData: Codable, Sendable { let mimeType: String; let data: String }
        var text: String?; var inlineData: InlineData?; var thought: Bool?
    }
    private struct Content: Codable, Sendable { var role: String?; let parts: [Part] }
    private struct Request: Encodable, Sendable {
        struct Config: Encodable, Sendable {
            struct ImageConfig: Encodable, Sendable { let aspectRatio: String; let imageSize: String }
            let responseModalities: [String]; var imageConfig: ImageConfig?
        }
        let contents: [Content]; let generationConfig: Config; var systemInstruction: Content?
    }
    private struct Response: Decodable {
        struct Candidate: Decodable { let content: Content?; let finishReason: String? }
        struct Feedback: Decodable { let blockReason: String? }
        struct Usage: Decodable { let promptTokenCount: Int?; let candidatesTokenCount: Int? }
        let candidates: [Candidate]?; let promptFeedback: Feedback?; let usageMetadata: Usage?
    }
    public func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput {
        try settings.validate()
        guard references.count <= ProviderID.gemini.maximumReferences else { throw BrainstormError.invalid("Gemini supports at most 14 reference images.") }
        let body = Request(contents: [Content(role: "user", parts: parts(prompt, references))],
                           generationConfig: .init(responseModalities: ["TEXT", "IMAGE"], imageConfig: .init(aspectRatio: settings.shape.aspectRatio, imageSize: settings.quality.geminiSize)))
        let response = try await send(body, model: settings.model, apiKey: try credential.apiKey)
        let decoded = try JSONDecoder().decode(Response.self, from: response.data)
        let finalParts = decoded.candidates?.first?.content?.parts.filter { $0.thought != true } ?? []
        guard let imagePart = finalParts.last(where: { $0.inlineData?.mimeType.hasPrefix("image/") == true }),
              let base64 = imagePart.inlineData?.data, let image = Data(base64Encoded: base64), !image.isEmpty else {
            let explanation = finalParts.compactMap(\.text).joined(separator: " ")
            throw BrainstormError.response(explanation.isEmpty ? "Gemini returned no image (\(decoded.promptFeedback?.blockReason ?? decoded.candidates?.first?.finishReason ?? "empty response"))." : explanation)
        }
        return ImageOutput(data: image, requestID: response.requestID,
                           inputTokens: decoded.usageMetadata?.promptTokenCount, outputTokens: decoded.usageMetadata?.candidatesTokenCount)
    }
    public func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String {
        let body = Request(contents: [Content(role: "user", parts: parts("Current brief:\n\(prompt)\n\nRequested revision:\n\(direction)", references))],
                           generationConfig: .init(responseModalities: ["TEXT"]),
                           systemInstruction: Content(parts: [Part(text: refinementInstructions)]))
        let response = try await send(body, model: ProviderID.gemini.textModel, apiKey: try credential.apiKey)
        let decoded = try JSONDecoder().decode(Response.self, from: response.data)
        let text = decoded.candidates?.first?.content?.parts.filter { $0.thought != true }.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw BrainstormError.response("Gemini returned no revised prompt.") }
        return text
    }
    private func parts(_ prompt: String, _ references: [ImageReference]) -> [Part] {
        references.map { Part(inlineData: .init(mimeType: $0.mimeType, data: $0.data.base64EncodedString())) } + [Part(text: prompt)]
    }
    private func send(_ body: Request, model: String, apiKey: String) async throws -> HTTPResult {
        // Each call is a standalone edit with explicit image references, never reconstructed model turns.
        try await client.post(body, to: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!, apiKey: apiKey, provider: .gemini)
    }
}

public struct ProviderRegistry: Sendable {
    private let providers: [ProviderID: any ImageProvider]
    public init(providers: [ProviderID: any ImageProvider] = [.openAI: OpenAIProvider(), .gemini: GeminiProvider()]) { self.providers = providers }
    public func provider(_ id: ProviderID) throws -> any ImageProvider {
        guard let provider = providers[id] else { throw BrainstormError.invalid("\(id.title) is unavailable.") }
        return provider
    }
}
