/// A second, independent local authorization boundary. Grants allow eligibility
/// for a tool, never substitute for explicit human consent to a memory write.
public protocol ToolAuthorization: Sendable {
    func permits(_ action: String) -> Bool
}

public struct LocalToolAuthorization: ToolAuthorization {
    public init() {}
    public func permits(_ action: String) -> Bool {
        switch action {
        case "reply", "current_time", "search_memory", "save_memory": true
        default: false
        }
    }
}
