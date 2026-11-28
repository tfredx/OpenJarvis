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

/// Codable equivalents of the pinned upstream openjarvis-core agent contracts.
/// Field names and defaults track AgentContext, AgentResult and ToolResult at
/// `556ddf32456bdf5c40195714a3385b339b5f98f9`.
public indirect enum UpstreamJSONValue: Codable, Sendable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([UpstreamJSONValue]), object([String: UpstreamJSONValue])

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([UpstreamJSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: UpstreamJSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .string(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        }
    }
}

public struct UpstreamConversationMessage: Codable, Sendable, Equatable {
    public let role: WireMessage.Role
    public let content: String
    public let name: String?
    public let toolCalls: [UpstreamToolCall]?
    public let toolCallID: String?
    public let metadata: [String: UpstreamJSONValue]

    public init(role: WireMessage.Role, content: String, name: String? = nil,
                toolCalls: [UpstreamToolCall]? = nil, toolCallID: String? = nil,
                metadata: [String: UpstreamJSONValue] = [:]) {
        self.role = role; self.content = content; self.name = name
        self.toolCalls = toolCalls; self.toolCallID = toolCallID; self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey { case role, content, name, toolCalls = "tool_calls", toolCallID = "tool_call_id", metadata }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decode(WireMessage.Role.self, forKey: .role)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        toolCalls = try c.decodeIfPresent([UpstreamToolCall].self, forKey: .toolCalls)
        toolCallID = try c.decodeIfPresent(String.self, forKey: .toolCallID)
        metadata = try c.decodeIfPresent([String: UpstreamJSONValue].self, forKey: .metadata) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(role, forKey: .role); try c.encode(content, forKey: .content)
        try c.encodeIfPresent(name, forKey: .name); try c.encodeIfPresent(toolCalls, forKey: .toolCalls)
        try c.encodeIfPresent(toolCallID, forKey: .toolCallID)
        if !metadata.isEmpty { try c.encode(metadata, forKey: .metadata) }
    }
}

public struct UpstreamToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let arguments: String
    public init(id: String, name: String, arguments: String) { self.id = id; self.name = name; self.arguments = arguments }
}

public struct UpstreamConversation: Codable, Sendable, Equatable {
    public let messages: [UpstreamConversationMessage]
    public let maxMessages: Int?
    public init(messages: [UpstreamConversationMessage], maxMessages: Int? = nil) {
        self.messages = messages; self.maxMessages = maxMessages
    }
    enum CodingKeys: String, CodingKey { case messages, maxMessages = "max_messages" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messages = try c.decodeIfPresent([UpstreamConversationMessage].self, forKey: .messages) ?? []
        maxMessages = try c.decodeIfPresent(Int.self, forKey: .maxMessages)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(messages, forKey: .messages); try c.encodeIfPresent(maxMessages, forKey: .maxMessages)
    }
}

public struct UpstreamAgentContext: Codable, Sendable, Equatable {
    public let conversation: UpstreamConversation
    public let tools: [String]
    public let memoryResults: [UpstreamJSONValue]
    public let metadata: [String: UpstreamJSONValue]
    public init(conversation: UpstreamConversation, tools: [String] = [],
                memoryResults: [UpstreamJSONValue] = [], metadata: [String: UpstreamJSONValue] = [:]) {
        self.conversation = conversation; self.tools = tools
        self.memoryResults = memoryResults; self.metadata = metadata
    }
    enum CodingKeys: String, CodingKey { case conversation, tools, memoryResults = "memory_results", metadata }
}

public struct UpstreamToolResult: Codable, Sendable, Equatable {
    public let toolName: String
    public let content: String
    public let success: Bool
    public let usage: [String: UpstreamJSONValue]
    public let costUSD: Double
    public let latencySeconds: Double
    public let metadata: [String: UpstreamJSONValue]
    public init(toolName: String, content: String, success: Bool = true,
                usage: [String: UpstreamJSONValue] = [:], costUSD: Double = 0,
                latencySeconds: Double = 0, metadata: [String: UpstreamJSONValue] = [:]) {
        self.toolName = toolName; self.content = content; self.success = success
        self.usage = usage; self.costUSD = costUSD; self.latencySeconds = latencySeconds; self.metadata = metadata
    }
    enum CodingKeys: String, CodingKey { case toolName = "tool_name", content, success, usage, costUSD = "cost_usd", latencySeconds = "latency_seconds", metadata }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        toolName = try c.decode(String.self, forKey: .toolName); content = try c.decode(String.self, forKey: .content)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
        usage = try c.decodeIfPresent([String: UpstreamJSONValue].self, forKey: .usage) ?? [:]
        costUSD = try c.decodeIfPresent(Double.self, forKey: .costUSD) ?? 0
        latencySeconds = try c.decodeIfPresent(Double.self, forKey: .latencySeconds) ?? 0
        metadata = try c.decodeIfPresent([String: UpstreamJSONValue].self, forKey: .metadata) ?? [:]
    }
}

public struct UpstreamAgentResult: Codable, Sendable, Equatable {
    public let content: String
    public let toolResults: [UpstreamToolResult]
    public let turns: Int
    public let metadata: [String: UpstreamJSONValue]
    public init(content: String, toolResults: [UpstreamToolResult] = [], turns: Int = 0,
                metadata: [String: UpstreamJSONValue] = [:]) {
        self.content = content; self.toolResults = toolResults; self.turns = turns; self.metadata = metadata
    }
    enum CodingKeys: String, CodingKey { case content, toolResults = "tool_results", turns, metadata }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        toolResults = try c.decodeIfPresent([UpstreamToolResult].self, forKey: .toolResults) ?? []
        turns = try c.decodeIfPresent(Int.self, forKey: .turns) ?? 0
        metadata = try c.decodeIfPresent([String: UpstreamJSONValue].self, forKey: .metadata) ?? [:]
    }
}

/// Swift-side adapter shape for the pinned upstream `OjAgent` trait.
public protocol OpenJarvisAgentRuntime: Sendable {
    var agentID: String { get }
    func acceptsTools() -> Bool
    func run(input: String, context: UpstreamAgentContext?) async throws -> UpstreamAgentResult
}
