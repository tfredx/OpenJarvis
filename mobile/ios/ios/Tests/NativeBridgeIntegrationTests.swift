import Foundation
import XCTest
import JarvisCore
@testable import OpenJarvisMobile

private actor ScriptedModel: Intelligence {
    private var decisions: [Decision]
    init(_ decisions: [Decision]) { self.decisions = decisions }
    func decide(prompt: String) async throws -> Decision {
        guard !decisions.isEmpty else { throw AgentError.invalidDecision }
        return decisions.removeFirst()
    }
}

/// Runs in the native-required iOS simulator test host.
/// No real model inference or personal data is involved.
@MainActor final class NativeBridgeIntegrationTests: XCTestCase {
    func testNativeBridgeSelected() async throws {
        XCTAssertTrue(makeConversationBridge() is NativeConversationBridge)
        XCTAssertEqual(conversationBridgeLabel, "Upstream Rust conversation bridge")
    }

    func testAllWindowSizesAndUnicodeAcrossABI() async throws {
        let roles: [WireMessage.Role] = [.system, .user, .assistant, .tool]
        let messages = (0..<32).map {
            WireMessage(role: roles[$0 % roles.count], content: "\($0) café 日本語 🧪 \"quoted\"\nline\u{0000}end")
        }
        let bridge = NativeConversationBridge()
        for limit in 1...32 {
            let input = WireConversation(messages: messages, maxMessages: limit)
            XCTAssertEqual(try bridge.window(input), Array(messages.suffix(limit)))
            XCTAssertEqual(try verifiedWindow(input, using: bridge), Array(messages.suffix(limit)))
        }
    }

    func testNativeRejectsInvalidBoundsAndOversizedHistory() async throws {
        let bridge = NativeConversationBridge()
        for limit in [-1, 0, 33] {
            XCTAssertThrowsError(try bridge.window(.init(messages: [], maxMessages: limit)))
        }
        let messages = Array(repeating: WireMessage(role: .user, content: "synthetic"), count: 33)
        XCTAssertThrowsError(try bridge.window(.init(messages: messages, maxMessages: 6)))
    }

    func testRepeatedEmptyAndNonemptyABICalls() async throws {
        let bridge = NativeConversationBridge()
        for i in 0..<100 {
            let empty = WireConversation(messages: [], maxMessages: 6)
            XCTAssertEqual(try bridge.window(empty), [])
            let message = WireMessage(role: .user, content: "synthetic \(i)")
            XCTAssertEqual(try bridge.window(.init(messages: [message], maxMessages: 6)), [message])
        }
    }

    func testAgentApprovalPersistsWithNativeBridge() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("state.json")
        let agent = try Agent(engine: ScriptedModel([.init("save_memory", "Synthetic blue")]),
                              file: file, bridge: NativeConversationBridge())
        let pending = try await agent.start("Remember synthetic blue")
        XCTAssertEqual(pending.status, .approval)
        XCTAssertTrue(pending.notes.isEmpty)
        let reopened = try Agent(engine: ScriptedModel([.init("reply", "Saved")]),
                                 file: file, bridge: NativeConversationBridge())
        let saved = try await reopened.approve(true)
        XCTAssertEqual(saved.status, .complete)
        XCTAssertEqual(saved.notes.map(\.text), ["Synthetic blue"])
        let finalAgent = try Agent(engine: ScriptedModel([]), file: file, bridge: NativeConversationBridge())
        let final = await finalAgent.snapshot()
        XCTAssertEqual(final.notes.map(\.text), ["Synthetic blue"])
    }

    func testAgentDenialWithNativeBridge() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let agent = try Agent(engine: ScriptedModel([.init("save_memory", "synthetic"),
                                                    .init("save_memory", "synthetic"),
                                                    .init("reply", "Not saved")]),
                              file: dir.appendingPathComponent("state.json"), bridge: NativeConversationBridge())
        _ = try await agent.start("Remember synthetic")
        let result = try await agent.approve(false)
        XCTAssertEqual(result.status, .complete)
        XCTAssertTrue(result.notes.isEmpty)
    }
}
