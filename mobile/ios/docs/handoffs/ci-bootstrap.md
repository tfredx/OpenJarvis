# CI proposal — issue #3

This PR is independent of native import PR #6; merge #6 first, then this PR. Source detection skips the native job only until the complete baseline is present. A skipped job is not a pass of the native gate. Once both PRs merge, push to ios/main triggers both jobs. Do not require native checks until actually observed on the complete baseline; remove the transitional source-detection condition in a follow-up.

The portable job uses Ubuntu 24.04 with runner-provided Swift and logs its version. The native job uses the standard Apple Silicon xcode-27 runner (https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/). It checks SDK major version, logs tool versions, installs XcodeGen if necessary, then executes the imported bridge script, generates the native-required project, and runs unsigned device and simulator builds separately. No signing or model inference claimed. No secrets, write token, pull_request_target or deployment. Checkout is pinned to verified v7 commit and credential persistence is disabled.

First native run generates a Cargo.lock if absent; this is a bootstrap step rather than fully reproducible dependency resolution. Follow-up: recover and review resolved lockfile, commit it, pin Rust and XcodeGen versions, and require --locked with no automatic lock regeneration. Inspect actual CI logs and fix first failing gate; retain evidence and update HANDOFF.md. Owner may need to authorize workflows on fork. Require checks only after names and execution are verified. No device tests in CI. See issue #4.

This is a proposed workflow, not executed evidence. Do not mark CI or native validation passed until actual run results exist.
