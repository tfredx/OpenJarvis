import Foundation

/// Sole owner of the active Agent. Never hand its reference to app code.
@MainActor public final class SessionCoordinator {
    private let repository: SessionRepository
    private let engine: any Intelligence
    private let bridge: any ConversationBridge
    private let authorization: any ToolAuthorization
    private var agent: Agent?
    private var generation = UUID()
    public private(set) var snapshot = Snapshot()
    public private(set) var busy = false
    public var isReady: Bool { agent != nil }
    public var sessions: [SessionSummary] { repository.sessions }
    public var activeID: UUID { repository.activeID }
    public var canChangeSessions: Bool {
        isReady && !busy && snapshot.status != .running && snapshot.status != .approval && snapshot.pending == nil
    }

    public init(root: URL, engine: any Intelligence,
                bridge: any ConversationBridge = SwiftConversationBridge(),
                authorization: any ToolAuthorization = LocalToolAuthorization()) throws {
        repository = try SessionRepository(root: root)
        self.engine = engine; self.bridge = bridge; self.authorization = authorization
        try loadActive()
    }

    public func submit(_ text: String) async throws {
        guard canChangeSessions else { throw AgentError.busy }
        try await execute { try await $0.start(text) }
    }
    public func resume() async throws { try await execute { try await $0.resume() } }
    public func approve(_ allow: Bool) async throws { try await execute { try await $0.approve(allow) } }
    public func discard() async throws { try await execute { try await $0.cancel() } }
    public func deleteMemory(_ id: UUID) async throws { try await execute { try await $0.deleteMemory(id) } }

    public func create(title: String) throws {
        try transition { _ = try repository.create(title: title) }
    }
    public func select(_ id: UUID) throws {
        try transition { try repository.select(id) }
    }
    public func rename(_ id: UUID, title: String) throws {
        try transition { try repository.rename(id, title: title) }
    }
    public func delete(_ id: UUID) throws {
        try transition { try repository.delete(id) }
    }
    public func eraseAll() throws {
        try transition { try repository.eraseAll() }
    }

    /// Development verification only. No UI or automatic migration invokes this.
    /// Saved pending/running tasks are preserved; a live writer is prohibited.
    public func rehearseSQLiteMigration(scratchRoot: URL) throws -> SQLiteMigrationReport {
        guard !busy, isReady else { throw AgentError.busy }
        try verifyPersisted(snapshot)
        let report = try SQLiteShadowMigration.rehearse(scratchRoot: scratchRoot) {
            try repository.exportArchive()
        }
        try verifyPersisted(snapshot)
        return report
    }

    private func readActive() throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: repository.activeSnapshotURL()))
    }
    private func loadActive() throws {
        let url = try repository.activeSnapshotURL()
        let persisted = try readActive()
        let next = try Agent(engine: engine, file: url, bridge: bridge, authorization: authorization)
        snapshot = persisted; agent = next; generation = UUID()
    }
    private func invalidate() {
        agent = nil; snapshot = Snapshot(); generation = UUID()
    }
    private func verifyPersisted(_ expected: Snapshot) throws {
        do {
            guard try readActive() == expected else { throw SessionError.recoveryRequired }
        } catch {
            invalidate()
            throw SessionError.recoveryRequired
        }
    }

    private func transition(_ change: () throws -> Void) throws {
        guard canChangeSessions else { throw SessionError.unresolvedTask }
        try verifyPersisted(snapshot)
        let originalID = repository.activeID
        // No actor operation is running; release the old writer before touching its file.
        agent = nil; generation = UUID()
        do {
            try change()
        } catch {
            // Restore only an unchanged, fully ready selection. Never continue from
            // a partially persisted catalog transition or a different session.
            if repository.activeID == originalID {
                do { try loadActive() } catch { invalidate(); throw SessionError.recoveryRequired }
            } else { invalidate(); throw SessionError.recoveryRequired }
            throw error
        }
        do { try loadActive() }
        catch { invalidate(); throw SessionError.recoveryRequired }
    }

    private func execute(_ operation: @Sendable (Agent) async throws -> Snapshot) async throws {
        guard !busy, let writer = agent else { throw AgentError.busy }
        try verifyPersisted(snapshot)
        let token = generation; let id = repository.activeID
        busy = true; defer { busy = false }
        let result: Result<Snapshot, Error>
        do { result = .success(try await operation(writer)) }
        catch { result = .failure(error) }
        let actual = await writer.snapshot()
        guard generation == token, repository.activeID == id else {
            invalidate(); throw SessionError.recoveryRequired
        }
        // Even an error can mutate Agent's in-memory state before a failed save.
        // Refuse further operations unless the durable snapshot agrees.
        try verifyPersisted(actual)
        snapshot = actual
        _ = try result.get()
    }
}
