import Foundation

/// Application-owned reminder parameters. A model response cannot supply a
/// destination list or grant permission to create the reminder.
public struct BriefingReminder: Codable, Sendable, Equatable {
    public let title: String
    public let dueAt: Date

    public init(title: String, dueAt: Date) throws {
        guard !title.isEmpty, title == title.trimmingCharacters(in: .whitespacesAndNewlines),
              title.utf8.count <= 160, !title.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              dueAt.timeIntervalSince1970.isFinite,
              dueAt.timeIntervalSince1970.rounded(.down) == dueAt.timeIntervalSince1970 else {
            throw NativeDeviceCapabilityError.invalidInput
        }
        self.title = title
        self.dueAt = dueAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(title: values.decode(String.self, forKey: .title),
                      dueAt: values.decode(Date.self, forKey: .dueAt))
    }
}

public struct BriefingAnalysis: Sendable, Equatable {
    public struct Event: Decodable, Sendable, Equatable {
        public let title: String
        public let start: Date
        public let end: Date
        public let allDay: Bool
    }

    public struct Reminder: Decodable, Sendable, Equatable {
        public let title: String
        public let dueAt: Date
    }

    public let events: [Event]
    public let reminders: [Reminder]
    public let overlappingEventPairs: Int
    public let isPartial: Bool
}

public enum ReminderWriteState: Equatable, Sendable {
    case ready, requiresReconciliation, completed
}

public enum BriefingError: Error, Equatable {
    case busy, missingBriefing, writeAlreadyAttempted, dueDatePassed
}

/// Executes the fixed read/read/analyze sequence and an independently approved
/// write. All callers for a task must use the same stable ID and trusted,
/// app-owned checkpoint directory. A started write is never replayed.
public actor PersonalBriefing {
    private struct CalendarPage: Decodable {
        let events: [BriefingAnalysis.Event]
        let truncated: Bool
    }

    private struct RemindersPage: Decodable {
        let reminders: [BriefingAnalysis.Reminder]
        let truncated: Bool
    }

    private let dispatcher: NativeDeviceCapabilityDispatcher
    private let checkpoint: URL
    private var busy = false
    private var preparedReminder: BriefingReminder?

    public init(id: UUID, checkpointDirectory: URL, dispatcher: NativeDeviceCapabilityDispatcher) {
        self.dispatcher = dispatcher
        checkpoint = checkpointDirectory.appendingPathComponent("briefing-\(id.uuidString).write")
    }

    public func writeState() throws -> ReminderWriteState {
        // Only absence of the expected directory entry permits a first write.
        let entries = try FileManager.default.contentsOfDirectory(atPath: checkpoint.deletingLastPathComponent().path)
        guard entries.contains(checkpoint.lastPathComponent) else { return .ready }
        let attributes = try FileManager.default.attributesOfItem(atPath: checkpoint.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              attributes[.size] as? Int == 1,
              let state = try? Data(contentsOf: checkpoint), state == Data([1]) else {
            return .requiresReconciliation
        }
        return .completed
    }

    /// The same narrow UTC interval is passed to both registered adapters.
    /// A successful analysis binds this exact optional reminder to the next step.
    public func prepare(windowInput: String, reminder: BriefingReminder?) async throws -> BriefingAnalysis {
        guard !busy else { throw BriefingError.busy }
        busy = true
        preparedReminder = nil
        defer { busy = false }

        let window = try CalendarReadWindow(input: windowInput)
        let calendar = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue,
                                                   input: windowInput)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let page = try? decoder.decode(CalendarPage.self, from: Data(calendar.content.utf8)),
              page.events.count <= 20, page.events.allSatisfy({
                  $0.start < $0.end && $0.start < window.end && $0.end > window.start
                      && $0.title.utf8.count <= 16_000
              }) else {
            throw NativeDeviceCapabilityError.invalidResult
        }
        let reminders = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.reminderRead.rawValue,
                                                    input: windowInput)
        guard let list = try? decoder.decode(RemindersPage.self, from: Data(reminders.content.utf8)),
              list.reminders.count <= 20, list.reminders.allSatisfy({
                  $0.dueAt >= window.start && $0.dueAt < window.end && $0.title.utf8.count <= 16_000
              }) else {
            throw NativeDeviceCapabilityError.invalidResult
        }
        try Task.checkCancellation()

        let timed = page.events.filter { !$0.allDay }
        var overlaps = 0
        for (index, event) in timed.enumerated() {
            for other in timed.dropFirst(index + 1) where event.start < other.end && other.start < event.end {
                overlaps += 1
            }
        }
        preparedReminder = reminder
        return BriefingAnalysis(events: page.events, reminders: list.reminders,
                                overlappingEventPairs: overlaps, isPartial: page.truncated || list.truncated)
    }

    /// The dispatcher obtains fresh app authorization and human approval over
    /// the exact serialized draft. Consume the write slot before any provider
    /// call. If execution or persistence is interrupted, reconcile manually.
    public func createPreparedReminder() async throws -> NativeDeviceCapabilityResult {
        guard !busy else { throw BriefingError.busy }
        guard try writeState() == .ready else { throw BriefingError.writeAlreadyAttempted }
        guard let reminder = preparedReminder else { throw BriefingError.missingBriefing }
        guard reminder.dueAt > Date() else { throw BriefingError.dueDatePassed }
        busy = true
        defer { busy = false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let input = String(decoding: try encoder.encode(reminder), as: UTF8.self)
        try Task.checkCancellation()
        let checkpoint = self.checkpoint
        let receipt = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.reminderCreate.rawValue,
                                                  input: input) {
            try Task.checkCancellation()
            guard reminder.dueAt > Date() else { throw BriefingError.dueDatePassed }
            try Data([0]).write(to: checkpoint, options: .withoutOverwriting)
        }
        preparedReminder = nil
        guard !receipt.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeDeviceCapabilityError.invalidResult
        }
        try Data([1]).write(to: checkpoint, options: .atomic)
        return receipt
    }
}
