import Foundation

public enum ProviderID: String, Codable, CaseIterable, Sendable, Identifiable {
    case chatGPT, openAI, gemini
    public var id: String { rawValue }
    public var title: String { switch self { case .chatGPT: "ChatGPT subscription"; case .openAI: "OpenAI API"; case .gemini: "Google Gemini" } }
    public var models: [ImageModel] {
        switch self {
        case .chatGPT: [ImageModel(id: "codex-native-image", title: "ChatGPT subscription")]
        case .openAI: [
            ImageModel(id: "gpt-image-2.5-flare", title: "GPT Image 2.5 · Flare"),
            ImageModel(id: "gpt-image-2.5-sunburst", title: "GPT Image 2.5 · Sunburst"),
            ImageModel(id: "gpt-image-2", title: "GPT Image 2")
        ]
        case .gemini: [
            ImageModel(id: "gemini-nano-banana-2.1", title: "Nano Banana 2.1"),
            ImageModel(id: "gemini-3-pro-image", title: "Nano Banana Pro")
        ]
        }
    }
    public var textModel: String { self == .openAI ? "gpt-6-luna" : "gemini-2.5-flash" }
    public var maximumReferences: Int { self == .gemini ? 14 : 16 }
}

public struct ImageModel: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
}

public enum ImageShape: String, CaseIterable, Codable, Sendable, Identifiable {
    case square, landscape, portrait
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var openAISize: String {
        switch self { case .square: "1024x1024"; case .landscape: "1536x1024"; case .portrait: "1024x1536" }
    }
    public var aspectRatio: String {
        switch self { case .square: "1:1"; case .landscape: "3:2"; case .portrait: "2:3" }
    }
}

public enum ImageQuality: String, CaseIterable, Codable, Sendable, Identifiable {
    case draft, standard, high
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var openAIValue: String {
        switch self { case .draft: "low"; case .standard: "medium"; case .high: "high" }
    }
    public var geminiSize: String {
        switch self { case .draft: "1K"; case .standard: "2K"; case .high: "4K" }
    }
}

public struct GenerationSettings: Codable, Equatable, Sendable {
    public var provider: ProviderID
    public var model: String
    public var shape: ImageShape
    public var quality: ImageQuality
    public init(provider: ProviderID = .chatGPT, model: String = "codex-native-image",
                shape: ImageShape = .square, quality: ImageQuality = .draft) {
        self.provider = provider; self.model = model; self.shape = shape; self.quality = quality
    }
    public func validate() throws {
        guard provider.models.contains(where: { $0.id == model }) else {
            throw BrainstormError.invalid("Choose a supported model for \(provider.title).")
        }
    }
}

public struct Project: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var prompt: String
    public var parentAssetID: UUID?
    public var referenceIDs: [UUID]
    public let createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), title: String = "Untitled concept", prompt: String = "",
                parentAssetID: UUID? = nil, referenceIDs: [UUID] = [], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.prompt = prompt; self.parentAssetID = parentAssetID
        self.referenceIDs = referenceIDs; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct Asset: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let name: String
    public let filename: String
    public let thumbnailFilename: String
    public let mimeType: String
    public let width: Int
    public let height: Int
    public let createdAt: Date
    public init(id: UUID = UUID(), projectID: UUID, name: String, filename: String,
                thumbnailFilename: String, mimeType: String, width: Int, height: Int, createdAt: Date = .now) {
        self.id = id; self.projectID = projectID; self.name = name; self.filename = filename
        self.thumbnailFilename = thumbnailFilename; self.mimeType = mimeType
        self.width = width; self.height = height; self.createdAt = createdAt
    }
}

public enum JobStatus: String, Codable, Sendable {
    case queued, running, succeeded, failed, cancelled, interrupted
    public var isActive: Bool { self == .queued || self == .running }
    public var canRetry: Bool { self == .failed || self == .cancelled || self == .interrupted }
    public var title: String { rawValue.capitalized }
}

public struct GenerationJob: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let batchID: UUID
    public let position: Int
    public var status: JobStatus
    public var assetID: UUID?
    public var error: String?
    public var attempts: Int
    public var requestID: String?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public init(id: UUID = UUID(), batchID: UUID, position: Int, status: JobStatus = .queued,
                assetID: UUID? = nil, error: String? = nil, attempts: Int = 0,
                requestID: String? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.id = id; self.batchID = batchID; self.position = position; self.status = status
        self.assetID = assetID; self.error = error; self.attempts = attempts
        self.requestID = requestID; self.inputTokens = inputTokens; self.outputTokens = outputTokens
    }
}

public struct GenerationBatch: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let prompt: String
    public let resolvedPrompt: String
    public let parentAssetID: UUID?
    public let referenceIDs: [UUID]
    public let settings: GenerationSettings
    public let createdAt: Date
    public var jobs: [GenerationJob]
    public var isActive: Bool { jobs.contains { $0.status.isActive } }
    public var completedCount: Int { jobs.filter { $0.status == .succeeded }.count }
    public init(id: UUID = UUID(), projectID: UUID, prompt: String, resolvedPrompt: String,
                parentAssetID: UUID? = nil, referenceIDs: [UUID] = [], settings: GenerationSettings,
                createdAt: Date = .now, jobs: [GenerationJob] = []) {
        self.id = id; self.projectID = projectID; self.prompt = prompt; self.resolvedPrompt = resolvedPrompt
        self.parentAssetID = parentAssetID; self.referenceIDs = referenceIDs
        self.settings = settings; self.createdAt = createdAt; self.jobs = jobs
    }
}

public struct LibrarySnapshot: Sendable {
    public let projects: [Project]
    public let batches: [GenerationBatch]
    public let assets: [Asset]
}

public enum BrainstormError: LocalizedError, Sendable {
    case invalid(String), storage(String), missingKey(ProviderID), response(String)
    public var errorDescription: String? {
        switch self {
        case .invalid(let message), .storage(let message), .response(let message): message
        case .missingKey(let provider): "Add your \(provider.title) API key in Settings to continue."
        }
    }
}

public enum PromptBuilder {
    public static func imagePrompt(_ prompt: String, parentPrompt: String?) throws -> String {
        let instruction = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { throw BrainstormError.invalid("Describe what you want to create.") }
        let result: String
        if let parentPrompt {
            result = """
            Edit the first attached image. It is the exact design selected by the user.
            Preserve everything not affected by the requested change. Any additional images are supplementary references.
            Previous design instructions (context only):
            \(parentPrompt)

            New change, which takes precedence:
            \(instruction)
            """
        } else {
            result = instruction
        }
        guard result.count <= 30_000 else {
            throw BrainstormError.invalid("This revision history is too long. Start a fresh concept with the selected image attached.")
        }
        return result
    }
    public static func title(from prompt: String) -> String {
        let words = prompt.split(whereSeparator: \.isWhitespace).prefix(7).joined(separator: " ")
        return words.isEmpty ? "Untitled concept" : String(words.prefix(70))
    }
}
