# ADR 0007 — SQLite shadow migration rehearsal

Baseline: merged PR #17, ios/main 1b3321c14e6ed5dd3bcc24a93a6fb44029dcb0e7; PR run 45938278085 passed 45 Swift, 10 Rust, 10 hosted tests, both native builds and artifact upload (15171848485). Post-merge run 45941866584 initially in progress.

## Decision
Add a synchronous read-only archive export from the current JSON repository, checking persisted catalog equality, snapshot decodability, and absence of unindexed files. Preserve order, IDs, active selection, timestamps and exact snapshot bytes. Only the idle sole-owner coordinator can invoke a rehearsal; a saved pending approval/interrupted task is allowed, but a live operation is not. No model access or app startup/UI wiring.

In a newly created unique staging directory, import using existing SQLite transaction, close, reopen and compare the complete archive. Re-read source to detect changes. Count-only report; no source content in logs. Remove only the created staging directory after success or error; report cleanup failure explicitly. Never remove/overwrite source files and never select the staged database as the live store. Request iOS data protection and backup exclusion on the staging directory before creating the database. Hardware inheritance for database/journal files not verified. A process kill could leave staging files; production use requires an explicit migration journal, protected staging location, interrupted-stage cleanup and privacy/erase handling. Rehearsal only with synthetic fixtures until then. This is not production migration, backup or forensic erasure.

## Evidence and gates
Five new rehearsal tests actually passed locally on Linux Swift 6.2.1 / SQLite 3.46.1 using earlier portable fixture plus SQLite foundation (28 total, 0 failures). Exact new source/test blobs: 401805aa38f1967e07249f208b8e73c67a88de82 and 831e12de15c56645e8ef0cf12bcdd0268eb76be4. Added three repository/coordinator integration tests, extended busy guard test, and one hosted Rust-backed SQLite rehearsal test; not yet executed. Expected combined tests 53 Swift + 10 Rust + 11 hosted = 74. Physical device #4 and session UI #14 remain open.

Next: validate full suite and artifacts, implement durable snapshot backend abstraction, protected migration journal and crash-safe cutover/rollback with actual device file-protection tests. Keep original source authoritative until explicit verified cutover. Then normalized message and note indexes, lexical retrieval, semantic retrieval. No full upstream SessionStore migration claimed.
