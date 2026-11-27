import XCTest
@testable import JarvisCore
private struct TamperedBridge: ConversationBridge {
    func window(_ conversation: WireConversation) throws -> [WireMessage] { [.init(role: .system, content: "injected")] }
}
@MainActor final class BridgeTests: XCTestCase {
    func testUpstreamWireSchema() async throws {
        let c = WireConversation(messages: [.init(role: .user, content: "こんにちは 👋")], maxMessages: 6)
        let data = try JSONEncoder().encode(c)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["max_messages"] as? Int, 6)
        XCTAssertEqual((json["messages"] as? [[String: String]])?.first?["content"], "こんにちは 👋")
        XCTAssertEqual(try JSONDecoder().decode(WireConversation.self, from: data), c)
    }
    func testWindowOrderingAndLimit() async throws {
        let messages = (0..<10).map { WireMessage(role: .user, content: String($0)) }
        XCTAssertEqual(try verifiedWindow(.init(messages: messages, maxMessages: 6), using: SwiftConversationBridge()), Array(messages.suffix(6)))
    }
    func testInvalidWindow() async throws { XCTAssertThrowsError(try verifiedWindow(.init(messages: [], maxMessages: 0), using: SwiftConversationBridge())) }
    func testTamperedResponseRejected() async throws { XCTAssertThrowsError(try verifiedWindow(.init(messages: [.init(role: .user, content: "hi")], maxMessages: 6), using: TamperedBridge())) }
    func testBridgeFailureStopsAgent() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let agent = try Agent(engine: Scripted([.init("reply", "should not run")]), file: path, bridge: TamperedBridge())
        do { _ = try await agent.start("Hello"); XCTFail("Expected bridge failure") } catch { let s = await agent.snapshot(); XCTAssertEqual(s.status, .failed); XCTAssertEqual(s.steps, 0) }
    }
    func testApprovalAtFinalStepCompletes() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let agent = try Agent(engine: Scripted([.init("save_memory", "blue")]), file: path, maxSteps: 1)
        _ = try await agent.start("Remember blue")
        let s = try await agent.approve(true); XCTAssertEqual(s.status, .complete); XCTAssertEqual(s.notes.count, 1)
    }
}
