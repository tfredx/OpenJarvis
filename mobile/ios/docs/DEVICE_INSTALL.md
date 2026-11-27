# Developer installation and device validation

This is an experimental application, not an App Store release. CI builds unsigned device and simulator .app bundles. A validated `ios-vX.Y.Z` tag also produces a versioned unsigned IPA Actions artifact. Neither the device ZIP nor unsigned IPA includes signing credentials or a provisioning profile; neither can be directly installed from Files or Safari. Use Xcode for personal development signing. No Apple account credentials, signing certificates or provisioning profiles should be uploaded to GitHub.

## Prerequisites
- Mac with Xcode 27+ and its iOS simulator runtime. Open Xcode once and install required components.
- XcodeGen and rustup installed; Rust 1.100.0 is installed by the bridge script. XcodeGen 2.48.0 is the version observed in successful CI.
- Apple Intelligence-capable iPhone on iOS 27+, Apple Intelligence enabled and model downloaded.
- Apple account added in Xcode Settings > Accounts; personal team or paid development team as appropriate.

## Build and install
```sh
git clone https://github.com/tfredx/OpenJarvis.git
cd OpenJarvis
git switch ios/main
cd mobile/ios
./scripts/setup-ios.sh --native
```
If already cloned, fetch and update to the verified integration commit. Verify the exact commit and CI success before installation. Select the OpenJarvisMobile app target in Xcode, Signing & Capabilities, select your team and set a unique bundle identifier if needed. Connect and trust the iPhone, enable Developer Mode when prompted, select it as the run destination, and Run. Personal team provisioning can expire; re-sign/reinstall when required. No cloud key needed.

The native-required configuration must identify the upstream Rust conversation bridge in Settings. The Swift-only mode is a diagnostic configuration, not a native validation substitute.

## CI build artifact
After successful CI validation, ordinary branch runs publish unsigned device/simulator app bundles and a development IPA for 14 days. A valid `ios-vX.Y.Z` tag pointing into `ios/main` publishes `OpenJarvisMobile-ios-vX.Y.Z-unsigned.ipa`, `BUILD-MANIFEST.json` and `SHA256SUMS.txt` as a versioned Actions artifact retained for 90 days. The workflow requires portable tests, security audit, Rust bridge validation, arm64 `iphoneos` and simulator compilation, and hosted simulator integration tests before publishing. Verify the checksum file after download. The IPA must be re-signed locally before installation. Artifact generation does not create a GitHub release or validate physical-device runtime behavior.

## Device tests
Use the acceptance checklist in issue #4: launch, bridge identification, real on-device inference and offline request, memory denial/approval/relaunch, checkpoint cancellation/recovery, Shortcut prefill, unavailable model behavior and erase/delete scope. Use synthetic requests only. Record commit, iOS version and results in issue #4, without personal data. A compiled or simulator-tested app does not satisfy physical validation.
