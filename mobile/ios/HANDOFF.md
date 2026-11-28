# Mobile integration handoff

Verified `ios/main` at `76acd8ddb8ae977d501315fe3efd1b5d45ca0ddb`. PRs #25–#33 are merged. The latest first-parent merge is #32.

GitHub Actions displays a fork-wide suspension due to usage. The most recent successful integration run shown is [46085721355](https://github.com/tfredx/OpenJarvis/actions/runs/46085721355) at `adab8f8`. No run or status was found for the current HEAD. Shell build fixtures and `git diff --check 6206921f..HEAD` passed. Swift regression, security jobs, Rust, both native builds and hosted simulator tests lack current-HEAD results. This Linux workspace has no Swift, Rust or Xcode toolchain. No current development IPA was produced.

## Owner-reported Mac and device evidence

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust; passing 55 Swift core tests; compiling simulator and physical-device targets; and packaging an unsigned IPA. The tested commit and logs were not supplied, so this remains owner-reported and is not attributed to a repository SHA.

Tim reported partial execution on a physical iPhone: four basic factual/creative prompts passed; a process explanation explicitly denying tools and memory failed; six semantic-memory prompts failed. Exact device, OS, tested commit and diagnostic logs/timings were not supplied. This is partial physical execution evidence only. It does not demonstrate current-build acceptance, reliable inference, performance or complete G5 validation. PR #26 adds an opt-in synthetic diagnostic runner and redacted report; its physical execution on a current build remains pending.

## CI and unsigned artifacts

PR #20 added a required security audit dependency, validated `ios-vX.Y.Z` tag handling, tag-derived version/build injection, unsigned IPA packaging and checksummed artifacts. PR #20/#21 integrated runs passed; artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277). PR #22 run 46082211356 and integrated run 46083177104 passed seven jobs, including 62 portable Swift tests, 10 Rust bridge tests/cross-build, 11 hosted native integration tests, security audits, iPhoneOS and simulator compilation, and artifact packaging; integrated artifact 15237619676 was uploaded. PR #23 run 46084387629 and integrated run 46085721355 passed seven jobs and uploaded artifact 15238954029.

PR #24 run 46086033077 executed 66 portable Swift tests, 10 Rust bridge tests, security validation, both unsigned native builds and 11 hosted integration tests and uploaded artifact 15239452414, but the native job ended cancelled during final diagnostics retention. It is not a passing required conclusion. PR #25 replaced it and merged; its integrated CI status is unknown here. For PR #26, the available GitHub commit-status and workflow-run endpoints returned no checks/runs for the merge commit. Required CI results for the later integration commits remain unverified. Treat absent evidence as unknown, not passed.

The pipeline artifact is unsigned. Tag-specific versioned release publication has not been exercised. No signed, App Store or production release exists. Successful compilation and simulator tests are not physical-device runtime validation.

## Integrated changes

- #25 and #32 added transactional SQLite archive operations and safer rehearsal recovery. JSON remains authoritative. Production activation requires the migration, rollback, signed-device file protection and backup exclusion gates.
- #26 and #29 added synthetic inference comparison. Report schema 2 compares direct local generation and the agent path, recording elapsed time and content-free failure categories.
- #27 and #30 added Swift-first upstream contract adaptation and invocation-scoped tool results, preserving explicit approval and default-deny policy. The upstream source pin is `556ddf32456bdf5c40195714a3385b339b5f98f9`.
- #28 and #31 added capability dispatch and an unregistered scoped Calendar reader. OS access and registration remain pending permission review.
- #33 added the Activity view for the latest task with approval, cancellation and user-initiated recovery. Native accessibility evidence is pending.

## Next integration steps

A maintainer must restore Actions. Require a successful complete workflow and verify the artifact manifest source SHA and checksums before installation. Use the signed-device batch in [DEVICE_INSTALL.md](docs/DEVICE_INSTALL.md). Continue with deterministic briefing execution, gated EventKit scope and durable action outcomes independently. Feature PRs record evidence in their own validation records. Update this handoff and the roadmap in dedicated integration documentation commits.
