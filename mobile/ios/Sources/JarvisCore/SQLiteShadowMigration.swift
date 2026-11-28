import Foundation

public struct SQLiteMigrationReport: Equatable, Sendable {
    public let sessionCount: Int
    public let messageCount: Int
    public let approvedMemoryCount: Int
    public let pendingApprovalCount: Int
    public let interruptedTaskCount: Int
}

public enum SQLiteMigrationError: Error, LocalizedError, Equatable {
    case sourceChanged, archiveMismatch, cleanupFailed, invalidJournal, untrackedStage
    public var errorDescription: String? {
        switch self {
        case .sourceChanged: "Session data changed during migration verification. No cutover occurred."
        case .archiveMismatch: "SQLite verification did not match the source archive. No cutover occurred."
        case .cleanupFailed: "The temporary migration copy could not be removed. Recovery is required before enabling migration."
        case .invalidJournal: "The migration recovery record is invalid. Existing data was left untouched."
        case .untrackedStage: "An untracked migration staging directory exists. Existing data was left untouched."
        }
    }
}

/// A content-free recovery record. The journal is written before its staging
/// directory is created, so every directory created by this code has an intent
/// record that a later launch can validate and clean up.
@MainActor enum SQLiteMigrationJournal {
    struct Record: Codable, Equatable {
        let version: Int
        let stageDirectory: String
    }

    static let journalName = "jarvis-shadow-migration.json"
    static let stagePrefix = "jarvis-shadow-"

    static func recover(in root: URL) throws {
        let fm = FileManager.default
        let journal = root.appendingPathComponent(journalName)
        let entries = try fm.contentsOfDirectory(atPath: root.path)
        if !entries.contains(journalName) {
            guard !entries.contains(where: { $0.hasPrefix(stagePrefix) }) else {
                throw SQLiteMigrationError.untrackedStage
            }
            return
        }
        guard try itemType(at: journal, fileManager: fm) == .typeRegular,
              let data = try? Data(contentsOf: journal),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == 1,
              let id = UUID(uuidString: String(record.stageDirectory.dropFirst(stagePrefix.count))),
              record.stageDirectory == stagePrefix + id.uuidString else {
            throw SQLiteMigrationError.invalidJournal
        }
        let stages = entries.filter { $0.hasPrefix(stagePrefix) && $0 != journalName }
        guard stages.isEmpty || stages == [record.stageDirectory] else {
            throw SQLiteMigrationError.untrackedStage
        }
        let stage = root.appendingPathComponent(record.stageDirectory, isDirectory: true)
        if stages.contains(record.stageDirectory) {
            guard try itemType(at: stage, fileManager: fm) == .typeDirectory else {
                throw SQLiteMigrationError.invalidJournal
            }
            try fm.removeItem(at: stage)
        }
        try fm.removeItem(at: journal)
    }

    static func prepare(in root: URL) throws -> URL {
        try recover(in: root)
        let fm = FileManager.default
        let id = UUID()
        let name = stagePrefix + id.uuidString
        let stage = root.appendingPathComponent(name, isDirectory: true)
        let journal = root.appendingPathComponent(journalName)
        let data = try JSONEncoder().encode(Record(version: 1, stageDirectory: name))
        try data.write(to: journal, options: .atomic)
        do {
            try protect(journal, fileManager: fm)
            try fm.createDirectory(at: stage, withIntermediateDirectories: false)
            try protect(stage, fileManager: fm)
            return stage
        } catch {
            // Leave the journal in place if cleanup fails; recovery will retry.
            try recover(in: root)
            throw error
        }
    }

    static func finish(_ stage: URL) throws {
        let fm = FileManager.default
        let root = stage.deletingLastPathComponent()
        let journal = root.appendingPathComponent(journalName)
        guard try itemType(at: journal, fileManager: fm) == .typeRegular,
              let data = try? Data(contentsOf: journal),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == 1,
              let id = UUID(uuidString: String(record.stageDirectory.dropFirst(stagePrefix.count))),
              record.stageDirectory == stagePrefix + id.uuidString,
              stage.lastPathComponent == record.stageDirectory else {
            throw SQLiteMigrationError.invalidJournal
        }
        guard try itemType(at: stage, fileManager: fm) == .typeDirectory else {
            throw SQLiteMigrationError.invalidJournal
        }
        try fm.removeItem(at: stage)
        try fm.removeItem(at: journal)
    }

    private static func itemType(at url: URL, fileManager: FileManager) throws -> FileAttributeType? {
        try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
    }

    private static func protect(_ url: URL, fileManager: FileManager) throws {
        #if os(iOS)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        var protectedURL = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedURL.setResourceValues(values)
        #endif
    }
}

/// A rehearsal only: no persistent migration marker, source deletion or cutover.
/// The caller must hold exclusive repository ownership across this synchronous call.
/// A process kill can leave a journaled staging directory. The next rehearsal can
/// recover that stage; malformed or untracked stages fail closed. This is not a
/// production migration journal or a durability guarantee for power loss.
@MainActor enum SQLiteShadowMigration {
    static func rehearse(scratchRoot: URL, source: () throws -> SQLiteSessionArchive) throws -> SQLiteMigrationReport {
        let original = try source()
        let stage = try SQLiteMigrationJournal.prepare(in: scratchRoot)
        let report: SQLiteMigrationReport
        do {
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
            do { try SQLiteMigrationJournal.finish(stage) } catch { throw SQLiteMigrationError.cleanupFailed }
            throw error
        }
        do { try SQLiteMigrationJournal.finish(stage) } catch { throw SQLiteMigrationError.cleanupFailed }
        return report
    }
}
