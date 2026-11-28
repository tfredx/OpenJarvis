import Foundation

/// A synthetic, local-only probe suite for collecting device inference evidence.
/// The report deliberately excludes prompts, model output, notes and error text.
public struct InferenceDiagnosticEnvironment: Codable, Sendable, Equatable {
    public let device: String
    public let operatingSystem: String
    public let appVersion: String
    public let build: String

    public init(device: String, operatingSystem: String, appVersion: String, build: String) {
        self.device = device
        self.operatingSystem = operatingSystem
        self.appVersion = appVersion
        self.build = build
    }
}

public struct InferenceDiagnosticObservation: Codable, Sendable, Equatable {
    public let scenario: String
    public let elapsedMilliseconds: Int
    public let terminalState: String
    public let modelSteps: Int
    public let assistantReplyCharacters: Int
    public let pendingApproval: Bool
    public let deniedPolicyPresented: Bool
    public let memorySelectionMatchedExpectation: Bool?
    public let syntheticPriorContextAbsent: Bool?
}

public struct InferenceDiagnosticReport: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let startedAt: Date
    public let completedAt: Date
    public let environment: InferenceDiagnosticEnvironment
    public let observations: [InferenceDiagnosticObservation]

    public init(startedAt: Date, completedAt: Date, environment: InferenceDiagnosticEnvironment,
                observations: [InferenceDiagnosticObservation]) {
        schemaVersion = 1
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.environment = environment
        self.observations = observations
    }
}

public enum InferenceDiagnosticsError: Error {
    case temporaryDataCleanupFailed
}

public enum PhysicalInferenceDiagnostics {
    private static let memoryMarker = "SYNTHETIC_DIAGNOSTIC_GERMINATION_MARKER"
    private static let historyMarker = "SYNTHETIC_DIAGNOSTIC_PRIOR_HISTORY_MARKER"
    private static let memoryText = "\(memoryMarker): a seed germinates after absorbing water; its root emerges before the shoot."

    private struct Scenario: Sendable {
        let id: String
        let request: String
        let expectsMemory: Bool?
        let deniesContext: Bool
    }

    private static let scenarios = [
        Scenario(id: "basic-generation", request: "What is a seed? Answer in one sentence.", expectsMemory: nil, deniesContext: false),
        Scenario(id: "no-tools-no-memory", request: "Explain how a seed grows. Do not use tools or memory.", expectsMemory: false, deniesContext: true),
        Scenario(id: "germination-paraphrase", request: "Describe the process of germination.", expectsMemory: true, deniesContext: false),
        Scenario(id: "plant-from-seed", request: "How does a plant grow from a seed?", expectsMemory: true, deniesContext: false),
        Scenario(id: "related-tree-growth", request: "Explain how a tree grows from a seed.", expectsMemory: true, deniesContext: false),
        Scenario(id: "unrelated-battery", request: "Explain how a battery works.", expectsMemory: false, deniesContext: false),
        Scenario(id: "germination-repeat-1", request: "Explain how a seed grows.", expectsMemory: true, deniesContext: false),
        Scenario(id: "germination-repeat-2", request: "Explain how a seed grows.", expectsMemory: true, deniesContext: false)
    ]

    /// Runs against an injected local inference provider using only synthetic fixtures.
    /// `root` should be the app's protected Application Support directory.
    public static func run(engine: any Intelligence, root: URL,
                           environment: InferenceDiagnosticEnvironment,
                           memoryMatcher: any MemorySemanticMatcher = OnDeviceMemorySemanticMatcher()) async throws -> InferenceDiagnosticReport {
        let startedAt = Date()
        let temporaryDirectory = root.appendingPathComponent("diagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        do {
            var observations: [InferenceDiagnosticObservation] = []
            for scenario in scenarios {
                var seed = Snapshot()
                seed.messages = [Message("user", historyMarker)]
                seed.notes = [Note(memoryText)]
                let file = temporaryDirectory.appendingPathComponent("\(scenario.id).json")
                try JSONEncoder().encode(seed).write(to: file, options: .atomic)

                let recorder = DiagnosticIntelligence(base: engine)
                let agent = try Agent(engine: recorder, file: file, maxSteps: 4, memoryMatcher: memoryMatcher)
                let startTime = ProcessInfo.processInfo.systemUptime
                do { _ = try await agent.start(scenario.request) }
                catch { /* Record the terminal state; never serialize model/error text. */ }
                let elapsed = max(0, Int((ProcessInfo.processInfo.systemUptime - startTime) * 1000))
                let snapshot = await agent.snapshot()
                let trace = await recorder.trace()
                let reply = snapshot.messages.last(where: { $0.role == "assistant" })?.text ?? ""
                let contextWasAbsent = scenario.deniesContext
                    ? !trace.contains(where: { $0.contains(memoryMarker) || $0.contains(historyMarker) })
                    : nil
                let expectedMemoryInContext = scenario.expectsMemory.map { expected in
                    let wasIncluded = trace.contains(where: { $0.contains(memoryMarker) })
                    return expected == wasIncluded
                }
                observations.append(InferenceDiagnosticObservation(
                    scenario: scenario.id,
                    elapsedMilliseconds: elapsed,
                    terminalState: snapshot.status.rawValue,
                    modelSteps: snapshot.steps,
                    assistantReplyCharacters: reply.count,
                    pendingApproval: snapshot.pending != nil,
                    deniedPolicyPresented: scenario.deniesContext && trace.contains(where: {
                        $0.contains("Only action allowed for this task: reply")
                    }),
                    memorySelectionMatchedExpectation: expectedMemoryInContext,
                    syntheticPriorContextAbsent: contextWasAbsent
                ))
            }

            let report = InferenceDiagnosticReport(startedAt: startedAt, completedAt: Date(),
                                                   environment: environment, observations: observations)
            do { try FileManager.default.removeItem(at: temporaryDirectory) }
            catch { throw InferenceDiagnosticsError.temporaryDataCleanupFailed }
            return report
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }
    }
}

private actor DiagnosticIntelligence: Intelligence {
    private let base: any Intelligence
    private var prompts: [String] = []

    init(base: any Intelligence) { self.base = base }

    func decide(prompt: String) async throws -> Decision {
        prompts.append(prompt)
        return try await base.decide(prompt: prompt)
    }

    func trace() -> [String] { prompts }
}
