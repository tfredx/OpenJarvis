# ADR-0002: Narrow Rust bridge

Status: source imported; native validation pending.

Retain the tested Swift agent, approval policy and persistence while introducing the actual pinned upstream Rust Conversation::new/add implementation via an owned UTF-8 C ABI. Swift independently checks the returned history window and fails closed if altered. Rust handles conversation windowing only, not inference, tool authorization or orchestration. Two XcodeGen specs distinguish native-required and diagnostic Swift-only modes. No silent downgrade from a failed native build.

On-device model requests use Apple Foundation Models; App Intent preloads a request for review. No external model service, autonomous background scheduler or arbitrary shell execution in the app. User-approved local memory remains JSON until a tested versioned SQLite migration. Physical-device privacy, permissions and model availability remain to be validated.

Reconsider UniFFI once the native surface grows. Preserve the upstream pin and record dependency resolution.
