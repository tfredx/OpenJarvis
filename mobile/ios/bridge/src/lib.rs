//! Small, owned-string C ABI around the real upstream Conversation type.
use openjarvis_core::Conversation;
#[cfg(test)]
use openjarvis_core::Message;

// Compile the unchanged upstream capability module, not its desktop dependency graph.
// Source provenance is checked in build-rust-bridge.sh before any build.
#[allow(dead_code)]
#[path = "../../../../rust/crates/openjarvis-security/src/capabilities.rs"]
mod upstream_capabilities;
use upstream_capabilities::{Capability, CapabilityPolicy};
use std::{ffi::{CStr, CString, c_char}, panic::catch_unwind};

fn window(input: &str) -> Result<String, String> {
    if input.len() > 524_288 { return Err("oversize input".into()); }
    let c: Conversation = serde_json::from_str(input).map_err(|e| e.to_string())?;
    let limit = c.max_messages.filter(|n| (1..=32).contains(n)).ok_or("invalid limit")?;
    if c.messages.len() > 32 { return Err("too many messages".into()); }
    let mut result = Conversation::new(Some(limit));
    for message in c.messages { result.add(message); }
    serde_json::to_string(&result.messages).map_err(|e| e.to_string())
}
/// Caller supplies a valid NUL-terminated UTF-8 string. Null indicates error.
/// Returned pointer must be freed using oj_string_free exactly once.
#[no_mangle]
pub unsafe extern "C" fn oj_window_json(input: *const c_char) -> *mut c_char {
    if input.is_null() { return std::ptr::null_mut(); }
    catch_unwind(|| {
        let s = match unsafe { CStr::from_ptr(input) }.to_str() { Ok(s) => s, Err(_) => return std::ptr::null_mut() };
        match window(s).ok().and_then(|s| CString::new(s).ok()) { Some(s) => s.into_raw(), None => std::ptr::null_mut() }
    }).unwrap_or(std::ptr::null_mut())
}
#[no_mangle]
pub unsafe extern "C" fn oj_string_free(value: *mut c_char) {
    if !value.is_null() { drop(unsafe { CString::from_raw(value) }); }
}
/// Return 1 only for an explicitly granted local action. Input is a JSON string;
/// errors, unknown actions and panics return 0. No grants originate from the model.
fn authorize(action: &str) -> bool {
    const AGENT: &str = "ios-local-agent";
    let mut policy = CapabilityPolicy::new(true);
    policy.grant(AGENT, Capability::ToolInvoke.as_str(), "reply");
    policy.grant(AGENT, Capability::ToolInvoke.as_str(), "current_time");
    policy.grant(AGENT, Capability::MemoryRead.as_str(), "local-memory");
    policy.grant(AGENT, Capability::MemoryWrite.as_str(), "local-memory");
    match action {
        "reply" | "current_time" => policy.check(AGENT, Capability::ToolInvoke.as_str(), action),
        "search_memory" => policy.check(AGENT, Capability::MemoryRead.as_str(), "local-memory"),
        "save_memory" => policy.check(AGENT, Capability::MemoryWrite.as_str(), "local-memory"),
        _ => false,
    }
}

/// Caller supplies valid NUL-terminated UTF-8 JSON. No allocation is returned.
#[no_mangle]
pub unsafe extern "C" fn oj_authorize_action_json(input: *const c_char) -> i32 {
    if input.is_null() { return 0; }
    catch_unwind(|| {
        let bytes = unsafe { CStr::from_ptr(input) }.to_bytes();
        if bytes.len() > 1024 { return 0; }
        match serde_json::from_slice::<String>(bytes) {
            Ok(action) if authorize(&action) => 1,
            _ => 0,
        }
    }).unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn capability_policy_grants_only_four_actions() {
        for action in ["reply", "current_time", "search_memory", "save_memory"] {
            assert!(authorize(action));
        }
        for action in ["", "shell", "network:fetch", "file:write", "schedule:create", "system:admin", "Reply", "reply ", "*", "reply\0shell"] {
            assert!(!authorize(action));
        }
    }
    #[test] fn capability_ffi_rejects_invalid_or_oversized_json() {
        for (input, expected) in [(r#""reply""#, 1), (r#""save_memory""#, 1), (r#""reply\u0000shell""#, 0), ("{}", 0), ("not json", 0)] {
            let input = CString::new(input).unwrap();
            assert_eq!(unsafe { oj_authorize_action_json(input.as_ptr()) }, expected);
        }
        let big = CString::new(format!("\"{}\"", "x".repeat(1025))).unwrap();
        assert_eq!(unsafe { oj_authorize_action_json(big.as_ptr()) }, 0);
        assert_eq!(unsafe { oj_authorize_action_json(std::ptr::null()) }, 0);
    }
    #[test] fn uses_upstream_window() {
        let input = r#"{"messages":[{"role":"user","content":"one"},{"role":"assistant","content":"二"}],"max_messages":1}"#;
        let messages: Vec<Message> = serde_json::from_str(&window(input).unwrap()).unwrap();
        assert_eq!(messages.len(),1); assert_eq!(messages[0].content,"二");
    }
    #[test] fn rejects_bad_data() { assert!(window(r#"{"messages":[],"max_messages":0}"#).is_err()); assert!(window("bad").is_err()); }
    #[test] fn ffi_roundtrip() {
        let input = CString::new(r#"{"messages":[],"max_messages":6}"#).unwrap();
        unsafe { let p = oj_window_json(input.as_ptr()); assert!(!p.is_null()); assert_eq!(CStr::from_ptr(p).to_str().unwrap(),"[]"); oj_string_free(p); assert!(oj_window_json(std::ptr::null()).is_null()); }
    }
}
