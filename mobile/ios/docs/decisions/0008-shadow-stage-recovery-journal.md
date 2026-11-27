# ADR 0008 — Journaled SQLite shadow-stage recovery

Status: proposed; rehearsal-only until portable/native CI and physical file-protection validation complete.

## Context

PR #18 (`996cb96f101033628d6b1eee3a3cfcde6dec9ebc`) verifies an exact JSON archive by importing it into a unique temporary SQLite database, closing and reopening that database, comparing the full archive, and re-reading the source. A process termination can leave the temporary directory behind. Source JSON remains authoritative and no cutover is in scope.

## Decision

Before creating a shadow directory, atomically persist a small versioned JSON record containing only the generated directory name. The stage name is restricted to `jarvis-shadow-<canonical UUID>`. On the next rehearsal, recovery validates the journal and filesystem object types, then removes only that recorded directory and the journal. A malformed/symlink journal, non-directory stage, or untracked stage fails closed and preserves all files. The journal is written first, making termination between intent and directory creation recoverable. Cleanup can be retried if termination occurs after stage removal but before journal removal.

On iOS, apply complete-until-first-authentication protection and backup exclusion to both journal and stage before writing SQLite data. No claim is made that the SQLite database or rollback journal inherits the intended attributes on actual hardware; inspect and test this on a signed physical device before any live migration. The journal contains no conversation content. No persistent runtime switch, automatic source deletion, cutover, rollback-to-live-backend, or app startup integration is added.

## Acceptance evidence

Tests verify cleanup of the recorded stage only, preservation of unrelated files, rejection of corrupt journal data, and refusal to delete an orphaned stage without a valid journal. Rehearsal verifies recovery before starting another stage. Run the complete portable and native CI jobs; compile-time simulator/device builds are not physical-device evidence. Linux local Swift execution is unavailable in the current development environment.

## Next

Implement and validate snapshot backend abstraction and a crash-recoverable migration state machine only after this increment passes CI. Keep JSON authoritative until signed-device tests establish file protection, backup behavior, locked/unlocked behavior, process-kill recovery and preservation of source data. Do not claim semantic memory or full upstream session-store integration.
