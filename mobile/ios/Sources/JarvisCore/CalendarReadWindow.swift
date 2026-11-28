import Foundation

/// A narrow UTC window accepted by the read-only Calendar capability.
public struct CalendarReadWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(input: String) throws {
        let formatter = ISO8601DateFormatter()
        guard input.utf8.count <= 256,
              let object = try? JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: String],
              Set(object.keys) == ["start", "end"],
              let startText = object["start"], let endText = object["end"],
              let start = formatter.date(from: startText), let end = formatter.date(from: endText),
              formatter.string(from: start) == startText, formatter.string(from: end) == endText,
              start < end, end.timeIntervalSince(start) <= 7 * 24 * 60 * 60 else {
            throw NativeDeviceCapabilityError.invalidInput
        }
        self.start = start
        self.end = end
    }
}
