# Native archive symbol verification — incident and fix

Base: b17f0b330e654667d6bf818d082ee159276ef627. Upstream pin: 556ddf32456bdf5c40195714a3385b339b5f98f9. Issue #3.

## Observed evidence
Integrated run https://github.com/tfredx/OpenJarvis/actions/runs/45931139897/job/140283989915:
- Xcode 27.1; Cargo 1.100.0 (3acc79c0c 2026-11-05).
- 3 Rust tests passed, 0 failed; release builds finished for both aarch64-apple-ios and aarch64-apple-ios-sim.
- Apple's nm rejected embedded LLVM metadata: "Not an int attribute" / "Unknown attribute kind (105)"; producer LLVM23.1.5-rust-1.100.0-stable, reader LLVM APPLE_1_2100.3.34.2_0.
- Run was cancelled when PR #8 merged; no completed symbol gate, XCFramework or Xcode link result. Cargo.lock hash printed: 4006df18f100df468fde3be16c0c197e540b75895afa8567bf50bfaa9023e992 (not a committed lockfile).

## Change
Pin Rust 1.100.0, install its llvm-tools-preview component, derive the host-specific llvm-nm path from rustc sysroot, check its availability, and use it to inspect both archives. Require both exported C ABI symbols and successful nm exit; preserve stderr and tool versions in artifacts. Leave Apple XCFramework construction and unsigned Xcode device/simulator build gates intact. Workflow no longer installs a moving stable toolchain separately.

## Validation and risk
Proposed fix addresses a verified reader/producer mismatch, not a verified Apple linker issue. Actual CI execution is required. If matching llvm-nm fails, inspect component availability and symbol names. If Apple linker later rejects metadata, investigate native Mach-O/bitcode and compatible Rust toolchain without weakening gates. Do not claim successful XCFramework or app linking until observed. Cargo.lock must be recovered from the current CI artifact, reviewed and committed in a separate follow-up; XcodeGen version pin still pending.
