# OpenJarvis Mobile — native prototype

Experimental local-first iOS 27 port. Portable Swift core, SwiftUI app, Apple Foundation Models adapter, App Intents, and a narrow Rust C ABI around the pinned upstream Conversation type. The Rust agent engine is not yet migrated.

## Build on macOS
Install Xcode 27 (select its developer directory), XcodeGen and rustup. From mobile/ios:
```sh
swift test
./scripts/setup-ios.sh --native
```
This generates a Cargo.lock if absent (retain it in a follow-up PR), tests the bridge, builds arm64 device/simulator static libraries, verifies symbols, creates the XCFramework and attempts unsigned builds. Then select a personal signing team and device in Xcode. No cloud API key is required. The separate --swift-only mode is a diagnostic baseline, not proof of native Rust integration.
```sh
./scripts/audit-upstream.sh
```
The audit checks the upstream pinned crates against both Apple targets. It requires network and Apple SDK.

Read AGENTS.md, HANDOFF.md, ROADMAP.md, docs/validation and architecture decision records. No secrets or real personal data in this public repository. Source under repository Apache-2.0 license.
