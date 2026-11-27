import XCTest
@testable import JarvisCore
actor Scripted: Intelligence {
    var decisions: [Decision]; init(_ d: [Decision]) { decisions = d }
    func decide(prompt: String) async throws -> Decision { guard !decisions.isEmpty else { throw AgentError.invalidDecision }; return decisions.removeFirst() }
}
@MainActor final class AgentTests: XCTestCase {
    func path() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json") }
    func testReplyAndReload() async throws {
        let f = path(); let a = try Agent(engine: Scripted([.init("reply", "Hello")]), file: f)
        let s = try await a.start("Hi"); XCTAssertEqual(s.status, .complete); XCTAssertEqual(s.messages.last?.text, "Hello")
        let b = try Agent(engine: Scripted([]), file: f); let r = await b.snapshot(); XCTAssertEqual(r.messages, s.messages)
    }
    func testApprovalAfterRestart() async throws {
        let f = path(); let a = try Agent(engine: Scripted([.init("save_memory", "Favorite color is blue")]), file: f)
        let s = try await a.start("Remember my favorite color"); XCTAssertEqual(s.status, .approval); XCTAssertTrue(s.notes.isEmpty)
        let b = try Agent(engine: Scripted([.init("reply", "Saved")]), file: f); let r = try await b.approve(true); XCTAssertEqual(r.notes.count, 1); XCTAssertEqual(r.status, .complete)
    }
    func testDeny() async throws {
        let a = try Agent(engine: Scripted([.init("save_memory", "secret"), .init("reply", "Not saved")]), file: path())
        _ = try await a.start("Remember this"); let s = try await a.approve(false); XCTAssertTrue(s.notes.isEmpty)
    }
    func testUnknownActionFails() async throws {
        let a = try Agent(engine: Scripted([.init("shell", "bad")]), file: path())
        do { _ = try await a.start("Run it"); XCTFail() } catch { let s = await a.snapshot(); XCTAssertEqual(s.status, .failed) }
    }
    func testBoundedLoop() async throws {
        let a = try Agent(engine: Scripted([.init("current_time", ""), .init("current_time", "")]), file: path(), maxSteps: 2)
        do { _ = try await a.start("Time"); XCTFail() } catch { let s = await a.snapshot(); XCTAssertEqual(s.steps, 2); XCTAssertEqual(s.status, .failed) }
    }
    func testDeleteMemory() async throws {
        let a = try Agent(engine: Scripted([.init("save_memory", "blue"), .init("reply", "ok")]), file: path())
        _ = try await a.start("Remember blue"); let s = try await a.approve(true); let r = try await a.deleteMemory(s.notes[0].id); XCTAssertTrue(r.notes.isEmpty)
    }
    func testTimeTool() async throws {
        let a = try Agent(engine: Scripted([.init("current_time", ""), .init("reply", "done")]), file: path()); let s = try await a.start("time"); XCTAssertEqual(s.messages.map(\.role), ["user", "tool", "assistant"])
    }
    func testRepeatedDeniedWriteIsBlocked() async throws {
        let a = try Agent(engine: Scripted([.init("save_memory", "secret"), .init("save_memory", "secret"), .init("reply", "No write")]), file: path())
        _ = try await a.start("Remember this"); let s = try await a.approve(false); XCTAssertTrue(s.notes.isEmpty); XCTAssertEqual(s.status, .complete)
    }
    func testResumeFromCheckpoint() async throws {
        let f = path(); try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        var checkpoint = Snapshot(); checkpoint.status = .running; checkpoint.messages = [Message("user", "Resume me")]; checkpoint.steps = 1
        try JSONEncoder().encode(checkpoint).write(to: f)
        let a = try Agent(engine: Scripted([.init("reply", "Resumed")]), file: f); let s = try await a.resume(); XCTAssertEqual(s.steps, 2); XCTAssertEqual(s.status, .complete)
    }
    func testEraseAll() async throws {
        let f = path(); let a = try Agent(engine: Scripted([.init("reply", "answer")]), file: f); _ = try await a.start("private request"); _ = try await a.eraseAll()
        let b = try Agent(engine: Scripted([]), file: f); let s = await b.snapshot(); XCTAssertTrue(s.messages.isEmpty); XCTAssertTrue(s.notes.isEmpty); XCTAssertEqual(s.status, .idle)
    }
}
