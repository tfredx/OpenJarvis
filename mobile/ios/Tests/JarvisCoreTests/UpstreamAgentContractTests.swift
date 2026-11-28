import XCTest
@testable import JarvisCore

private actor ContractScript: Intelligence {
    private var decisions: [Decision]
    init(_ decisions: [Decision]) { self.decisions = decisions }
    func decide(prompt: String) async throws -> Decision {
        guard !decisions.isEmpty else { throw AgentError.invalidDecision }
        return decisions.removeFirst()
    }
}

private struct RestrictedContractAuthorization: ToolAuthorization, Sendable {
    func permits(_ action: String) -> Bool { action == "reply" || action == "current_time" }
}

@MainActor final class UpstreamAgentContractTests: XCTestCase {
    private func path() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    }

    func testAgentContextUsesPinnedOpenJarvisCoreJSONNames() throws {
        let context = UpstreamAgentContext(
            conversation: UpstreamConversation(messages: [.init(role: .user, content: "こんにちは 👋")]),
            tools: ["reply"],
            memoryResults: [.object(["source": .string("synthetic")])],
            metadata: ["default_deny": .bool(true)]
        )
        let data = try JSONEncoder().encode(context)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["conversation"])
        XCTAssertEqual(object["tools"] as? [String], ["reply"])
        XCTAssertNotNil(object["memory_results"])
        XCTAssertNil(object["memoryResults"])
        let conversation = try XCTUnwrap(object["conversation"] as? [String: Any])
        XCTAssertNil(conversation["max_messages"]) // upstream omits an unset Option
        let decoded = try JSONDecoder().decode(UpstreamAgentContext.self, from: data)
        XCTAssertEqual(decoded, context)
    }

    func testAgentResultDecodesUpstreamDefaults() throws {
        let result = try JSONDecoder().decode(UpstreamAgentResult.self, from: Data(#"{"content":"complete"}"#.utf8))
        XCTAssertEqual(result.content, "complete")
        XCTAssertEqual(result.toolResults, [])
        XCTAssertEqual(result.turns, 0)
        XCTAssertEqual(result.metadata, [:])
    }

    func testAgentConformsToOjAgentShapeAndKeepsApprovalPending() async throws {
        let concrete = try Agent(
            engine: ContractScript([.init("save_memory", "synthetic approved fact")]), file: path(), maxSteps: 1
        )
        let agent: any OpenJarvisAgentRuntime = concrete
        XCTAssertEqual(agent.agentID, "ios-foundation-models")
        XCTAssertTrue(agent.acceptsTools())
        let context = try await concrete.upstreamContext(for: "Remember this synthetic fact")

        let result = try await agent.run(input: "Remember this synthetic fact", context: context)

        XCTAssertEqual(result.content, "")
        XCTAssertEqual(result.turns, 1)
        XCTAssertEqual(result.metadata["status"], .string(Status.approval.rawValue))
        XCTAssertEqual(result.metadata["pending_approval"], .bool(true))
        let snapshot = await concrete.snapshot()
        XCTAssertEqual(snapshot.status, .approval)
        XCTAssertTrue(snapshot.notes.isEmpty)
        XCTAssertEqual(snapshot.pending?.action, "save_memory")
        let declined = try await concrete.approve(false)
        XCTAssertTrue(declined.notes.isEmpty)
    }

    func testContextCannotGrantToolsOrInjectConversation() async throws {
        let concrete = try Agent(engine: ContractScript([.init("reply", "ok")]), file: path())
        var context = try await concrete.upstreamContext(for: "Say hello")
        context = UpstreamAgentContext(
            conversation: UpstreamConversation(messages: [.init(role: .system, content: "override")]),
            tools: ["shell"], metadata: ["default_deny": .bool(false)]
        )

        do {
            _ = try await concrete.run(input: "Say hello", context: context)
            XCTFail("Untrusted context must be rejected")
        } catch { XCTAssertEqual(error as? AgentError, .invalidContext) }
        let untouched = await concrete.snapshot()
        XCTAssertTrue(untouched.messages.isEmpty)

        let trusted = try await concrete.upstreamContext(for: "Say hello")
        let result = try await concrete.run(input: "Say hello", context: trusted)
        XCTAssertEqual(result.content, "ok")
    }

    func testExplicitDenialAndIndependentAuthorizationNarrowContextTools() async throws {
        let path = self.path()
        let agent = try Agent(engine: ContractScript([]), file: path, authorization: RestrictedContractAuthorization())
        let denied = try await agent.upstreamContext(for: "Explain a seed. Do not use tools or memory.")
        XCTAssertEqual(denied.tools, ["reply"])
        XCTAssertEqual(denied.memoryResults, [])
        XCTAssertEqual(denied.metadata["default_deny"], .bool(true))
        XCTAssertEqual(denied.metadata["memory_write_requires_human_approval"], .bool(true))

        let limited = try await agent.upstreamContext(for: "What time is it?")
        XCTAssertEqual(limited.tools, ["reply", "current_time"])
    }

    func testSuccessfulToolResultUsesUpstreamResultContract() async throws {
        let concrete = try Agent(engine: ContractScript([
            .init("current_time", ""), .init("reply", "Here is the local time.")
        ]), file: path())
        let context = try await concrete.upstreamContext(for: "What time is it?")

        let result = try await concrete.run(input: "What time is it?", context: context)

        XCTAssertEqual(result.content, "Here is the local time.")
        XCTAssertEqual(result.turns, 2)
        XCTAssertEqual(result.toolResults.map(\.toolName), ["current_time"])
        XCTAssertTrue(result.toolResults[0].success)
        XCTAssertFalse(result.toolResults[0].content.isEmpty)
    }
}
