# Validation record — session repository storage phase

Baseline: integrated run 45935060866 (https://github.com/tfredx/OpenJarvis/actions/runs/45935060866). Portable job 140296353045 and native job 140296580829 succeeded. Native log: 10 Rust and 8 XCTest tests, both unsigned Xcode builds succeeded, three archive/manifest SHA checks OK, artifact 15170975527 uploaded. Total baseline 39 tests (21+10+8). Hardware not tested.

New local test command: swift test, Swift 6.2.1 Linux x86_64, temporary package from earlier v0.2 portable source and the exact two new files. Executed 26 tests, with 0 failures (0 unexpected). SessionRepositoryTests: Executed 10 tests, with 0 failures (0 unexpected). This fixture did not include the five later security tests; full integration remains CI's responsibility.

New tests: empty startup/reopen; exact legacy bytes/idempotence; independent Agent history/memory; pending approval blocks switch/delete/erase after restart; rename/delete/erase; invalid catalog/version; missing snapshot/catalog; interrupted create/retire; interrupted legacy copy; failed catalog write leaves in-memory selection unchanged.

Verified exact blobs: SessionRepository.swift 51d101aed90d5d84c2e2766b6070dff154249cfb; SessionRepositoryTests.swift 563a1ecc42d7ef774bc5ef1b483ab24be6859b48. Expected full suite 49 tests, not yet observed.
