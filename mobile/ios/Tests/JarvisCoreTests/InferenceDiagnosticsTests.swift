import XCTest
@testable import JarvisCore

private actor DiagnosticScript: Intelligence {
    private var decisions: [Decision]
    init(_ decisions: [Decision]) { self.decisions = decisions }
    func decide(prompt: String) async throws -> Decision {
        guard !decisions.isEmpty else { throw AgentError.invalidDecision }
        return decisions.removeFirst()
    }
}

private struct SyntheticSemanticMatcher: MemorySemanticMatcher {
    func distance(query: String, note: String) -> Double? {
        let query = query.lowercased()
        return query.contains("seed") || query.contains("germination") || query.contains("plant") || query.contains("tree") ? 0 : nil
    }
}

@MainActor final class InferenceDiagnosticsTests: XCTestCase {
    func testSyntheticSuiteReportsContextAndPolicyWithoutContent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let decisions = [
            Decision("reply", "A seed is a plant embryo."),
            Decision("search_memory", "seed"), Decision("reply", "A seed grows through germination."),
            Decision("reply", "Germination starts after water is absorbed."),
            Decision("reply", "A seed grows into a plant."),
            Decision("reply", "A tree grows from a seed."),
            Decision("reply", "A battery converts chemical energy."),
            Decision("reply", "Water starts seed germination."),
            Decision("reply", "Water starts seed germination.")
        ]
        let environment = InferenceDiagnosticEnvironment(device: "iPhone", operatingSystem: "iOS test", appVersion: "0.0", build: "1")

        let report = try await PhysicalInferenceDiagnostics.run(
            engine: DiagnosticScript(decisions), root: root, environment: environment,
            memoryMatcher: SyntheticSemanticMatcher(), directReply: { request in
                if request.contains("battery") { throw InferenceFailure.generation }
                return "Synthetic direct response"
            }
        )

        XCTAssertEqual(report.schemaVersion, 2)
        XCTAssertEqual(report.observations.map(\.scenario), [
            "basic-generation", "no-tools-no-memory", "germination-paraphrase", "plant-from-seed",
            "related-tree-growth", "unrelated-battery", "germination-repeat-1", "germination-repeat-2"
        ])
        XCTAssertTrue(report.observations.allSatisfy { $0.terminalState == Status.complete.rawValue })
        XCTAssertTrue(report.observations[1].deniedPolicyPresented)
        XCTAssertEqual(report.observations[1].syntheticPriorContextAbsent, true)
        XCTAssertEqual(report.observations[2].memorySelectionMatchedExpectation, true)
        XCTAssertEqual(report.observations[5].memorySelectionMatchedExpectation, true)
        XCTAssertTrue(report.observations.allSatisfy { $0.assistantReplyCharacters > 0 })

        XCTAssertTrue(report.observations.allSatisfy { $0.failure == nil })
        XCTAssertEqual(report.observations[5].direct?.failure, .generation)
        XCTAssertEqual(report.observations[5].direct?.replyCharacters, 0)
        XCTAssertNil(report.observations[0].direct?.failure)
        XCTAssertGreaterThan(report.observations[0].direct?.replyCharacters ?? 0, 0)

        let encoded = try JSONEncoder().encode(report)
        let serialized = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(serialized.contains("SYNTHETIC_DIAGNOSTIC"))
        XCTAssertFalse(serialized.contains("Synthetic direct response"))
        XCTAssertFalse(serialized.contains("A seed grows through germination."))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testAgentFailuresPreserveDirectComparison() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try await PhysicalInferenceDiagnostics.run(
            engine: DiagnosticScript([.init("reply", " "), .init("save_memory", "synthetic"),
                                      .init("save_memory", "synthetic")]),
            root: root,
            environment: .init(device: "test", operatingSystem: "test", appVersion: "0", build: "1"),
            directReply: { _ in "Synthetic answer" }
        )
        XCTAssertEqual(report.observations[0].failure, .emptyReply)
        // The second scenario prohibits tools and consumes both blocked proposals.
        XCTAssertEqual(report.observations[1].failure, .rejectedDecision)
        XCTAssertFalse(report.observations[1].pendingApproval)
        XCTAssertEqual(report.observations[1].syntheticPriorContextAbsent, true)
        XCTAssertNil(report.observations[1].direct?.failure)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
}
