import Foundation

public struct SQLiteMigrationReport: Equatable, Sendable {
    public let sessionCount: Int
    public let messageCount: Int
    public let approvedMemoryCount: Int
    public let pendingApprovalCount: Int
    public let interruptedTaskCount: Int
}

public enum SQLiteMigrationError: Error, LocalizedError, Equatable {
    case sourceChanged, archiveMismatch, cleanupFailed
    public var errorDescription: String? {
        switch self {
        case .sourceChanged: "Session data changed during migration verification. No cutover occurred."
        case .archiveMismatch: "SQLite verification did not match the source archive. No cutover occurred."
        case .cleanupFailed: "The temporary migration copy could not be removed. Recovery is required before enabling migration."
        }
    }
}

/// A rehearsal only: no persistent migration marker, source deletion or cutover.
/// The caller must hold exclusive repository ownership across this synchronous call.
/// A process kill can leave a staging directory; do not enable this in the app until
/// recovery and privacy-aware cleanup of interrupted staging are implemented.
@MainActor enum SQLiteShadowMigration {
    static func rehearse(scratchRoot: URL, source: () throws -> SQLiteSessionArchive) throws -> SQLiteMigrationReport {
        let original = try source()
        let fm = FileManager.default
        let stage = scratchRoot.appendingPathComponent("jarvis-shadow-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: false)
        let report: SQLiteMigrationReport
        do {
            #if os(iOS)
            try fm.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: stage.path)
            var directory = stage
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            #endif
            let database = stage.appendingPathComponent("sessions.sqlite3")
            do {
                let store = try SQLiteSessionStore(url: database)
                defer { store.close() }
                try store.importArchive(original)
            }
            let reopened: SQLiteSessionArchive
            do {
                let store = try SQLiteSessionStore(url: database)
                defer { store.close() }
                reopened = try store.loadArchive()
            }
            guard reopened == original else { throw SQLiteMigrationError.archiveMismatch }
            guard try source() == original else { throw SQLiteMigrationError.sourceChanged }
            let snapshots = try reopened.sessions.map { try JSONDecoder().decode(Snapshot.self, from: $0.snapshot) }
            report = SQLiteMigrationReport(
                sessionCount: snapshots.count,
                messageCount: snapshots.reduce(0) { $0 + $1.messages.count },
                approvedMemoryCount: snapshots.reduce(0) { $0 + $1.notes.count },
                pendingApprovalCount: snapshots.filter { $0.status == .approval }.count,
                interruptedTaskCount: snapshots.filter { $0.status == .running }.count
            )
        } catch {
            do { try fm.removeItem(at: stage) } catch { throw SQLiteMigrationError.cleanupFailed }
            throw error
        }
        do { try fm.removeItem(at: stage) } catch { throw SQLiteMigrationError.cleanupFailed }
        return report
    }
}
