import Foundation

/// Matches Blint's native app-server route: Codex owns sign-in and token renewal.
actor CodexAppServer: CodexRPC {
    nonisolated let events: AsyncStream<CodexEvent>
    private let continuation: AsyncStream<CodexEvent>.Continuation
    private let binary: URL?
    private var process: Process?
    private var input: FileHandle?
    private var reader: Task<Void, Never>?
    private var starting: Task<Void, Error>?
    private var buffer = Data()
    private var nextID = 1
    private struct Pending {
        let complete: @Sendable (Result<Data, Error>) -> Void
        let timeout: Task<Void, Never>
    }
    private var pending: [Int: Pending] = [:]

    init(binary: URL? = nil) {
        self.binary = binary
        let stream = AsyncStream<CodexEvent>.makeStream()
        events = stream.stream; continuation = stream.continuation
    }

    static func environment(_ source: [String: String]) -> [String: String] {
        source.filter { !["OPENAI_API_KEY", "CODEX_API_KEY"].contains($0.key) }
    }
    static func executable() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["BRAINSTORM_CODEX_BINARY"] {
            guard FileManager.default.isExecutableFile(atPath: explicit) else {
                throw BrainstormError.invalid("BRAINSTORM_CODEX_BINARY does not point to an executable.")
            }
            return URL(fileURLWithPath: explicit)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ] + (env["PATH"] ?? "").split(separator: ":").map { "\($0)/codex" }
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw BrainstormError.invalid("Install ChatGPT or the Codex CLI on this Mac to use your ChatGPT subscription.")
        }
        return URL(fileURLWithPath: path)
    }

    func request<P: Encodable & Sendable, R: Decodable & Sendable>(_ method: String, _ params: P, as: R.Type) async throws -> R {
        try await start()
        return try await send(method, params, as: R.self)
    }
    private func start() async throws {
        if let starting { return try await starting.value }
        if process != nil { return }
        let task = Task { try await self.launch() }
        starting = task
        defer { starting = nil }
        try await task.value
    }
    private func launch() async throws {
        let child = Process()
        child.executableURL = try binary ?? Self.executable()
        child.arguments = ["app-server", "--stdio", "-c", "model_provider=\"openai\""]
        child.environment = Self.environment(ProcessInfo.processInfo.environment)
        let stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout
        // Protocol errors are surfaced through stdout; diagnostic logs may contain private context.
        child.standardError = FileHandle.nullDevice
        try child.run()
        process = child; input = stdin.fileHandleForWriting; buffer.removeAll()
        let handle = stdout.fileHandleForReading
        reader = Task.detached { [weak self] in
            while !Task.isCancelled {
                let data = handle.availableData
                if data.isEmpty { break }
                await self?.receive(data)
            }
            await self?.exited(child)
        }
        struct Initialize: Encodable, Sendable {
            struct Client: Encodable, Sendable { let name = "brainstorm"; let title = "Brainstorm"; let version = "2.1" }
            struct Capabilities: Encodable, Sendable { let experimentalApi = true; let requestAttestation = false }
            let clientInfo = Client(); let capabilities = Capabilities()
        }
        do {
            let _: CodexEmpty = try await send("initialize", Initialize(), as: CodexEmpty.self)
            try write(Data("{\"method\":\"initialized\"}\n".utf8))
        } catch { close(); throw error }
    }
    private struct Request<P: Encodable>: Encodable { let id: Int; let method: String; let params: P }
    private struct Response<R: Decodable>: Decodable { let result: R?; let error: CodexMessageError? }
    private func send<P: Encodable & Sendable, R: Decodable & Sendable>(_ method: String, _ params: P, as: R.Type) async throws -> R {
        try Task.checkCancellation()
        let id = nextID; nextID += 1
        let data = try JSONEncoder().encode(Request(id: id, method: method, params: params)) + Data([10])
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiter in
                let timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(60)) }
                    catch { return }
                    await self?.fail(id, error: BrainstormError.response("Codex did not respond to \(method). Try reconnecting in Settings."))
                }
                pending[id] = Pending(complete: { result in
                    do {
                        let response = try JSONDecoder().decode(Response<R>.self, from: result.get())
                        if let error = response.error { throw BrainstormError.response(error.message) }
                        guard let value = response.result else { throw BrainstormError.response("Codex returned an empty response to \(method).") }
                        waiter.resume(returning: value)
                    } catch { waiter.resume(throwing: error) }
                }, timeout: timeout)
                do { try write(data) } catch { fail(id, error: error) }
            }
        } onCancel: { Task { await self.fail(id, error: CancellationError()) } }
    }
    private func write(_ data: Data) throws {
        guard let input else { throw BrainstormError.response("Codex is not connected.") }
        try input.write(contentsOf: data)
    }
    private struct Header: Decodable { let id: RPCID?; let method: String? }
    private enum RPCID: Codable {
        case number(Int), string(String)
        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let number = try? value.decode(Int.self) { self = .number(number) }
            else { self = .string(try value.decode(String.self)) }
        }
        func encode(to encoder: any Encoder) throws {
            var value = encoder.singleValueContainer()
            switch self { case .number(let n): try value.encode(n); case .string(let s): try value.encode(s) }
        }
    }
    private struct Notification: Decodable { let params: CodexEventParams }
    private func receive(_ data: Data) {
        buffer.append(data)
        guard buffer.count <= 100_000_000 else { disconnect("Codex returned an oversized response."); return }
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
            do {
                let header = try JSONDecoder().decode(Header.self, from: line)
                if let id = header.id {
                    if let method = header.method {
                        // This app never grants extra tool permissions or executes client tools.
                        struct Rejection: Encodable { let id: RPCID; let error: RejectionError }
                        struct RejectionError: Encodable { let code = -32601; let message: String }
                        try write(JSONEncoder().encode(Rejection(id: id, error: RejectionError(message: "Brainstorm does not support \(method)."))) + Data([10]))
                    } else if case .number(let id) = id, let call = pending.removeValue(forKey: id) {
                        call.timeout.cancel(); call.complete(.success(line))
                    }
                    continue
                }
                guard let method = header.method, ["item/completed", "turn/completed", "account/login/completed"].contains(method) else { continue }
                let params = try JSONDecoder().decode(Notification.self, from: line).params
                if method == "item/completed", let thread = params.threadId, let item = params.item { continuation.yield(.item(thread, item)) }
                if method == "turn/completed", let thread = params.threadId, let turn = params.turn { continuation.yield(.turn(thread, turn)) }
                if method == "account/login/completed" { continuation.yield(.login(params.success == true, params.error)) }
            } catch { disconnect("Could not read the Codex response: \(error.localizedDescription)"); return }
        }
    }
    private func fail(_ id: Int, error: Error) {
        guard let call = pending.removeValue(forKey: id) else { return }
        call.timeout.cancel(); call.complete(.failure(error))
    }
    private func exited(_ child: Process) {
        guard process === child else { return }
        disconnect("The Codex connection closed. Retry the interrupted image or reconnect in Settings.")
    }
    private func disconnect(_ message: String) {
        close(); continuation.yield(.stopped(message))
    }
    func close() {
        let child = process; process = nil
        input = nil; reader?.cancel(); reader = nil
        if child?.isRunning == true { child?.terminate() }
        for id in Array(pending.keys) { fail(id, error: BrainstormError.response("Codex connection closed.")) }
    }
}
