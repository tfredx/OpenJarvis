# Developer installation and device validation

This is an experimental application, not an App Store release. CI builds unsigned device and simulator .app bundles. A validated `ios-vX.Y.Z` tag also produces a versioned unsigned IPA Actions artifact. Neither the device ZIP nor unsigned IPA includes signing credentials or a provisioning profile; neither can be directly installed from Files or Safari. Use Xcode for personal development signing. No Apple account credentials, signing certificates or provisioning profiles should be uploaded to GitHub.

## Prerequisites
- Mac with Xcode 27+ and its iOS simulator runtime. Open Xcode once and install required components.
- XcodeGen and rustup installed; Rust 1.100.0 is installed by the bridge script. XcodeGen 2.48.0 is the version observed in successful CI.
- Apple Intelligence-capable iPhone on iOS 27+, Apple Intelligence enabled and model downloaded.
- Apple account added in Xcode Settings > Accounts; personal team or paid development team as appropriate.

## Build and install

The SHA below includes PRs #25–#33. GitHub Actions is suspended on the fork, so this SHA currently has no verified CI artifact. Use these commands after complete CI succeeds for this exact SHA, or substitute a later verified SHA that contains schema 2.
```sh
git clone https://github.com/tfredx/OpenJarvis.git
cd OpenJarvis
git fetch origin ios/main
git switch --detach 76acd8ddb8ae977d501315fe3efd1b5d45ca0ddb
cd mobile/ios
./scripts/setup-ios.sh --native
```
If already cloned, fetch and update to the verified integration commit. Verify the exact commit and CI success before installation. Select the OpenJarvisMobile app target in Xcode, Signing & Capabilities, select your team and set a unique bundle identifier if needed. Connect and trust the iPhone, enable Developer Mode when prompted, select it as the run destination, and Run. Personal team provisioning can expire; re-sign/reinstall when required. No cloud key needed.

The native-required configuration must identify the upstream Rust conversation bridge in Settings. The Swift-only mode is a diagnostic configuration, not a native validation substitute.

## CI build artifact
After successful CI validation, ordinary branch runs publish unsigned device/simulator app bundles and a development IPA for 14 days. A valid `ios-vX.Y.Z` tag pointing into `ios/main` publishes `OpenJarvisMobile-ios-vX.Y.Z-unsigned.ipa`, `BUILD-MANIFEST.json` and `SHA256SUMS.txt` as a versioned Actions artifact retained for 90 days. The workflow requires portable tests, security audit, Rust bridge validation, arm64 `iphoneos` and simulator compilation, and hosted simulator integration tests before publishing. Verify the checksum file after download. The IPA must be re-signed locally before installation. Artifact generation does not create a GitHub release or validate physical-device runtime behavior.

## Device tests
Use the acceptance checklist in issue #4: launch, bridge identification, real on-device inference and offline request, memory denial/approval/relaunch, checkpoint cancellation/recovery, Shortcut prefill, unavailable model behavior and erase/delete scope. Use synthetic requests only. Record commit, iOS version and results in issue #4, without personal data. A compiled or simulator-tested app does not satisfy physical validation.

## Batch for inference diagnostic report schema 2

Use a clean checkout of the exact CI-validated SHA that contains schema 2. Record `git rev-parse HEAD`, the Actions run and artifact ID, the iPhone model and the full iOS version alongside the report. For a locally signed Xcode build, record the source SHA before generating the project. The report includes bundle version and build number, which can be shared by multiple commits.

1. Install using the developer signing steps above. Enable Apple Intelligence, confirm its local model is available, and resolve any active Jarvis task.
2. In **Settings → Device diagnostics**, choose **Run local inference diagnostics**. Run twice under the same conditions and export each result via **Share diagnostics report**. Use the same build for both trials.
3. Expect eight comparisons per report. A healthy basic request returns a nonempty response in both paths. Check that the explicit no-tool/no-memory request shows prior context absent and no approval pending. Review relevant and unrelated memory fixtures separately.
4. Share the synthetic reports with the recorded build details. Direct success with a malformed agent decision points to the JSON response boundary. Failures in both paths at model availability point to device setup. Report timings are elapsed request times and do not measure time to first response, memory, thermals or battery use.
