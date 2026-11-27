import Foundation
import XCTest
@testable import JarvisCore

private actor GateModel: Intelligence {
    private var continuation: CheckedContinuation<Decision, Never>?
    private var started = false
    func decide(prompt: String) async throws -> Decision {
        await withCheckedContinuation { continuation = $0; started = true }
    }
    func hasStarted() -> Bool { started }
    func finish() { continuation?.resume(returning: .init("reply", "finished")); continuation = nil }
}

@MainActor final class SessionCoordinatorTests: XCTestCase {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    func testCreateSwitchRenameAndReopen() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let c = try SessionCoordinator(root: dir, engine: Scripted([.init("reply", "one"), .init("reply", "two")]))
        let first = c.activeID
        try await c.submit("first synthetic")
        try c.create(title: "Second"); let second = c.activeID
        XCTAssertNotEqual(first, second); XCTAssertTrue(c.snapshot.messages.isEmpty)
        try await c.submit("second synthetic")
        try c.rename(second, title: "Renamed")
        try c.select(first); XCTAssertEqual(c.snapshot.messages.last?.text, "one")
        let reopened = try SessionCoordinator(root: dir, engine: Scripted([]))
        XCTAssertEqual(reopened.activeID, first)
        try reopened.select(second)
        XCTAssertEqual(reopened.snapshot.messages.last?.text, "two")
        XCTAssertEqual(reopened.sessions.first { $0.id == second }?.title, "Renamed")
    }
    func testPendingApprovalAndRestartIsolation() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let c = try SessionCoordinator(root: dir, engine: Scripted([.init("save_memory", "synthetic blue")]))
        let first = c.activeID
        try c.create(title: "Second"); let second = c.activeID
        try await c.submit("remember synthetic blue")
        XCTAssertEqual(c.snapshot.status, .approval)
        XCTAssertFalse(c.canChangeSessions)
        XCTAssertThrowsError(try c.select(first))
        XCTAssertThrowsError(try c.eraseAll())
        let reopened = try SessionCoordinator(root: dir, engine: Scripted([.init("reply", "saved")]))
        XCTAssertEqual(reopened.activeID, second)
        try await reopened.approve(true)
        XCTAssertEqual(reopened.snapshot.notes.map(\.text), ["synthetic blue"])
        try reopened.select(first); XCTAssertTrue(reopened.snapshot.notes.isEmpty)
        try reopened.select(second); XCTAssertEqual(reopened.snapshot.notes.map(\.text), ["synthetic blue"])
    }
    func testBusyBlocksAllSessionMutationsUntilWriterReturns() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let gate = GateModel()
        let c = try SessionCoordinator(root: dir, engine: gate)
        let first = c.activeID; try c.create(title: "Second"); let second = c.activeID
        let task = Task { try await c.submit("synthetic") }
        for _ in 0..<1000 {
            if await gate.hasStarted() { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let started = await gate.hasStarted()
        XCTAssertTrue(started)
        XCTAssertTrue(c.busy)
        XCTAssertThrowsError(try c.select(first))
        XCTAssertThrowsError(try c.create(title: "Third"))
        XCTAssertThrowsError(try c.rename(second, title: "Other"))
        XCTAssertThrowsError(try c.delete(second))
        XCTAssertThrowsError(try c.eraseAll())
        await gate.finish()
        try await task.value
        XCTAssertFalse(c.busy); XCTAssertEqual(c.activeID, second)
        try c.select(first); XCTAssertTrue(c.snapshot.messages.isEmpty)
    }
    func testCancellationDoesNotAllowPrematureSwitch() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let gate = GateModel(); let c = try SessionCoordinator(root: dir, engine: gate)
        let first = c.activeID; try c.create(title: "Second")
        let task = Task { try await c.submit("synthetic") }
        for _ in 0..<1000 {
            if await gate.hasStarted() { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let started = await gate.hasStarted(); XCTAssertTrue(started)
        task.cancel()
        XCTAssertThrowsError(try c.select(first))
        await gate.finish()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(c.snapshot.status, .cancelled)
        try c.select(first); XCTAssertTrue(c.snapshot.messages.isEmpty)
    }
    func testOrdinaryValidationErrorPreservesWriter() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let c = try SessionCoordinator(root: dir, engine: Scripted([.init("reply", "ok")]))
        let id = c.activeID
        XCTAssertThrowsError(try c.create(title: " "))
        XCTAssertTrue(c.isReady); XCTAssertEqual(c.activeID, id)
        try await c.submit("valid")
        XCTAssertEqual(c.snapshot.status, .complete)
    }
    func testExternalSnapshotChangeFailsClosed() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let c = try SessionCoordinator(root: dir, engine: Scripted([]))
        let url = dir.appendingPathComponent("session-\(c.activeID.uuidString).json")
        var changed = Snapshot(); changed.messages = [Message("user", "external synthetic")]
        let bytes = try JSONEncoder().encode(changed); try bytes.write(to: url)
        XCTAssertThrowsError(try c.create(title: "Must fail"))
        XCTAssertFalse(c.isReady)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertTrue(c.snapshot.messages.isEmpty)
    }
    func testEraseAllClearsEverySessionAndReopens() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let c = try SessionCoordinator(root: dir, engine: Scripted([.init("reply", "one"), .init("reply", "two")]))
        try await c.submit("first"); let first = c.activeID
        try c.create(title: "Second"); let second = c.activeID
        try await c.submit("second")
        try c.eraseAll()
        XCTAssertEqual(c.sessions.count, 1); XCTAssertTrue(c.snapshot.messages.isEmpty)
        for id in [first, second] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("session-\(id.uuidString).json").path))
        }
        let reopened = try SessionCoordinator(root: dir, engine: Scripted([]))
        XCTAssertEqual(reopened.activeID, c.activeID); XCTAssertTrue(reopened.snapshot.messages.isEmpty)
    }
}
