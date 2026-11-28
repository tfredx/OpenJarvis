import Foundation
import XCTest
import CSQLite
@testable import JarvisCore

@MainActor final class SQLiteSessionStoreTests: XCTestCase {
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func archive() throws -> SQLiteSessionArchive {
        var one = Snapshot(); one.messages = [Message("user", "synthetic α")]; one.notes = [Note("blue")]
        one.status = .approval; one.pending = Decision("save_memory", "green"); one.steps = 2
        var two = Snapshot(); two.status = .running; two.messages = [Message("user", "synthetic 二")]
        let a = SQLiteSessionRecord(id: UUID(), title: "Café '一'", createdAt: Date(), snapshot: try JSONEncoder().encode(one))
        let b = SQLiteSessionRecord(id: UUID(), title: "Second", createdAt: Date(), snapshot: try JSONEncoder().encode(two))
        return .init(activeID: a.id, sessions: [a,b])
    }
    private func sql(_ url: URL, _ command: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw SQLiteStoreError.invalidSchema }
        defer { sqlite3_close(db) }
        let rc = sqlite3_exec(db, command, nil, nil, nil)
        guard rc == SQLITE_OK else { throw SQLiteStoreError.database(rc) }
    }
    func testExactArchiveRoundTripAndReopen() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3"); let original = try archive()
        let store = try SQLiteSessionStore(url: url)
        XCTAssertThrowsError(try store.loadArchive()) { XCTAssertEqual($0 as? SQLiteStoreError, .missingArchive) }
        try store.importArchive(original); XCTAssertEqual(try store.loadArchive(), original); store.close()
        let reopened = try SQLiteSessionStore(url: url); defer { reopened.close() }
        XCTAssertEqual(try reopened.loadArchive(), original)
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: reopened.loadArchive().sessions[0].snapshot)
        XCTAssertEqual(snapshot.status, .approval); XCTAssertEqual(snapshot.pending?.value, "green"); XCTAssertEqual(snapshot.notes.map(\.text), ["blue"])
    }
    func testInvalidArchiveRejectedWithoutWrites() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SQLiteSessionStore(url: dir.appendingPathComponent("sessions.sqlite3")); defer { store.close() }
        let original = try archive(); let a = original.sessions[0]
        for invalid in [SQLiteSessionArchive(activeID: UUID(), sessions: original.sessions), .init(activeID: a.id, sessions: [a,a]), .init(activeID: a.id, sessions: [.init(id: a.id, title: "bad\u{0000}title", createdAt: a.createdAt, snapshot: a.snapshot)]), .init(activeID: a.id, sessions: [.init(id: a.id, title: "Bad data", createdAt: a.createdAt, snapshot: Data("not JSON".utf8))])] {
            XCTAssertThrowsError(try store.importArchive(invalid)) { XCTAssertEqual($0 as? SQLiteStoreError, .invalidArchive) }
            XCTAssertThrowsError(try store.loadArchive()) { XCTAssertEqual($0 as? SQLiteStoreError, .missingArchive) }
        }
        try store.importArchive(original); XCTAssertEqual(try store.loadArchive(), original)
    }
    func testDuplicateImportNeverOverwrites() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SQLiteSessionStore(url: dir.appendingPathComponent("sessions.sqlite3")); defer { store.close() }
        let original = try archive(); try store.importArchive(original)
        XCTAssertThrowsError(try store.importArchive(archive())) { XCTAssertEqual($0 as? SQLiteStoreError, .alreadyImported) }
        XCTAssertEqual(try store.loadArchive(), original)
    }
    func testFailureInSecondInsertRollsBackEverything() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3"); let store = try SQLiteSessionStore(url: url); defer { store.close() }
        try sql(url, "CREATE TRIGGER reject_second BEFORE INSERT ON sessions WHEN NEW.position=1 BEGIN SELECT RAISE(ABORT, 'synthetic'); END;")
        let original = try archive(); XCTAssertThrowsError(try store.importArchive(original))
        XCTAssertThrowsError(try store.loadArchive()) { XCTAssertEqual($0 as? SQLiteStoreError, .missingArchive) }
        try sql(url, "DROP TRIGGER reject_second;"); try store.importArchive(original)
        XCTAssertEqual(try store.loadArchive(), original)
    }
    func testUnknownVersionAndUnrelatedDatabaseRejected() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("future.sqlite3")
        try sql(url, "PRAGMA user_version=99;")
        XCTAssertThrowsError(try SQLiteSessionStore(url: url)) { XCTAssertEqual($0 as? SQLiteStoreError, .unsupportedVersion(99)) }
        let unrelated = dir.appendingPathComponent("unrelated.sqlite3")
        try sql(unrelated, "CREATE TABLE other(value TEXT); INSERT INTO other VALUES ('keep');")
        XCTAssertThrowsError(try SQLiteSessionStore(url: unrelated)) { XCTAssertEqual($0 as? SQLiteStoreError, .invalidSchema) }
        try sql(unrelated, "INSERT INTO other VALUES ('still present');")
    }
    func testInvalidStoredSnapshotFailsClosed() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3"); let store = try SQLiteSessionStore(url: url)
        try store.importArchive(archive()); store.close()
        try sql(url, "UPDATE sessions SET snapshot=X'00' WHERE position=0;")
        XCTAssertThrowsError(try SQLiteSessionStore(url: url)) { XCTAssertEqual($0 as? SQLiteStoreError, .invalidArchive) }
    }
    func testClosedStoreRejectsOperations() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SQLiteSessionStore(url: dir.appendingPathComponent("sessions.sqlite3")); store.close()
        XCTAssertThrowsError(try store.loadArchive()) { XCTAssertEqual($0 as? SQLiteStoreError, .database(SQLITE_MISUSE)) }
    }

    func testTransactionalSessionCRUDAndReopen() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3")
        let initial = try archive()
        let settled = try initial.sessions.map { record -> SQLiteSessionRecord in
            var snapshot = try JSONDecoder().decode(Snapshot.self, from: record.snapshot)
            snapshot.status = .complete; snapshot.pending = nil
            return .init(id: record.id, title: record.title, createdAt: record.createdAt, snapshot: try JSONEncoder().encode(snapshot))
        }
        let store = try SQLiteSessionStore(url: url); try store.importArchive(.init(activeID: initial.activeID, sessions: settled))

        let created = try store.createSession(title: "Third")
        var newSnapshot = Snapshot(); newSnapshot.status = .complete
        newSnapshot.messages = [Message("user", "synthetic SQLite write")]
        try store.saveSnapshot(newSnapshot, for: created)
        try store.renameSession(created, title: "Renamed")
        let tail = try store.createSession(title: "Tail")
        try store.selectSession(initial.activeID)
        try store.deleteSession(created)

        var result = try store.loadArchive()
        XCTAssertEqual(result.sessions.map(\.id), initial.sessions.map(\.id) + [tail])
        XCTAssertEqual(result.activeID, initial.activeID)
        try store.deleteSession(tail)
        result = try store.loadArchive()
        XCTAssertEqual(result.sessions.map(\.id), initial.sessions.map(\.id))
        store.close()

        let reopened = try SQLiteSessionStore(url: url)
        defer { reopened.close() }
        XCTAssertEqual(try reopened.loadArchive(), result)
        let fresh = try reopened.eraseAllAndCreateFreshSession()
        result = try reopened.loadArchive()
        XCTAssertEqual(result.sessions.map(\.id), [fresh])
        XCTAssertEqual(result.sessions[0].title, "New conversation")
        XCTAssertEqual(try JSONDecoder().decode(Snapshot.self, from: result.sessions[0].snapshot), Snapshot())
    }

    func testMutationsPreserveUnresolvedAndLastSessionBoundaries() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3")
        let original = try archive()
        var pending = try JSONDecoder().decode(Snapshot.self, from: original.sessions[0].snapshot)
        pending.status = .approval; pending.pending = Decision("save_memory", "synthetic")
        var settled = try JSONDecoder().decode(Snapshot.self, from: original.sessions[1].snapshot)
        settled.status = .complete
        let records = [
            SQLiteSessionRecord(id: original.sessions[0].id, title: original.sessions[0].title, createdAt: original.sessions[0].createdAt, snapshot: try JSONEncoder().encode(pending)),
            SQLiteSessionRecord(id: original.sessions[1].id, title: original.sessions[1].title, createdAt: original.sessions[1].createdAt, snapshot: try JSONEncoder().encode(settled))
        ]
        let store = try SQLiteSessionStore(url: url); defer { store.close() }
        try store.importArchive(.init(activeID: records[0].id, sessions: records))
        XCTAssertThrowsError(try store.createSession(title: "Blocked")) { XCTAssertEqual($0 as? SQLiteStoreError, .unresolvedTask) }
        XCTAssertThrowsError(try store.selectSession(records[1].id)) { XCTAssertEqual($0 as? SQLiteStoreError, .unresolvedTask) }
        XCTAssertThrowsError(try store.deleteSession(records[0].id)) { XCTAssertEqual($0 as? SQLiteStoreError, .unresolvedTask) }
        XCTAssertThrowsError(try store.renameSession(records[0].id, title: " ")) { XCTAssertEqual($0 as? SQLiteStoreError, .invalidTitle) }
        try store.saveSnapshot(settled, for: records[0].id)
        try store.selectSession(records[1].id)
        try store.deleteSession(records[0].id)
        XCTAssertEqual(try store.loadArchive().sessions.map(\.id), [records[1].id])
        XCTAssertThrowsError(try store.deleteSession(records[1].id)) { XCTAssertEqual($0 as? SQLiteStoreError, .lastSession) }
        XCTAssertEqual(try store.loadArchive().sessions.map(\.id), [records[1].id])
    }

    func testCreateFirstSQLiteSessionWithoutArchive() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SQLiteSessionStore(url: dir.appendingPathComponent("sessions.sqlite3")); defer { store.close() }
        let id = try store.createSession(title: "First")
        XCTAssertEqual(try store.loadArchive().sessions.map(\.id), [id])
    }

    func testCreateSessionRollsBackIfActivationFails() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite3")
        let source = try archive()
        let records = try source.sessions.map { record -> SQLiteSessionRecord in
            var snapshot = try JSONDecoder().decode(Snapshot.self, from: record.snapshot)
            snapshot.status = .complete; snapshot.pending = nil
            return .init(id: record.id, title: record.title, createdAt: record.createdAt, snapshot: try JSONEncoder().encode(snapshot))
        }
        let store = try SQLiteSessionStore(url: url); defer { store.close() }
        let baseline = SQLiteSessionArchive(activeID: source.activeID, sessions: records)
        try store.importArchive(baseline)
        try sql(url, "CREATE TRIGGER reject_activation BEFORE UPDATE OF active_id ON selection BEGIN SELECT RAISE(ABORT, 'synthetic'); END;")
        XCTAssertThrowsError(try store.createSession(title: "Must roll back"))
        XCTAssertEqual(try store.loadArchive(), baseline)
    }
}
