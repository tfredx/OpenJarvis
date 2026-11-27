import Foundation
import XCTest
@testable import JarvisCore

@MainActor final class SessionRepositoryTests: XCTestCase {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func read(_ url: URL) throws -> Snapshot { try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url)) }
    private func editCatalog(_ root: URL, _ change: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("sessions.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        change(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: url, options: .atomic)
    }
    func testEmptyStartupAndReopen() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(try read(store.activeSnapshotURL()).status, .idle)
        let reopened = try SessionRepository(root: dir)
        XCTAssertEqual(reopened.sessions, store.sessions); XCTAssertEqual(reopened.activeID, store.activeID)
    }
    func testLegacyMigrationPreservesExactBytesAndIsIdempotent() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var legacy = Snapshot(); legacy.messages = [Message("user", "synthetic")]; legacy.notes = [Note("blue")]
        legacy.status = .approval; legacy.pending = Decision("save_memory", "green"); legacy.steps = 2
        let bytes = try JSONEncoder().encode(legacy); let file = dir.appendingPathComponent("state.json")
        try bytes.write(to: file)
        let store = try SessionRepository(root: dir)
        XCTAssertEqual(try Data(contentsOf: store.activeSnapshotURL()), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let reopened = try SessionRepository(root: dir)
        XCTAssertEqual(reopened.sessions.count, 1); XCTAssertEqual(reopened.activeID, store.activeID)
        XCTAssertEqual(try Data(contentsOf: reopened.activeSnapshotURL()), bytes)
    }
    func testIsolatedHistoryAndMemoryAcrossAgentInstances() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let first = store.activeID
        let a = try Agent(engine: Scripted([.init("save_memory", "blue"), .init("reply", "done")]), file: store.activeSnapshotURL())
        _ = try await a.start("synthetic A"); _ = try await a.approve(true)
        let second = try store.create(title: "Synthetic B")
        let b = try Agent(engine: Scripted([.init("reply", "different")]), file: store.activeSnapshotURL())
        let result = try await b.start("synthetic B")
        XCTAssertTrue(result.notes.isEmpty); XCTAssertFalse(result.messages.contains { $0.text.contains("synthetic A") })
        try store.select(first); XCTAssertEqual(try read(store.activeSnapshotURL()).notes.map(\.text), ["blue"])
        let reopened = try SessionRepository(root: dir); XCTAssertEqual(reopened.activeID, first)
        try reopened.select(second.id); XCTAssertTrue(try read(reopened.activeSnapshotURL()).notes.isEmpty)
    }
    func testPendingApprovalBlocksSwitchAndDestructionAfterRestart() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let first = store.activeID
        let second = try store.create(title: "Second")
        let a = try Agent(engine: Scripted([.init("save_memory", "synthetic")]), file: store.activeSnapshotURL())
        _ = try await a.start("remember synthetic")
        let reopened = try SessionRepository(root: dir)
        XCTAssertEqual(reopened.activeID, second.id)
        XCTAssertThrowsError(try reopened.select(first)) { XCTAssertEqual($0 as? SessionError, .unresolvedTask) }
        XCTAssertThrowsError(try reopened.create(title: "Third"))
        XCTAssertThrowsError(try reopened.delete(second.id)); XCTAssertThrowsError(try reopened.eraseAll())
        let b = try Agent(engine: Scripted([]), file: reopened.activeSnapshotURL()); _ = try await b.cancel()
        try reopened.select(first); XCTAssertEqual(try read(reopened.activeSnapshotURL()).status, .idle)
    }
    func testRenameDeleteAndEraseAll() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let first = store.activeID; let oldURL = try store.activeSnapshotURL()
        let second = try store.create(title: "  Second  "); XCTAssertEqual(second.title, "Second")
        try store.rename(second.id, title: "Renamed")
        XCTAssertThrowsError(try store.rename(second.id, title: " "))
        XCTAssertThrowsError(try store.select(UUID()))
        try store.delete(first); XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        let secondURL = try store.activeSnapshotURL(); try store.eraseAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path)); XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(try read(store.activeSnapshotURL()).status, .idle)
        let reopened = try SessionRepository(root: dir); XCTAssertEqual(reopened.activeID, store.activeID)
        XCTAssertEqual(reopened.sessions.count, 1)
    }
    func testCorruptAndUnknownVersionNeverReset() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let state = try store.activeSnapshotURL()
        let url = dir.appendingPathComponent("sessions.json")
        try editCatalog(dir) { $0["version"] = 99 }
        XCTAssertThrowsError(try SessionRepository(root: dir)) { XCTAssertEqual($0 as? SessionError, .unsupportedVersion) }
        let bytes = Data("not json".utf8); try bytes.write(to: url)
        XCTAssertThrowsError(try SessionRepository(root: dir))
        XCTAssertEqual(try Data(contentsOf: url), bytes); XCTAssertTrue(FileManager.default.fileExists(atPath: state.path))
    }
    func testMissingSnapshotAndMissingCatalogFailClosed() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let state = try store.activeSnapshotURL()
        let bytes = try Data(contentsOf: state); try FileManager.default.removeItem(at: state)
        XCTAssertThrowsError(try SessionRepository(root: dir)) { XCTAssertEqual($0 as? SessionError, .missingSnapshot) }
        try bytes.write(to: state); try FileManager.default.removeItem(at: dir.appendingPathComponent("sessions.json"))
        XCTAssertThrowsError(try SessionRepository(root: dir)) { XCTAssertEqual($0 as? SessionError, .orphanedSnapshot) }
        XCTAssertEqual(try Data(contentsOf: state), bytes)
    }
    func testRecoverInterruptedCreationAndRetirement() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let first = store.activeID; let oldURL = try store.activeSnapshotURL()
        let next = try store.create(title: "Second"); let newURL = try store.activeSnapshotURL()
        try FileManager.default.removeItem(at: newURL)
        try editCatalog(dir) { json in
            json["initializing"] = next.id.uuidString; json["retired"] = [first.uuidString]
            json["sessions"] = (json["sessions"] as? [[String: Any]])?.filter { $0["id"] as? String == next.id.uuidString }
        }
        let reopened = try SessionRepository(root: dir)
        XCTAssertEqual(reopened.sessions.count, 1); XCTAssertEqual(reopened.activeID, next.id)
        XCTAssertEqual(try read(reopened.activeSnapshotURL()).status, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
    }
    func testRecoverInterruptedLegacyCopy() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let id = store.activeID; let state = try store.activeSnapshotURL()
        var old = Snapshot(); old.messages = [Message("user", "synthetic migration")]
        let bytes = try JSONEncoder().encode(old); try bytes.write(to: dir.appendingPathComponent("state.json"))
        try FileManager.default.removeItem(at: state)
        try editCatalog(dir) { $0["initializing"] = id.uuidString; $0["migratingLegacy"] = true }
        let reopened = try SessionRepository(root: dir)
        XCTAssertEqual(try Data(contentsOf: reopened.activeSnapshotURL()), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("state.json").path))
    }
    func testFailedCatalogWriteDoesNotMutateInMemorySelection() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try SessionRepository(root: dir); let first = store.activeID; let before = store.sessions
        let catalog = dir.appendingPathComponent("sessions.json"); let bytes = try Data(contentsOf: catalog)
        try FileManager.default.removeItem(at: catalog); try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.create(title: "Must fail"))
        XCTAssertEqual(store.activeID, first); XCTAssertEqual(store.sessions, before)
        try FileManager.default.removeItem(at: catalog); try bytes.write(to: catalog)
        XCTAssertEqual(try SessionRepository(root: dir).sessions, before)
    }
}
