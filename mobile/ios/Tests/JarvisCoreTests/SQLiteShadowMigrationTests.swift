import Foundation
import XCTest
@testable import JarvisCore

@MainActor final class SQLiteShadowMigrationTests: XCTestCase {
    private func root() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }
    private func archive() throws -> SQLiteSessionArchive {
        var first = Snapshot(); first.messages = [Message("user", "synthetic café")]
        first.notes = [Note("synthetic blue")]; first.status = .approval
        first.pending = Decision("save_memory", "synthetic green"); first.steps = 2
        var second = Snapshot(); second.status = .running
        second.messages = [Message("user", "synthetic two")]; second.memoryWriteDenied = true
        let a = SQLiteSessionRecord(id: UUID(), title: "First", createdAt: Date(), snapshot: try JSONEncoder().encode(first))
        let b = SQLiteSessionRecord(id: UUID(), title: "Second", createdAt: Date(), snapshot: try JSONEncoder().encode(second))
        return .init(activeID: a.id, sessions: [a,b])
    }
    func testRehearsalVerifiesReopenAndCleansOnlyItsStage() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let sentinel = dir.appendingPathComponent("keep.txt")
        let bytes = Data("synthetic sentinel".utf8); try bytes.write(to: sentinel)
        let a = try archive(); var reads = 0
        let result = try SQLiteShadowMigration.rehearse(scratchRoot: dir) { reads += 1; return a }
        XCTAssertEqual(reads, 2); XCTAssertEqual(result.sessionCount, 2)
        XCTAssertEqual(result.messageCount, 2); XCTAssertEqual(result.approvedMemoryCount, 1)
        XCTAssertEqual(result.pendingApprovalCount, 1); XCTAssertEqual(result.interruptedTaskCount, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["keep.txt"])
        XCTAssertEqual(try Data(contentsOf: sentinel), bytes)
    }
    func testSourceDriftRefusesSuccessAndCleansStage() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try archive(); let changed = SQLiteSessionArchive(activeID: a.sessions[1].id, sessions: a.sessions)
        var reads = 0
        XCTAssertThrowsError(try SQLiteShadowMigration.rehearse(scratchRoot: dir) {
            reads += 1; return reads == 1 ? a : changed
        }) { XCTAssertEqual($0 as? SQLiteMigrationError, .sourceChanged) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
    func testInvalidArchiveDoesNotLeaveStage() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try archive()
        let invalid = SQLiteSessionArchive(activeID: UUID(), sessions: a.sessions)
        XCTAssertThrowsError(try SQLiteShadowMigration.rehearse(scratchRoot: dir) { invalid })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
    func testSourceReadErrorBeforeAndAfterCopyDoesNotLeaveStage() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try archive()
        enum SyntheticError: Error { case read }
        XCTAssertThrowsError(try SQLiteShadowMigration.rehearse(scratchRoot: dir) { throw SyntheticError.read })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
        var reads = 0
        XCTAssertThrowsError(try SQLiteShadowMigration.rehearse(scratchRoot: dir) {
            reads += 1; if reads == 2 { throw SyntheticError.read }; return a
        })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
    func testMissingScratchDirectoryDoesNotCreateOrResetAnything() async throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try archive(); let missing = dir.appendingPathComponent("missing")
        XCTAssertThrowsError(try SQLiteShadowMigration.rehearse(scratchRoot: missing) { a })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
}
