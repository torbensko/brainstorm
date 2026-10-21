import Foundation

// Only the protocol fields Brainstorm consumes. Unknown notification types are ignored.
struct CodexEmpty: Codable, Sendable {}
struct CodexAccount: Codable, Sendable {
    let type: String
    let email: String?
    let planType: String?
}
struct CodexAccountResponse: Codable, Sendable { let account: CodexAccount? }
struct CodexAccountParams: Encodable, Sendable { let refreshToken: Bool }
struct CodexCapabilities: Codable, Sendable { let imageGeneration: Bool }
struct CodexLoginParams: Encodable, Sendable { let type = "chatgpt" }
struct CodexLogin: Codable, Sendable { let type: String; let loginId: String; let authUrl: String }
struct CodexLoginCancel: Encodable, Sendable { let loginId: String }
struct CodexThreadReference: Codable, Sendable { let id: String }
struct CodexThreadResponse: Codable, Sendable { let thread: CodexThreadReference }
struct CodexThreadID: Encodable, Sendable { let threadId: String }
struct CodexThreadStart: Encodable, Sendable {
    let cwd: String
    let modelProvider = "openai"
    let approvalPolicy = "never"
    let sandbox = "workspace-write"
    let ephemeral = true
    let serviceName = "brainstorm"
    let developerInstructions: String
}
struct CodexInput: Codable, Sendable {
    let type: String
    let text: String?
    let path: String?
    let text_elements: [CodexEmpty]?
    static func text(_ value: String) -> Self { .init(type: "text", text: value, path: nil, text_elements: []) }
    static func image(_ url: URL) -> Self { .init(type: "localImage", text: nil, path: url.path, text_elements: nil) }
}
struct CodexSandbox: Encodable, Sendable {
    let type = "workspaceWrite"
    let writableRoots: [String]
    let networkAccess = false
    let excludeTmpdirEnvVar = true
    let excludeSlashTmp = true
}
struct CodexTurnStart: Encodable, Sendable {
    let threadId: String
    let input: [CodexInput]
    let effort = "low"
    let approvalPolicy = "never"
    let sandboxPolicy: CodexSandbox
}
struct CodexInterrupt: Encodable, Sendable { let threadId: String; let turnId: String }
struct CodexTurnResponse: Codable, Sendable { let turn: CodexTurn }
struct CodexTurn: Codable, Sendable {
    let id: String
    let status: String
    let items: [CodexItem]?
    let error: CodexMessageError?
}
struct CodexMessageError: Codable, Sendable { let message: String }
struct CodexItem: Codable, Sendable {
    let type: String
    let id: String?
    let status: String?
    let result: String?
    let savedPath: String?
    let text: String?
    let failure: CodexImageFailure?
}
struct CodexImageFailure: Codable, Sendable { let type: String; let resetsAt: Double? }
struct CodexEventParams: Decodable, Sendable {
    let threadId: String?
    let item: CodexItem?
    let turn: CodexTurn?
    let success: Bool?
    let error: String?
}
enum CodexEvent: Sendable {
    case item(String, CodexItem), turn(String, CodexTurn), login(Bool, String?), stopped(String)
}

protocol CodexRPC: Sendable {
    var events: AsyncStream<CodexEvent> { get }
    func request<P: Encodable & Sendable, R: Decodable & Sendable>(_ method: String, _ params: P, as: R.Type) async throws -> R
    func close() async
}
