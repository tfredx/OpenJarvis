import EventKit
import Foundation
import JarvisCore

/// Requires the app to provide an explicit user-selected calendar scope.
/// Registration and the OS permission request belong to a separate UI flow.
@MainActor final class EventKitCalendarReader: NativeDeviceCapability {
    nonisolated let capabilityID = NativeDeviceCapabilityID.calendarRead
    private let calendarIDs: Set<String>

    init(calendarIDs: Set<String>) {
        self.calendarIDs = calendarIDs
    }

    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult {
        try Task.checkCancellation()
        guard request.capability == capabilityID else { throw NativeDeviceCapabilityError.unsupported }
        let window = try CalendarReadWindow(input: request.input)
        guard !calendarIDs.isEmpty, calendarIDs.count <= 10,
              EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }

        let store = EKEventStore()
        let calendars = calendarIDs.compactMap { store.calendar(withIdentifier: $0) }
        guard calendars.count == calendarIDs.count,
              calendars.allSatisfy({ $0.allowedEntityTypes.contains(.event) }) else {
            throw NativeDeviceCapabilityError.unavailable
        }
        let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: calendars)
        let selected = store.events(matching: predicate).compactMap { event -> EventSummary? in
            guard let calendar = event.calendar, calendarIDs.contains(calendar.calendarIdentifier),
                  let start = event.startDate, let end = event.endDate,
                  start < window.end, end > window.start else { return nil }
            let title = String((event.title ?? "").prefix(160))
            return EventSummary(title: title, start: start, end: end, allDay: event.isAllDay)
        }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end < $1.end }
            return $0.title < $1.title
        }
        try Task.checkCancellation()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw NativeDeviceCapabilityError.denied
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(ResultPage(events: Array(selected.prefix(20)), truncated: selected.count > 20))
        guard data.count <= 16_000 else { throw NativeDeviceCapabilityError.invalidResult }
        return NativeDeviceCapabilityResult(content: String(decoding: data, as: UTF8.self))
    }

    private struct EventSummary: Encodable {
        let title: String
        let start: Date
        let end: Date
        let allDay: Bool
    }

    private struct ResultPage: Encodable {
        let events: [EventSummary]
        let truncated: Bool
    }
}
