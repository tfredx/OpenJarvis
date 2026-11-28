# ADR 0009 — Mobile agent runtime boundary

Status: accepted for the iOS runtime; direct `rig-core` agent integration is deferred.

## Context

The mobile app currently runs its agent loop in `mobile/ios/Sources/JarvisCore/Core.swift`. Inference is supplied by asynchronous Apple Foundation Models in `mobile/ios/ios/App/OpenJarvisApp.swift`. The app checks an independent allowlist, asks the user before memory writes, and persists pending approval state. ADR-0002 keeps inference, authorization and orchestration outside the native Rust bridge; the bridge currently imports pinned `openjarvis-core` conversation types and the upstream capability policy.

At upstream pin `556ddf32456bdf5c40195714a3385b339b5f98f9`, `openjarvis-agents::OjAgent` in `rust/crates/openjarvis-agents/src/traits.rs` accepts `AgentContext` and returns `AgentResult`, but its implementations use `rig_core::CompletionModel`. `SimpleAgent` is single-turn and tool-free. `OrchestratorAgent` currently performs one `.chat()` call and leaves tool dispatch for future work. `NativeReActAgent` uses `ToolExecutor` directly. The Rust workspace pins `rig-core = 0.31`; its dependency graph includes `reqwest`. A direct port would therefore add substantial runtime dependency surface without providing the upstream tool orchestration its name implies, and using `NativeReActAgent` as-is would bypass the mobile approval gate.

## Decision

Keep inference and orchestration in Swift. Implement the pinned upstream `OjAgent` invocation shape and the `openjarvis-core` `AgentContext`, `AgentResult`, `ToolResult`, `Conversation` and `Message` JSON contracts in a narrow adapter. Continue using Apple Foundation Models for inference and the app's existing Swift authorization/approval path. Context is accepted only when it matches trusted local session state and locally derived grants; the model cannot add tools or permissions. Memory writes remain pending until an explicit user decision, and the result boundary reports pending approval without treating it as success.

Do not add `openjarvis-agents`, `rig-core` or `reqwest` to the iOS binary. The current upstream Rust `OrchestratorAgent` is not provider-neutral and its tool executor is not approval-aware. Reconsider direct Rust trait integration only after upstream provides a provider-neutral, approval-preserving executor contract and the app has lifecycle-safe async bridging tests. This adapter uses upstream contracts; it does not claim the pinned Rust agent implementation itself is linked into the runtime.

## Constraints for any choice

- No tool runs before explicit user approval where the current policy requires it; approval is rechecked after resume/restart.
- No generic network, shell, arbitrary filesystem or scheduling tools.
- Unknown capabilities fail closed; Swift authorization remains an independent check.
- No claim of on-device behavior or performance before signed physical-device validation.
- Keep the pinned upstream commit and dependency provenance auditable. Do not change upstream `main`.

The implementation and contract-parity tests are in `feat/ios-swift-agent-contracts`; the change remains unvalidated until complete CI passes. v0.5 is not complete until the branch is integrated, and direct Rust `openjarvis-agents` runtime use remains deferred.
