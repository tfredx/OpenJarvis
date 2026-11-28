import EventKit
import Foundation
import JarvisCore

/// The selected list IDs come from app settings. This adapter never invokes
/// the OS permission prompt and may only be registered after scope review.
@MainActor final class EventKitRemindersReader: NativeDeviceCapability {
    nonisolated let capabilityID = NativeDeviceCapabilityID.reminderRead
    private let listIDs: Set<String>

    init(listIDs: Set<String>) {
        self.listIDs = listIDs
    }

    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult {
        try Task.checkCancellation()
        guard request.capability == capabilityID else { throw NativeDeviceCapabilityError.unsupported }
        let window = try CalendarReadWindow(input: request.input)
        let listIDs = self.listIDs
        guard (1...10).contains(listIDs.count),
              EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }
        let store = EKEventStore()
        let lists = listIDs.compactMap { store.calendar(withIdentifier: $0) }
        guard lists.count == listIDs.count,
              lists.allSatisfy({ $0.allowedEntityTypes.contains(.reminder) }) else {
            throw NativeDeviceCapabilityError.unavailable
        }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: window.start, ending: window.end, calendars: lists
        )
        let page: Page? = await withCheckedContinuation { continuation in
            _ = store.fetchReminders(matching: predicate) { @Sendable reminders in
                guard let reminders else { continuation.resume(returning: nil); return }
                let items = reminders.compactMap { item -> Item? in
                    guard !item.isCompleted, let list = item.calendar, listIDs.contains(list.calendarIdentifier),
                          let components = item.dueDateComponents,
                          let dueAt = (components.calendar ?? Calendar.current).date(from: components),
                          dueAt >= window.start, dueAt < window.end else {
                        return nil
                    }
                    return Item(title: String((item.title ?? "").prefix(160)), dueAt: dueAt)
                }.sorted { ($0.dueAt, $0.title) < ($1.dueAt, $1.title) }
                continuation.resume(returning: Page(reminders: Array(items.prefix(20)), truncated: items.count > 20))
            }
        }
        withExtendedLifetime(store) {}
        try Task.checkCancellation()
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }
        guard let page else { throw NativeDeviceCapabilityError.unavailable }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(page)
        guard data.count <= 16_000 else { throw NativeDeviceCapabilityError.invalidResult }
        return NativeDeviceCapabilityResult(content: String(decoding: data, as: UTF8.self))
    }

    private struct Item: Encodable, Sendable {
        let title: String
        let dueAt: Date
    }

    private struct Page: Encodable, Sendable {
        let reminders: [Item]
        let truncated: Bool
    }
}

/// Save to one explicitly selected list. The workflow dispatcher provides
/// per-invocation authorization and the user reviews the exact draft.
@MainActor final class EventKitReminderWriter: NativeDeviceCapability {
    nonisolated let capabilityID = NativeDeviceCapabilityID.reminderCreate
    private let listID: String

    init(listID: String) {
        self.listID = listID
    }

    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult {
        try Task.checkCancellation()
        guard request.capability == capabilityID else { throw NativeDeviceCapabilityError.unsupported }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard request.input.utf8.count <= 1024,
              let draft = try? decoder.decode(BriefingReminder.self, from: Data(request.input.utf8)),
              draft.dueAt > Date() else { throw NativeDeviceCapabilityError.invalidInput }
        guard !listID.isEmpty, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }

        let store = EKEventStore()
        guard let list = store.calendar(withIdentifier: listID), list.allowedEntityTypes.contains(.reminder),
              list.allowsContentModifications else { throw NativeDeviceCapabilityError.unavailable }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = draft.title
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else { throw NativeDeviceCapabilityError.invalidInput }
        calendar.timeZone = utc
        reminder.dueDateComponents = calendar.dateComponents(in: utc, from: draft.dueAt)
        try Task.checkCancellation()
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }
        try store.save(reminder, commit: true)
        return NativeDeviceCapabilityResult(content: reminder.calendarItemIdentifier)
    }
}
