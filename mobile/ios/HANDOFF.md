# Current handoff — PR #25 integrated; CI evidence pending; diagnostics and orchestration in PRs

Date: 2026-11-28 ET. `ios/main` advanced from `adab8f8a665ba75e79813e82cc38166211345b3a` to `ede3b2242979fe0545dc93e74f718a2535a9d338` when PR #25 merged. PR #22 run 46082211356 and integrated run 46083177104 passed all seven jobs; PR #23 run 46084387629 and integrated run 46085721355 also passed all seven. Those runs covered portable Swift regressions, Rust bridge tests/cross-build, hosted native integration, five security audits, unsigned arm64 iPhoneOS and simulator builds, and artifacts 15237619676/15238954029. PR #25 is now integrated, but its push-triggered validation could not be independently verified with the connected GitHub tools: the workflow-run query returned no PR runs for the merge commit, and combined commit status exposed no contexts. Treat integrated validation as unknown, not passed.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling simulator and physical-device targets, and packaging an unsigned IPA. The tested commit and local logs were not supplied; keep this evidence owner-reported and unattributed to a specific SHA.

Tim later reported actual OpenJarvis execution on a physical iPhone using synthetic prompts: four basic responses passed, the request “Explain how a seed grows. Do not use tools or memory.” failed, and six targeted semantic-retrieval prompts failed. Device model, OS version, tested commit and logs/timings were not provided. This establishes partial physical-device execution, not complete G5 acceptance, overall feature correctness or performance. See `docs/validation/physical-memory-diagnostics.md`.

## Release artifact pipeline — merged and validated

PR #20 adds the reusable repository security audit as a required native-build dependency, valid `ios-vX.Y.Z` tag validation against `ios/main`, tag-derived app version/build number, unsigned IPA packaging and checksummed artifacts. The validated PR and integrated CI runs uploaded development IPAs. Integrated artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277); its package contains the device and simulator app bundles, IPA, manifest and checksums. I downloaded the PR artifact from run 46070616432 and verified its ZIP checksums and `Payload/OpenJarvisMobile.app/Info.plist`; the IPA manifest explicitly reports `physical_device_tested: false`.

No `ios-vX.Y.Z` tag has been created, so tag-specific version injection and 90-day release-artifact publication are configured but have not yet run. No signed, App Store or production release was created. Release artifacts require developer signing for installation.

## Current code increment — semantic recall and request policy

PR #22 adds on-device Apple sentence-embedding ranking with lexical fallback for approved memories, and enforces request-level denials before context assembly and action dispatch. Denied tasks exclude stored notes and prior-task history while retaining allowed current-task tool results. Tests cover paraphrases, unrelated-note rejection, lexical fallback, explicit denials, blocked actions, current-task context and old snapshot decoding. Initial CI exposed a weak token match and review found a context-window edge case; both were corrected. An intermediate update run failed to compile after the test source was truncated during transfer; the complete source was restored before final validation. PR run 46082211356 and integrated run 46083177104 passed all required jobs. Physical-device retesting remains needed to establish whether Tim's reported diagnostics are resolved. This workspace lacks Swift; local checks were `git diff --check` and the build-script fixtures.

JSON remains authoritative until the migration safety gates pass. Do not modify upstream `main`, add network/model downloads, or commit signing material.

## Current increment — transactional SQLite session operations

PR #25 merged the transactional create, rename, select, snapshot-save, delete and explicit erase API and its tests into `ios/main`. PR #24's earlier native run 46086033077 executed tests/builds and uploaded artifact 15239452414, but ended cancelled at diagnostics-artifact retention; it is not a successful required check. PR #25's complete CI conclusion and the integrated push-run remain unverified here. SQLite is still not wired into `SessionRepository`, `SessionCoordinator` or app startup; JSON remains the only production store. Migration/cutover, source deletion, device file protection and on-device behavior are not claimed. Do not begin dependent production-migration work until required CI evidence and physical file-protection evidence are verified.

## Current increment — physical inference diagnostics (PR #26)

The opt-in diagnostics runner executes eight fixed synthetic scenarios through the same local Agent/Intelligence path and memory matcher. Its report excludes prompts, answers, memory content and model error text. Regression tests are authored. PR #26 has not been asserted CI-green or physically run. It requires a signed install and an explicit user-run report to establish device evidence; no performance or device acceptance claim is made.

## Current increment — Swift-first upstream contract adapter (PR #27)

The owner selected Swift-first orchestration with Apple Foundation Models. ADR-0009 is accepted for an adapter using the pinned upstream `OjAgent`, `AgentContext`, `AgentResult` and `ToolResult` contracts. New submissions route through it; locally-derived tools, denial policy and explicit memory approval remain enforced. Contract, tampering, denial and approval tests are authored but unrun here. This adapter does not link Rust `openjarvis-agents`, `rig-core` or `reqwest`, and does not claim that the concrete upstream Rust agent is integrated. PR #27 is being updated to include the newly merged base without force-pushing its branch. Full Swift/Xcode CI is still required.

This workspace is Linux without Swift, Cargo or Xcode. `git diff --check` and `mobile/ios/scripts/test-build-scripts.sh` pass; Swift tests, Apple builds and actual device execution remain unrun here. Do not weaken CI or treat compile targets as device runtime evidence.
