# ADR 0009 — Mobile agent runtime boundary

Status: decision pending; do not change the agent runtime until the boundary is selected.

## Context

The mobile app currently runs its agent loop in `mobile/ios/Sources/JarvisCore/Core.swift`. Inference is supplied by asynchronous Apple Foundation Models in `mobile/ios/ios/App/OpenJarvisApp.swift`. The app checks an independent allowlist, asks the user before memory writes, and persists pending approval state. ADR-0002 keeps inference, authorization and orchestration outside the native Rust bridge; the bridge currently imports pinned `openjarvis-core` conversation types and the upstream capability policy.

At upstream pin `556ddf32456bdf5c40195714a3385b339b5f98f9`, `openjarvis-agents::OjAgent` in `rust/crates/openjarvis-agents/src/traits.rs` accepts `AgentContext` and returns `AgentResult`, but its implementations use `rig_core::CompletionModel`. `SimpleAgent` is single-turn and tool-free. `OrchestratorAgent` currently performs one `.chat()` call and leaves tool dispatch for future work. `NativeReActAgent` uses `ToolExecutor` directly. The Rust workspace pins `rig-core = 0.31`; its dependency graph includes `reqwest`. A direct port would therefore add substantial runtime dependency surface without providing the upstream tool orchestration its name implies, and using `NativeReActAgent` as-is would bypass the mobile approval gate.

## Options to resolve

1. Keep Apple inference and the approval-aware orchestration in Swift. Add a narrow adapter using upstream core context/result and capability contracts where they fit, and defer direct `openjarvis-agents` integration until upstream exposes a provider-neutral, approval-aware agent API. This preserves current on-device inference and avoids adding `rig-core`/`reqwest` to the iOS binary, but does not satisfy v0.5 until an actual upstream agent API is used.
2. Add an asynchronous Rust-to-Swift model bridge and integrate an upstream `OjAgent` implementation behind a restricted, approval-aware executor. This uses the original agent API, but requires lifecycle/cancellation-safe cross-language callbacks and adds the `rig-core` dependency graph. It needs dedicated concurrency, timeout, cancellation and signed-device tests before release.
3. Replace Apple Foundation Models with a Rust-native provider/model route. This would alter the existing local inference architecture and requires a separate device resource, model availability and distribution assessment.

## Constraints for any choice

- No tool runs before explicit user approval where the current policy requires it; approval is rechecked after resume/restart.
- No generic network, shell, arbitrary filesystem or scheduling tools.
- Unknown capabilities fail closed; Swift authorization remains an independent check.
- No claim of on-device behavior or performance before signed physical-device validation.
- Keep the pinned upstream commit and dependency provenance auditable. Do not change upstream `main`.

No option has been selected in this record. v0.5 remains open until an implementation uses and tests the chosen upstream agent boundary without weakening these constraints.
