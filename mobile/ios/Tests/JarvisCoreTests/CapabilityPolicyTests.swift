import Foundation
import XCTest
@testable import JarvisCore

private struct AllowEverything: ToolAuthorization {
    func permits(_ action: String) -> Bool { true }
}
private struct DenyMemoryWrites: ToolAuthorization {
    func permits(_ action: String) -> Bool { action != "save_memory" }
}
private struct DenyMemoryReads: ToolAuthorization {
    func permits(_ action: String) -> Bool { action != "search_memory" }
}
private actor PromptRecorder: Intelligence {
    var prompt = ""
    func decide(prompt: String) async throws -> Decision {
        self.prompt = prompt
        return .init("reply", "done")
    }
}
@MainActor final class CapabilityPolicyTests: XCTestCase {
    func testDefaultDenyAndExactActions() async throws {
        let p = LocalToolAuthorization()
        for action in ["reply", "current_time", "search_memory", "save_memory"] {
            XCTAssertTrue(p.permits(action))
        }
        for action in ["", "shell", "network:fetch", "file:write", "schedule:create", "system:admin", "Reply", "reply ", "*", "reply\u{0000}shell"] {
            XCTAssertFalse(p.permits(action))
        }
    }
    func testInjectedPolicyCannotExpandAllowlist() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try Agent(engine: Scripted([.init("shell", "synthetic")]), file: dir.appendingPathComponent("state.json"), authorization: AllowEverything())
        do { _ = try await a.start("test"); XCTFail("Unknown tool permitted") }
        catch { let s = await a.snapshot(); XCTAssertEqual(s.status, .failed); XCTAssertTrue(s.notes.isEmpty) }
    }
    func testPolicyDeniesMemoryBeforeApproval() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try Agent(engine: Scripted([.init("save_memory", "synthetic")]), file: dir.appendingPathComponent("state.json"), authorization: DenyMemoryWrites())
        do { _ = try await a.start("test"); XCTFail("Denied tool reached approval") }
        catch { let s = await a.snapshot(); XCTAssertEqual(s.status, .failed); XCTAssertNil(s.pending); XCTAssertTrue(s.notes.isEmpty) }
    }
    func testRestoredApprovalRechecksCurrentPolicy() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("state.json")
        let a = try Agent(engine: Scripted([.init("save_memory", "synthetic")]), file: file)
        let pending = try await a.start("remember synthetic")
        XCTAssertEqual(pending.status, .approval)
        let b = try Agent(engine: Scripted([.init("reply", "denied")]), file: file, authorization: DenyMemoryWrites())
        do { _ = try await b.approve(true); XCTFail("Restored approval bypassed policy") }
        catch { let s = await b.snapshot(); XCTAssertTrue(s.notes.isEmpty); XCTAssertEqual(s.status, .approval) }
        let denied = try await b.approve(false)
        XCTAssertTrue(denied.notes.isEmpty)
        XCTAssertEqual(denied.status, .complete)
    }
    func testImplicitMemoryRetrievalHonorsReadPolicy() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("state.json")
        var snapshot = Snapshot()
        snapshot.notes = [Note("synthetic unique-value")]
        try JSONEncoder().encode(snapshot).write(to: file)
        let recorder = PromptRecorder()
        let a = try Agent(engine: recorder, file: file, authorization: DenyMemoryReads())
        _ = try await a.start("synthetic")
        let prompt = await recorder.prompt
        XCTAssertFalse(prompt.contains("unique-value"))
    }
}
