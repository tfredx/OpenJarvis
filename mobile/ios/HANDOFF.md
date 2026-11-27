# Current handoff — v0.4.1 complete; v0.5 architecture decision pending

Date: 2026-11-27 ET. `ios/main` is `409c798f208b3211674b6838d4a2d614866db285` after PR #20. The PR validation run 46070616432 and integrated push run 46072060277 both passed. Each run passed 55 portable Swift tests, the pinned Rust bridge tests/cross-build, 11 hosted native simulator tests, security audit jobs, ARM64 `iphoneos` and simulator builds, packaging and artifact upload.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling simulator and physical-device targets, and packaging an unsigned IPA. The tested commit and local logs were not supplied; keep this evidence owner-reported and unattributed to a specific SHA. Physical-device pairing, signing, installation and runtime testing remain pending. This does not block development, and no on-device behavior or performance is claimed.

## Release artifact pipeline — merged and validated

PR #20 adds the reusable repository security audit as a required native-build dependency, valid `ios-vX.Y.Z` tag validation against `ios/main`, tag-derived app version/build number, unsigned IPA packaging and checksummed artifacts. The validated PR and integrated CI runs uploaded development IPAs. Integrated artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277); its package contains the device and simulator app bundles, IPA, manifest and checksums. I downloaded the PR artifact from run 46070616432 and verified its ZIP checksums and `Payload/OpenJarvisMobile.app/Info.plist`; the IPA manifest explicitly reports `physical_device_tested: false`.

No `ios-vX.Y.Z` tag has been created, so tag-specific version injection and 90-day release-artifact publication are configured but have not yet run. No signed, App Store or production release was created. Release artifacts require developer signing for installation.

## Next — upstream agent adapter

The v0.5 integration needs an architectural choice. The pinned upstream `openjarvis-agents` crate requires a `rig-core::CompletionModel`; its `NativeReActAgent` executes through `ToolExecutor` without the app's explicit approval gate. At this pin, `OrchestratorAgent` is still a one-turn chat wrapper and does not dispatch tools. `rig-core` brings a `reqwest` dependency graph. The app instead uses asynchronous Apple Foundation Models in Swift, and ADR-0002 deliberately keeps inference and tool authorization outside the Rust bridge.

Before implementing v0.5, choose whether to keep Apple inference and approvals in Swift with a narrow adapter around upstream core contracts, or build an asynchronous Rust-to-Swift model bridge and integrate the Rust agent crate behind a restricted approval-aware tool executor. Do not report original upstream orchestration as integrated until the chosen runtime actually uses its agent API and has regression coverage. Do not add generic network, shell, or file tools.

Other roadmap work can continue without physical-device installation, but production storage cutover and claims about file protection, model behavior, or performance require the signed-device gate. JSON remains authoritative until the migration safety gates pass. Do not modify upstream `main` or commit signing material.
