import Foundation

public struct Note: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID; public let text: String
    public init(_ text: String) { id = UUID(); self.text = text }
}
