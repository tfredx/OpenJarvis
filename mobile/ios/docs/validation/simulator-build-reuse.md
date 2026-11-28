# Simulator compilation reuse

This change uses Xcode build-for-testing to compile the arm64 iOS simulator host and hosted tests once. Hosted XCTest consumes the emitted test configuration with test-without-building. Packaging uses the same simulator host. The separate unsigned iPhoneOS build, portable regression and security checks, Rust validation, hosted test success requirements, artifact checks and publication order remain in place.

The test script requires fresh simulator derived data and exactly one generated test configuration. Release version and build overrides are passed to both platform builds. The artifact manifest source SHA must match the Actions run commit.

Local validation uses shell build fixtures and whitespace checks. Xcode validation must demonstrate successful unsigned simulator compilation and hosted XCTest, platform-specific package verification, and an unsigned device IPA before integration.

Run [46101262104](https://github.com/tfredx/OpenJarvis/actions/runs/46101262104) confirmed Actions resumed. All 83 Swift tests, five security jobs, 10 Rust bridge tests and the unsigned iPhoneOS build passed. The simulator step stopped before compilation because macOS Bash treated the empty development version array as unbound under nounset. The corrected script uses one nonempty build argument array for both development and version-tag builds. The initial run produced diagnostics, with no development IPA.
