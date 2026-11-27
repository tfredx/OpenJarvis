import Foundation
import XCTest
@testable import JarvisCore

@MainActor final class SessionMigrationIntegrationTests: XCTestCase {
    private func root() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }
    private func files(at root: URL) throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(atPath: root.path).map {
            ($0, try Data(contentsOf: root.appendingPathComponent($0)))
        })
    }
    func testCoordinatorRehearsalPreservesSourceBytesAndApproval() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source")
        let scratch = dir.appendingPathComponent("scratch")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
        let staleName = SQLiteMigrationJournal.stagePrefix + UUID().uuidString
        let staleStage = scratch.appendingPathComponent(staleName, isDirectory: true)
        try FileManager.default.createDirectory(at: staleStage, withIntermediateDirectories: false)
        let staleFile = staleStage.appendingPathComponent("sessions.sqlite3")
        try Data("synthetic interrupted database".utf8).write(to: staleFile)
        let journal = scratch.appendingPathComponent(SQLiteMigrationJournal.journalName)
        try JSONEncoder().encode(SQLiteMigrationJournal.Record(version: 1, stageDirectory: staleName)).write(to: journal)
        let c = try SessionCoordinator(root: source, engine: Scripted([
            .init("save_memory", "synthetic blue"), .init("reply", "saved"),
            .init("save_memory", "synthetic green"), .init("reply", "saved")
        ]))
        let first = c.activeID
        try await c.submit("remember blue"); try await c.approve(true)
        try c.create(title: "Second"); let second = c.activeID
        try await c.submit("remember green")
        let before = try files(at: source); let snapshot = c.snapshot
        let report = try c.rehearseSQLiteMigration(scratchRoot: scratch)
        XCTAssertEqual(report.sessionCount, 2); XCTAssertEqual(report.pendingApprovalCount, 1)
        XCTAssertEqual(report.approvedMemoryCount, 1); XCTAssertEqual(report.messageCount, snapshot.messages.count + 3)
        XCTAssertEqual(try files(at: source), before); XCTAssertEqual(c.snapshot, snapshot)
        XCTAssertEqual(c.activeID, second); XCTAssertFalse(c.busy)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: scratch.path).isEmpty)
        try await c.approve(true); XCTAssertEqual(c.snapshot.notes.map(\.text), ["synthetic green"])
        try c.select(first); XCTAssertEqual(c.snapshot.notes.map(\.text), ["synthetic blue"])
    }

    func testJournalRecoveryRemovesOnlyRecordedStage() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let stageName = SQLiteMigrationJournal.stagePrefix + UUID().uuidString
        let stage = dir.appendingPathComponent(stageName, isDirectory: true)
        let unrelated = dir.appendingPathComponent("unrelated", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)
        let marker = stage.appendingPathComponent("marker")
        let retained = unrelated.appendingPathComponent("keep")
        try Data("stage".utf8).write(to: marker)
        try Data("keep".utf8).write(to: retained)
        try JSONEncoder().encode(SQLiteMigrationJournal.Record(version: 1, stageDirectory: stageName))
            .write(to: dir.appendingPathComponent(SQLiteMigrationJournal.journalName))

        try SQLiteMigrationJournal.recover(in: dir)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stage.path))
        XCTAssertEqual(try Data(contentsOf: retained), Data("keep".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(SQLiteMigrationJournal.journalName).path))
    }

    func testJournalRecoveryFailsClosedOnCorruptOrUntrackedState() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let stageName = SQLiteMigrationJournal.stagePrefix + UUID().uuidString
        let stage = dir.appendingPathComponent(stageName, isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        let marker = stage.appendingPathComponent("marker")
        let markerBytes = Data("preserve".utf8)
        try markerBytes.write(to: marker)
        let journal = dir.appendingPathComponent(SQLiteMigrationJournal.journalName)
        try Data("not-json".utf8).write(to: journal)

        XCTAssertThrowsError(try SQLiteMigrationJournal.recover(in: dir)) {
            XCTAssertEqual($0 as? SQLiteMigrationError, .invalidJournal)
        }
        XCTAssertEqual(try Data(contentsOf: marker), markerBytes)

        try FileManager.default.removeItem(at: journal)
        XCTAssertThrowsError(try SQLiteMigrationJournal.recover(in: dir)) {
            XCTAssertEqual($0 as? SQLiteMigrationError, .untrackedStage)
        }
        XCTAssertEqual(try Data(contentsOf: marker), markerBytes)
    }
    func testExportRejectsExternalCatalogAndOrphanedSnapshot() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = try SessionRepository(root: dir)
        let catalog = dir.appendingPathComponent("sessions.json")
        let original = try Data(contentsOf: catalog)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var rows = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        rows[0]["title"] = "Externally changed"; json["sessions"] = rows
        let changed = try JSONSerialization.data(withJSONObject: json); try changed.write(to: catalog)
        XCTAssertThrowsError(try r.exportArchive()) { XCTAssertEqual($0 as? SessionError, .recoveryRequired) }
        XCTAssertEqual(try Data(contentsOf: catalog), changed)
        try original.write(to: catalog)
        let orphan = dir.appendingPathComponent("session-\(UUID().uuidString).json")
        let bytes = try JSONEncoder().encode(Snapshot()); try bytes.write(to: orphan)
        XCTAssertThrowsError(try r.exportArchive()) { XCTAssertEqual($0 as? SessionError, .orphanedSnapshot) }
        XCTAssertEqual(try Data(contentsOf: orphan), bytes)
    }
    func testExportRejectsMissingOrCorruptInactiveSnapshot() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = try SessionRepository(root: dir)
        let firstURL = try r.activeSnapshotURL()
        _ = try r.create(title: "Second")
        let before = try r.exportArchive()
        XCTAssertEqual(before.sessions.count, 2)
        try FileManager.default.removeItem(at: firstURL)
        XCTAssertThrowsError(try r.exportArchive()) { XCTAssertEqual($0 as? SessionError, .missingSnapshot) }
        let corrupt = Data("not JSON".utf8); try corrupt.write(to: firstURL)
        XCTAssertThrowsError(try r.exportArchive())
        XCTAssertEqual(try Data(contentsOf: firstURL), corrupt)
    }
}
