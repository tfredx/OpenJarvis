import Foundation

public struct SessionSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
}

public enum SessionError: Error, LocalizedError, Equatable {
    case invalidCatalog, unsupportedVersion, missingSnapshot, unknownSession
    case invalidTitle, unresolvedTask, recoveryRequired, unexpectedLegacy, orphanedSnapshot
    public var errorDescription: String? {
        switch self {
        case .invalidCatalog: "The session catalog is inconsistent. Existing data was not reset."
        case .unsupportedVersion: "This session catalog requires a different app version."
        case .missingSnapshot: "A session snapshot is missing. Restore the data before continuing."
        case .unknownSession: "That conversation does not exist."
        case .invalidTitle: "Enter a title between 1 and 80 characters."
        case .unresolvedTask: "Resolve or discard the current task before changing sessions."
        case .recoveryRequired: "Reopen the repository to finish interrupted storage work."
        case .unexpectedLegacy: "An unexpected legacy conversation exists. Data was not overwritten."
        case .orphanedSnapshot: "An unindexed session snapshot exists. Data was not overwritten."
        }
    }
}

/// Metadata and per-session Agent snapshots. One owner must serialize access and
/// release any live Agent writer before switching, deleting or erasing sessions.
/// Atomic files + a persisted transition allow recovery after process interruption.
/// No global memory, synchronization, or forensic deletion guarantee.
@MainActor public final class SessionRepository {
    private struct Catalog: Codable, Equatable {
        var version = 1
        var activeID: UUID
        var sessions: [SessionSummary]
        var initializing: UUID? = nil
        var migratingLegacy = false
        var retired: [UUID] = []
    }
    private let root: URL
    private let catalogURL: URL
    private let legacyURL: URL
    private let fm = FileManager.default
    private var catalog: Catalog

    public init(root: URL) throws {
        self.root = root
        catalogURL = root.appendingPathComponent("sessions.json")
        legacyURL = root.appendingPathComponent("state.json")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        if fm.fileExists(atPath: catalogURL.path) {
            let data = try Data(contentsOf: catalogURL)
            struct Version: Decodable { let version: Int }
            guard try JSONDecoder().decode(Version.self, from: data).version == 1 else {
                throw SessionError.unsupportedVersion
            }
            catalog = try JSONDecoder().decode(Catalog.self, from: data)
        } else {
            let legacy = fm.fileExists(atPath: legacyURL.path)
            if legacy { _ = try Self.decodeSnapshot(at: legacyURL) }
            guard try Self.managedIDs(in: root).isEmpty else { throw SessionError.orphanedSnapshot }
            let first = SessionSummary(id: UUID(), title: legacy ? "Imported conversation" : "New conversation", createdAt: Date())
            catalog = Catalog(activeID: first.id, sessions: [first], initializing: first.id, migratingLegacy: legacy)
            try persist(catalog)
        }
        try recover()
    }

    public var sessions: [SessionSummary] { catalog.sessions }
    public var activeID: UUID { catalog.activeID }

    public func activeSnapshotURL() throws -> URL {
        try ready()
        let url = snapshotURL(catalog.activeID)
        _ = try Self.decodeSnapshot(at: url)
        return url
    }

    /// Read-only export; the sole owner must hold the repository idle.
    /// Reject external catalog changes rather than exporting stale metadata.
    func exportArchive() throws -> SQLiteSessionArchive {
        try ready()
        let catalogBytes = try Data(contentsOf: catalogURL)
        guard try JSONDecoder().decode(Catalog.self, from: catalogBytes) == catalog else {
            throw SessionError.recoveryRequired
        }
        let ids = Set(catalog.sessions.map(\.id))
        guard try Self.managedIDs(in: root).isSubset(of: ids) else {
            throw SessionError.orphanedSnapshot
        }
        let records = try catalog.sessions.map { item -> SQLiteSessionRecord in
            let url = snapshotURL(item.id)
            guard fm.fileExists(atPath: url.path) else { throw SessionError.missingSnapshot }
            let bytes = try Data(contentsOf: url)
            _ = try JSONDecoder().decode(Snapshot.self, from: bytes)
            return SQLiteSessionRecord(id: item.id, title: item.title, createdAt: item.createdAt, snapshot: bytes)
        }
        guard try Data(contentsOf: catalogURL) == catalogBytes,
              try Self.managedIDs(in: root) == ids else { throw SessionError.recoveryRequired }
        return SQLiteSessionArchive(activeID: catalog.activeID, sessions: records)
    }

    @discardableResult public func create(title: String) throws -> SessionSummary {
        try ready(); try requireResolved(catalog.activeID)
        let item = SessionSummary(id: UUID(), title: try normalized(title), createdAt: Date())
        var next = catalog
        next.sessions.append(item); next.activeID = item.id; next.initializing = item.id
        try persist(next); try recover()
        return item
    }

    public func rename(_ id: UUID, title: String) throws {
        try ready()
        guard let i = catalog.sessions.firstIndex(where: { $0.id == id }) else { throw SessionError.unknownSession }
        var next = catalog; next.sessions[i].title = try normalized(title)
        try persist(next)
    }

    public func select(_ id: UUID) throws {
        try ready()
        guard catalog.sessions.contains(where: { $0.id == id }) else { throw SessionError.unknownSession }
        guard id != catalog.activeID else { return }
        try requireResolved(catalog.activeID)
        _ = try Self.decodeSnapshot(at: snapshotURL(id))
        var next = catalog; next.activeID = id; try persist(next)
    }

    public func delete(_ id: UUID) throws {
        try ready()
        guard catalog.sessions.contains(where: { $0.id == id }) else { throw SessionError.unknownSession }
        try requireResolved(catalog.activeID); try requireResolved(id)
        if catalog.sessions.count == 1 { try eraseAll(); return }
        var next = catalog
        next.sessions.removeAll { $0.id == id }; next.retired = [id]
        if next.activeID == id { next.activeID = next.sessions[0].id }
        try persist(next); try recover()
    }

    /// Explicit user action only, after discarding/resolving any pending task.
    public func eraseAll() throws {
        try ready()
        for item in catalog.sessions { try requireResolved(item.id) }
        let first = SessionSummary(id: UUID(), title: "New conversation", createdAt: Date())
        let next = Catalog(activeID: first.id, sessions: [first], initializing: first.id, retired: catalog.sessions.map(\.id))
        try persist(next); try recover()
    }

    private func normalized(_ title: String) throws -> String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(value.count) else { throw SessionError.invalidTitle }
        return value
    }
    private func snapshotURL(_ id: UUID) -> URL {
        root.appendingPathComponent("session-\(id.uuidString).json")
    }
    private static func decodeSnapshot(at url: URL) throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SessionError.missingSnapshot }
        return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
    }
    private static func managedIDs(in root: URL) throws -> Set<UUID> {
        var ids = Set<UUID>()
        for name in try FileManager.default.contentsOfDirectory(atPath: root.path) {
            guard name.hasPrefix("session-"), name.hasSuffix(".json") else { continue }
            guard let id = UUID(uuidString: String(name.dropFirst(8).dropLast(5))),
                  name == "session-\(id.uuidString).json", ids.insert(id).inserted else { throw SessionError.orphanedSnapshot }
        }
        return ids
    }
    private func requireResolved(_ id: UUID) throws {
        let snapshot = try Self.decodeSnapshot(at: snapshotURL(id))
        guard snapshot.status != .running, snapshot.status != .approval else { throw SessionError.unresolvedTask }
    }
    private func ready() throws {
        guard catalog.initializing == nil, catalog.retired.isEmpty, !catalog.migratingLegacy else {
            throw SessionError.recoveryRequired
        }
        guard !fm.fileExists(atPath: legacyURL.path) else { throw SessionError.unexpectedLegacy }
    }
    private func persist(_ next: Catalog) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(next).write(to: catalogURL, options: .atomic)
        catalog = next
    }
    private func recover() throws {
        let ids = Set(catalog.sessions.map(\.id)); let retired = Set(catalog.retired)
        guard catalog.version == 1, !ids.isEmpty, ids.count == catalog.sessions.count,
              ids.contains(catalog.activeID), retired.count == catalog.retired.count,
              ids.isDisjoint(with: retired),
              catalog.initializing == nil || catalog.initializing == catalog.activeID,
              !catalog.migratingLegacy || (catalog.initializing != nil && catalog.sessions.count == 1 && retired.isEmpty) else {
            throw SessionError.invalidCatalog
        }
        for item in catalog.sessions { guard try normalized(item.title) == item.title else { throw SessionError.invalidCatalog } }
        guard try Self.managedIDs(in: root).isSubset(of: ids.union(retired)) else { throw SessionError.orphanedSnapshot }
        let legacy = fm.fileExists(atPath: legacyURL.path)
        guard !legacy || catalog.migratingLegacy else { throw SessionError.unexpectedLegacy }
        for id in ids where id != catalog.initializing { _ = try Self.decodeSnapshot(at: snapshotURL(id)) }
        if let id = catalog.initializing {
            let url = snapshotURL(id)
            let exists = fm.fileExists(atPath: url.path)
            if catalog.migratingLegacy {
                if legacy {
                    let bytes = try Data(contentsOf: legacyURL)
                    _ = try JSONDecoder().decode(Snapshot.self, from: bytes)
                    if exists {
                        guard try Data(contentsOf: url) == bytes else { throw SessionError.invalidCatalog }
                    } else { try bytes.write(to: url, options: .atomic) }
                } else if !exists { throw SessionError.missingSnapshot }
                _ = try Self.decodeSnapshot(at: url)
            } else if exists {
                let empty = try Self.decodeSnapshot(at: url)
                guard empty.messages.isEmpty, empty.notes.isEmpty, empty.status == .idle,
                      empty.pending == nil, empty.steps == 0, empty.memoryWriteDenied != true else { throw SessionError.invalidCatalog }
            } else { try JSONEncoder().encode(Snapshot()).write(to: url, options: .atomic) }
        }
        if legacy { try fm.removeItem(at: legacyURL) }
        for id in retired {
            let url = snapshotURL(id)
            if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        }
        if catalog.initializing != nil || !retired.isEmpty || catalog.migratingLegacy {
            var next = catalog; next.initializing = nil; next.retired = []; next.migratingLegacy = false
            try persist(next)
        }
    }
}
