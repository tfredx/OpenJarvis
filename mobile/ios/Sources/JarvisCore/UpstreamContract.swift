import Foundation

/// JSON contract matching upstream openjarvis_core::Message and Conversation.
public struct WireMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable { case user, assistant, system, tool }
    public let role: Role
    public let content: String
    public init(role: Role, content: String) { self.role = role; self.content = content }
}
public struct WireConversation: Codable, Sendable, Equatable {
    public let messages: [WireMessage]
    public let max_messages: Int
    public init(messages: [WireMessage], maxMessages: Int) { self.messages = messages; self.max_messages = maxMessages }
}
public protocol ConversationBridge: Sendable {
    func window(_ conversation: WireConversation) throws -> [WireMessage]
}
public enum BridgeError: Error { case invalidWindow, invalidRole, nativeFailure }
/// A deliberately narrow bridge. Rust is used only for upstream conversation windowing,
/// never for permissions or tool execution. Validate the returned content against the input.
public struct SwiftConversationBridge: ConversationBridge {
    public init() {}
    public func window(_ conversation: WireConversation) throws -> [WireMessage] {
        guard (1...32).contains(conversation.max_messages) else { throw BridgeError.invalidWindow }
        return Array(conversation.messages.suffix(conversation.max_messages))
    }
}
public func verifiedWindow(_ conversation: WireConversation, using bridge: any ConversationBridge) throws -> [WireMessage] {
    let expected = try SwiftConversationBridge().window(conversation)
    let actual = try bridge.window(conversation)
    guard actual == expected else { throw BridgeError.nativeFailure }
    return actual
}
