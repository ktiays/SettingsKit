import Foundation
import SQLite3
import Synchronization

/// A settings storage backend that persists values in an SQLite database.
///
/// The backend stores each setting as a row of a key-value table with the
/// columns `key`, `kind`, and `value`. The `kind` column records the
/// representation case, so values keep their exact type. The database uses
/// write-ahead logging, and the table is created when the backend opens it.
///
/// The backend reports every change made through the same instance. Share one
/// instance between stores, rather than opening the same database file more
/// than once, so that all stores observe each other's changes.
public final class SQLiteSettingsStorage: SettingsStorage {
    /// The location of an SQLite settings database.
    public enum Location: Sendable, Hashable {
        /// A database file at the specified file URL.
        ///
        /// The backend creates the file and its parent directory if needed.
        case file(URL)

        /// A private, temporary database that exists only in memory.
        case inMemory
    }

    /// The location of the database.
    public let location: Location

    /// The name of the table that holds settings.
    public let tableName: String

    private let connection: Mutex<SQLiteConnection>
    private let notifier = SettingsStorageChangeNotifier()

    /// Opens or creates an SQLite settings database.
    ///
    /// - Parameters:
    ///   - location: The location of the database.
    ///   - tableName: The name of the settings table. The name may contain
    ///     only ASCII letters, digits, and underscores, and must not begin
    ///     with a digit.
    /// - Throws: ``SQLiteSettingsStorageError`` if the database cannot be
    ///   opened or prepared, or a file system error if the parent directory
    ///   cannot be created.
    public init(location: Location, tableName: String = "settings") throws {
        guard Self.isValidIdentifier(tableName) else {
            throw SQLiteSettingsStorageError(
                code: SQLITE_MISUSE,
                message: "The table name \"\(tableName)\" is not a valid identifier."
            )
        }
        let path: String
        switch location {
        case .file(let url):
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            path = url.path(percentEncoded: false)
        case .inMemory:
            path = ":memory:"
        }
        self.location = location
        self.tableName = tableName
        connection = Mutex(try SQLiteConnection(path: path, tableName: tableName))
    }

    /// Opens or creates an SQLite settings database file.
    ///
    /// - Parameters:
    ///   - url: The file URL of the database.
    ///   - tableName: The name of the settings table.
    /// - Throws: An error if the database cannot be opened or prepared.
    public convenience init(url: URL, tableName: String = "settings") throws {
        try self.init(location: .file(url), tableName: tableName)
    }

    public func value(forKey key: String) throws -> SettingRepresentation? {
        try connection.withLock {
            try $0.value(forKey: key)
        }
    }

    public func setValue(_ value: SettingRepresentation, forKey key: String) throws {
        try connection.withLock {
            try $0.setValue(value, forKey: key)
        }
        notifier.notifyObservers(of: .keys([key]))
    }

    public func removeValue(forKey key: String) throws {
        try connection.withLock {
            try $0.removeValue(forKey: key)
        }
        notifier.notifyObservers(of: .keys([key]))
    }

    public func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        notifier.observeChanges(handler)
    }

    private static func isValidIdentifier(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first, !("0"..."9").contains(first) else {
            return false
        }
        return name.unicodeScalars.allSatisfy {
            $0.isASCII && ($0 == "_" || CharacterSet.alphanumerics.contains($0))
        }
    }
}

/// An error that the SQLite settings storage backend reports.
public struct SQLiteSettingsStorageError: Error, Hashable, CustomStringConvertible {
    /// The SQLite result code.
    public let code: Int32

    /// A description of the failure.
    public let message: String

    /// Creates an SQLite settings storage error.
    ///
    /// - Parameters:
    ///   - code: The SQLite result code.
    ///   - message: A description of the failure.
    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    public var description: String {
        "SQLite error \(code): \(message)"
    }
}

// MARK: - Connection

/// The database connection and prepared statements, protected by a mutex.
private final class SQLiteConnection {
    private enum Kind: String {
        case bool
        case integer
        case double
        case string
        case data
    }

    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let database: OpaquePointer
    private let selectStatement: OpaquePointer
    private let upsertStatement: OpaquePointer
    private let deleteStatement: OpaquePointer

    init(path: String, tableName: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map {
                String(cString: sqlite3_errmsg($0))
            } ?? "The database could not be opened."
            sqlite3_close_v2(handle)
            throw SQLiteSettingsStorageError(code: result, message: message)
        }
        var preparedStatements: [OpaquePointer] = []
        do {
            sqlite3_busy_timeout(handle, 5_000)
            try Self.execute("PRAGMA journal_mode = WAL", in: handle)
            try Self.execute(
                """
                CREATE TABLE IF NOT EXISTS "\(tableName)" (
                    key TEXT PRIMARY KEY NOT NULL,
                    kind TEXT NOT NULL,
                    value
                ) WITHOUT ROWID
                """,
                in: handle
            )
            for sql in [
                "SELECT kind, value FROM \"\(tableName)\" WHERE key = ?1",
                """
                INSERT INTO "\(tableName)" (key, kind, value) VALUES (?1, ?2, ?3)
                ON CONFLICT (key) DO UPDATE SET kind = excluded.kind, value = excluded.value
                """,
                "DELETE FROM \"\(tableName)\" WHERE key = ?1",
            ] {
                preparedStatements.append(try Self.prepare(sql, in: handle))
            }
        } catch {
            for statement in preparedStatements {
                sqlite3_finalize(statement)
            }
            sqlite3_close_v2(handle)
            throw error
        }
        database = handle
        selectStatement = preparedStatements[0]
        upsertStatement = preparedStatements[1]
        deleteStatement = preparedStatements[2]
    }

    deinit {
        sqlite3_finalize(selectStatement)
        sqlite3_finalize(upsertStatement)
        sqlite3_finalize(deleteStatement)
        sqlite3_close_v2(database)
    }

    func value(forKey key: String) throws -> SettingRepresentation? {
        let statement = selectStatement
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        try bind(key, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            break
        case SQLITE_DONE:
            return nil
        case let result:
            throw error(code: result)
        }
        guard let kindText = sqlite3_column_text(statement, 0),
              let kind = Kind(rawValue: String(cString: kindText)) else {
            throw SettingsStorageError.unsupportedValue(key: key)
        }
        switch kind {
        case .bool:
            return .bool(sqlite3_column_int64(statement, 1) != 0)
        case .integer:
            return .integer(Int(sqlite3_column_int64(statement, 1)))
        case .double:
            return .double(sqlite3_column_double(statement, 1))
        case .string:
            let count = Int(sqlite3_column_bytes(statement, 1))
            guard let text = sqlite3_column_text(statement, 1) else {
                return .string("")
            }
            return .string(String(decoding: UnsafeBufferPointer(start: text, count: count), as: UTF8.self))
        case .data:
            let count = Int(sqlite3_column_bytes(statement, 1))
            guard let bytes = sqlite3_column_blob(statement, 1) else {
                return .data(Data())
            }
            return .data(Data(bytes: bytes, count: count))
        }
    }

    func setValue(_ value: SettingRepresentation, forKey key: String) throws {
        let statement = upsertStatement
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        try bind(key, at: 1, in: statement)
        let kind: Kind
        let result: Int32
        switch value {
        case .bool(let value):
            kind = .bool
            result = sqlite3_bind_int64(statement, 3, value ? 1 : 0)
        case .integer(let value):
            kind = .integer
            result = sqlite3_bind_int64(statement, 3, Int64(value))
        case .double(let value):
            kind = .double
            result = sqlite3_bind_double(statement, 3, value)
        case .string(let value):
            kind = .string
            result = bindText(value, at: 3, in: statement)
        case .data(let value):
            kind = .data
            result = value.withUnsafeBytes { buffer in
                sqlite3_bind_blob64(
                    statement,
                    3,
                    buffer.baseAddress,
                    sqlite3_uint64(buffer.count),
                    Self.transientDestructor
                )
            }
        }
        try check(result)
        try bind(kind.rawValue, at: 2, in: statement)
        try step(statement)
    }

    func removeValue(forKey key: String) throws {
        let statement = deleteStatement
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        try bind(key, at: 1, in: statement)
        try step(statement)
    }

    // MARK: Helpers

    private func bind(_ text: String, at index: Int32, in statement: OpaquePointer) throws {
        try check(bindText(text, at: index, in: statement))
    }

    private func bindText(_ text: String, at index: Int32, in statement: OpaquePointer) -> Int32 {
        // The explicit byte count preserves embedded null characters.
        let count = sqlite3_uint64(text.utf8.count)
        return text.withCString {
            sqlite3_bind_text64(statement, index, $0, count, Self.transientDestructor, UInt8(SQLITE_UTF8))
        }
    }

    private func step(_ statement: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw error(code: result)
        }
    }

    private func check(_ result: Int32) throws {
        guard result == SQLITE_OK else {
            throw error(code: result)
        }
    }

    private func error(code: Int32) -> SQLiteSettingsStorageError {
        SQLiteSettingsStorageError(code: code, message: String(cString: sqlite3_errmsg(database)))
    }

    private static func execute(_ sql: String, in database: OpaquePointer) throws {
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw SQLiteSettingsStorageError(code: result, message: String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func prepare(_ sql: String, in database: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v3(database, sql, -1, UInt32(SQLITE_PREPARE_PERSISTENT), &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteSettingsStorageError(code: result, message: String(cString: sqlite3_errmsg(database)))
        }
        return statement
    }
}
