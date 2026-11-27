# ADR 0004 — Isolated local sessions, storage phase (proposal)

## Context
Integrated baseline 3bd28cb697ced6574eb9e215434370e4450442e2, run 45935060866, passed 21 portable Swift, 10 Rust host, and 8 hosted simulator tests. Native archives and their checksums were published as artifact 15170975527. Physical device validation #4 and required status checks remain unresolved. Issue #14 scopes session management.

The pinned upstream sessions crate is SQLite-backed and supports cross-channel identity links and checkpoint/rewind. It does not represent the full mobile Agent Snapshot (approval, steps, denial state, notes), and its storage methods can panic on errors. Do not use it as a drop-in replacement. This phase adds no external dependency and is not upstream SQLite integration.

## Decision
A MainActor-owned SessionRepository stores a version-1 sessions.json catalog plus a separate UUID-named Agent snapshot per conversation. It creates, renames, selects, deletes and erases sessions through host-controlled methods. A persisted initializing UUID and retirement list make interrupted operations recoverable: write catalog transition, create or copy the new snapshot, validate retained snapshots, remove tracked retired files, then clear transition. Initial migration validates legacy state.json and copies its exact bytes before removing it. Unknown versions, missing/corrupt snapshots, unexpected legacy data and unindexed snapshots fail closed; no automatic reset. Catalog writes are atomic and update memory only after success. Pending/running snapshots block switching and destructive changes until resolved/discarded.

The storage layer requires one owner and no live Agent writer during transitions. It is not wired into the application yet; the next PR must enforce ownership and task-generation identity, including in-flight operations, and show explicit confirmation for deletion. Existing production app storage remains unchanged. Memory is session-scoped, not global. No guarantee of multi-process concurrency, power-loss durability or forensic deletion. The next UI increment must preserve iOS file protection and backup exclusion, handle recovery errors visibly, clear stale draft text, and scope erase-all correctly. Review local filesystem assumptions before device deployment.

## Evidence
Local Linux Swift 6.2.1: 10 new repository tests passed; 26 total tests on the earlier v0.2 portable source snapshot (16 existing plus 10 new). Exact new source/test Git blobs 51d101aed90d5d84c2e2766b6070dff154249cfb and 563a1ecc42d7ef774bc5ef1b483ab24be6859b48 match the locally executed files. This is not the full merged security baseline; CI must execute the combined 31 portable, 10 Rust and 8 hosted tests before claiming 49 passes. No new hosted or device results.

## Next
Review this PR's actual CI; merge only after successful checks and physical baseline validation or explicit deferral. Then wire a single session coordinator to SwiftUI, add hosted switch/approval isolation tests, and test the upgrade on a device. SQLite/upstream SessionStore remains a later reviewed migration.
