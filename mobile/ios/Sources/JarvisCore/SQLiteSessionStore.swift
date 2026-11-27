import Foundation
import CSQLite

public struct SQLiteSessionRecord: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let snapshot: Data
    public init(id: UUID, title: String, createdAt: Date, snapshot: Data) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.snapshot = snapshot
    }
}

public struct SQLiteSessionArchive: Equatable, Sendable {
    public let activeID: UUID
    public let sessions: [SQLiteSessionRecord]
    public init(activeID: UUID, sessions: [SQLiteSessionRecord]) {
        self.activeID = activeID; self.sessions = sessions
    }
}

public enum SQLiteStoreError: Error, Equatable {
    case database(Int32), unsupportedVersion(Int32), invalidArchive, invalidSchema, alreadyImported, missingArchive
}

private final class SQLiteConnection {
    let pointer: OpaquePointer
    init(_ pointer: OpaquePointer) { self.pointer = pointer }
    deinit { sqlite3_close_v2(pointer) }
}

/// Storage foundation only. Never point at a live JSON repository or delete its files.
/// The connection is owned by this instance and automatically closed on release.
@MainActor public final class SQLiteSessionStore {
    private var connection: SQLiteConnection?
    private var db: OpaquePointer? { connection?.pointer }
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        guard url.isFileURL else { throw SQLiteStoreError.invalidSchema }
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK, let handle else {
            if let handle { sqlite3_close_v2(handle) }
            throw SQLiteStoreError.database(rc)
        }
        connection = SQLiteConnection(handle)
        do {
            try check(sqlite3_busy_timeout(handle, 3000))
            try exec("PRAGMA foreign_keys=ON; PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL;")
            try transaction {
                let version = try scalar("PRAGMA user_version")
                if version == 0 {
                    guard try scalar("SELECT count(*) FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'") == 0 else { throw SQLiteStoreError.invalidSchema }
                    try exec("""
                    CREATE TABLE sessions(id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, created REAL NOT NULL, position INTEGER NOT NULL UNIQUE, snapshot BLOB NOT NULL);
                    CREATE TABLE selection(singleton INTEGER PRIMARY KEY CHECK(singleton=1), active_id TEXT NOT NULL REFERENCES sessions(id));
                    PRAGMA user_version=1;
                    """)
                } else if version != 1 { throw SQLiteStoreError.unsupportedVersion(version) }
                guard try scalar("SELECT count(*) FROM sqlite_schema WHERE type='table' AND name IN ('sessions','selection')") == 2 else { throw SQLiteStoreError.invalidSchema }
                guard try scalar("SELECT count(*) FROM pragma_foreign_key_check") == 0 else { throw SQLiteStoreError.invalidSchema }
                // Validate column names and schema readability even when empty.
                try statement("SELECT id,title,created,position,snapshot FROM sessions LIMIT 0") { _ in }
                try statement("SELECT singleton,active_id FROM selection LIMIT 0") { _ in }
                let count = try scalar("SELECT count(*) FROM sessions")
                let selected = try scalar("SELECT count(*) FROM selection")
                guard (count == 0 && selected == 0) || (count > 0 && selected == 1) else { throw SQLiteStoreError.invalidSchema }
                if count > 0 { _ = try readArchive() }
            }
        } catch { close(); throw error }
    }
    public func close() {
        connection = nil
    }

    public func importArchive(_ archive: SQLiteSessionArchive) throws {
        try validate(archive)
        try transaction {
            guard try scalar("SELECT count(*) FROM sessions") == 0,
                  try scalar("SELECT count(*) FROM selection") == 0 else { throw SQLiteStoreError.alreadyImported }
            for (position, record) in archive.sessions.enumerated() {
                try statement("INSERT INTO sessions(id,title,created,position,snapshot) VALUES(?,?,?,?,?)") { s in
                    try bind(record.id.uuidString, to: s, at: 1)
                    try bind(record.title, to: s, at: 2)
                    try check(sqlite3_bind_double(s, 3, record.createdAt.timeIntervalSinceReferenceDate))
                    try check(sqlite3_bind_int64(s, 4, Int64(position)))
                    try record.snapshot.withUnsafeBytes { bytes in
                        try check(sqlite3_bind_blob(s, 5, bytes.baseAddress, Int32(bytes.count), Self.transient))
                    }
                    try done(s)
                }
            }
            try statement("INSERT INTO selection(singleton,active_id) VALUES(1,?)") { s in
                try bind(archive.activeID.uuidString, to: s, at: 1); try done(s)
            }
            guard try readArchive() == archive else { throw SQLiteStoreError.invalidArchive }
        }
    }

    public func loadArchive() throws -> SQLiteSessionArchive {
        try transaction { try readArchive() }
    }

    private func validate(_ archive: SQLiteSessionArchive) throws {
        let ids = Set(archive.sessions.map(\.id))
        guard !ids.isEmpty, ids.count == archive.sessions.count, ids.contains(archive.activeID) else { throw SQLiteStoreError.invalidArchive }
        for record in archive.sessions {
            guard (1...80).contains(record.title.count), record.title == record.title.trimmingCharacters(in: .whitespacesAndNewlines),
                  !record.title.contains("\u{0000}"), record.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  !record.snapshot.isEmpty, record.snapshot.count <= Int(Int32.max) else { throw SQLiteStoreError.invalidArchive }
            do { _ = try JSONDecoder().decode(Snapshot.self, from: record.snapshot) }
            catch { throw SQLiteStoreError.invalidArchive }
        }
    }
    private func readArchive() throws -> SQLiteSessionArchive {
        let id: UUID = try statement("SELECT active_id FROM selection WHERE singleton=1") { s in
            let rc = sqlite3_step(s)
            if rc == SQLITE_DONE { throw SQLiteStoreError.missingArchive }
            guard rc == SQLITE_ROW else { throw SQLiteStoreError.database(rc) }
            guard let value = try text(s, 0).flatMap(UUID.init(uuidString:)) else { throw SQLiteStoreError.invalidSchema }
            try done(s); return value
        }
        let records: [SQLiteSessionRecord] = try statement("SELECT id,title,created,position,snapshot FROM sessions ORDER BY position") { s in
            var result: [SQLiteSessionRecord] = []
            while true {
                let rc = sqlite3_step(s)
                if rc == SQLITE_DONE { break }
                guard rc == SQLITE_ROW else { throw SQLiteStoreError.database(rc) }
                guard let id = try text(s, 0).flatMap(UUID.init(uuidString:)), let title = try text(s, 1),
                      sqlite3_column_type(s, 2) == SQLITE_FLOAT, sqlite3_column_int64(s, 3) == Int64(result.count),
                      sqlite3_column_type(s, 4) == SQLITE_BLOB, let blob = sqlite3_column_blob(s, 4) else { throw SQLiteStoreError.invalidSchema }
                let bytes = Data(bytes: blob, count: Int(sqlite3_column_bytes(s, 4)))
                result.append(.init(id: id, title: title, createdAt: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(s, 2)), snapshot: bytes))
            }
            return result
        }
        let archive = SQLiteSessionArchive(activeID: id, sessions: records)
        try validate(archive); return archive
    }
    private func text(_ s: OpaquePointer, _ index: Int32) throws -> String? {
        guard sqlite3_column_type(s, index) == SQLITE_TEXT, let ptr = sqlite3_column_text(s, index) else { return nil }
        guard let value = String(bytes: UnsafeBufferPointer(start: ptr, count: Int(sqlite3_column_bytes(s, index))), encoding: .utf8) else { throw SQLiteStoreError.invalidSchema }
        return value
    }
    private func bind(_ value: String, to s: OpaquePointer, at index: Int32) throws {
        try value.withCString { try check(sqlite3_bind_text(s, index, $0, -1, Self.transient)) }
    }
    private func check(_ rc: Int32) throws { guard rc == SQLITE_OK else { throw SQLiteStoreError.database(rc) } }
    private func done(_ s: OpaquePointer) throws {
        let rc = sqlite3_step(s); guard rc == SQLITE_DONE else { throw SQLiteStoreError.database(rc) }
    }
    private func exec(_ sql: String) throws {
        guard let db else { throw SQLiteStoreError.database(SQLITE_MISUSE) }
        try check(sqlite3_exec(db, sql, nil, nil, nil))
    }
    private func statement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard let db else { throw SQLiteStoreError.database(SQLITE_MISUSE) }
        var s: OpaquePointer?
        try check(sqlite3_prepare_v2(db, sql, -1, &s, nil))
        guard let s else { throw SQLiteStoreError.invalidSchema }
        defer { sqlite3_finalize(s) }; return try body(s)
    }
    private func scalar(_ sql: String) throws -> Int32 {
        try statement(sql) { s in
            let rc = sqlite3_step(s); guard rc == SQLITE_ROW else { throw SQLiteStoreError.database(rc) }
            let value = sqlite3_column_int(s, 0); try done(s); return value
        }
    }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        do { let result = try body(); try exec("COMMIT"); return result }
        catch { try? exec("ROLLBACK"); throw error }
    }
}
