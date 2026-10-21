import Foundation
import CSQLite

enum SQLValue {
    case text(String), number(Double), null
    static func id(_ value: UUID) -> SQLValue { .text(value.uuidString) }
    static func optionalID(_ value: UUID?) -> SQLValue { value.map { .id($0) } ?? .null }
    static func optionalText(_ value: String?) -> SQLValue { value.map { .text($0) } ?? .null }
    static func optionalInt(_ value: Int?) -> SQLValue { value.map { .number(Double($0)) } ?? .null }
}

struct SQLRow {
    let values: [String: SQLValue]
    func string(_ name: String) throws -> String {
        guard case .text(let value) = values[name] else { throw BrainstormError.storage("Invalid library field: \(name)") }
        return value
    }
    func optionalString(_ name: String) throws -> String? {
        if case .null = values[name] { return nil }
        return try string(name)
    }
    func number(_ name: String) throws -> Double {
        guard case .number(let value) = values[name] else { throw BrainstormError.storage("Invalid library field: \(name)") }
        return value
    }
    func int(_ name: String) throws -> Int { Int(try number(name)) }
    func optionalInt(_ name: String) throws -> Int? {
        if case .null = values[name] { return nil }
        return try int(name)
    }
    func id(_ name: String) throws -> UUID {
        guard let value = UUID(uuidString: try string(name)) else { throw BrainstormError.storage("Invalid library identifier.") }
        return value
    }
    func optionalID(_ name: String) throws -> UUID? {
        guard let value = try optionalString(name) else { return nil }
        guard let id = UUID(uuidString: value) else { throw BrainstormError.storage("Invalid library identifier.") }
        return id
    }
    func date(_ name: String) throws -> Date { Date(timeIntervalSince1970: try number(name)) }
}

// Confined to LibraryStore's actor after initialization.
final class SQLiteConnection: @unchecked Sendable {
    private var handle: OpaquePointer?
    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let detail = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open database."
            if let handle { sqlite3_close(handle) }
            handle = nil
            throw BrainstormError.storage(detail)
        }
        sqlite3_busy_timeout(handle, 5_000)
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }
    deinit { if let handle { sqlite3_close(handle) } }

    @discardableResult
    func execute(_ sql: String, _ bindings: [SQLValue] = []) throws -> [SQLRow] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            let code: Int32
            switch value {
            case .text(let text): code = sqlite3_bind_text(statement, position, text, -1, transient)
            case .number(let number): code = sqlite3_bind_double(statement, position, number)
            case .null: code = sqlite3_bind_null(statement, position)
            }
            guard code == SQLITE_OK else { throw failure() }
        }
        var rows: [SQLRow] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_DONE: return rows
            case SQLITE_ROW:
                var values: [String: SQLValue] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    switch sqlite3_column_type(statement, index) {
                    case SQLITE_NULL: values[name] = .null
                    case SQLITE_INTEGER, SQLITE_FLOAT: values[name] = .number(sqlite3_column_double(statement, index))
                    default: values[name] = .text(String(cString: sqlite3_column_text(statement, index)))
                    }
                }
                rows.append(SQLRow(values: values))
            default: throw failure()
            }
        }
    }
    func transaction<T>(_ action: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let value = try action()
            try execute("COMMIT")
            return value
        } catch {
            do { try execute("ROLLBACK") } catch { throw BrainstormError.storage("Could not roll back a library transaction: \(error.localizedDescription)") }
            throw error
        }
    }
    private func failure() -> BrainstormError {
        .storage(handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Database unavailable.")
    }
}
