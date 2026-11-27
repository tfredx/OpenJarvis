import Foundation
import JarvisCore
#if REQUIRE_RUST_BRIDGE && !canImport(OpenJarvisBridge)
#error("Native build requires the upstream Rust bridge module")
#endif
#if canImport(OpenJarvisBridge)
import OpenJarvisBridge
struct NativeConversationBridge: ConversationBridge {
    func window(_ conversation: WireConversation) throws -> [WireMessage] {
        let data = try JSONEncoder().encode(conversation)
        let json = String(decoding: data, as: UTF8.self)
        guard let result = json.withCString({ oj_window_json($0) }) else { throw BridgeError.nativeFailure }
        defer { oj_string_free(result) }
        return try JSONDecoder().decode([WireMessage].self, from: Data(String(cString: result).utf8))
    }
}
#endif
func makeConversationBridge() -> any ConversationBridge {
    #if canImport(OpenJarvisBridge)
    return NativeConversationBridge()
    #else
    return SwiftConversationBridge()
    #endif
}
let conversationBridgeLabel: String = {
    #if canImport(OpenJarvisBridge)
    return "Upstream Rust conversation bridge"
    #else
    return "Swift compatibility mode"
    #endif
}()
