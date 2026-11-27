//! Small, owned-string C ABI around the real upstream Conversation type.
use openjarvis_core::{Conversation, Message};
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
#[cfg(test)]
mod tests {
    use super::*;
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
