# Current handoff — native capability boundary integrated; diagnostics comparison in review

Date: 2026-11-27 ET. `ios/main` is `6206921f534f89433fbe14e60069bf26434d1132` after PR #28; `827735587db3dbae082f06099d89239c7348721d` was the merge of PR #26 on top of PR #25's `ede3b2242979fe0545dc93e74f718a2535a9d338`. PR #25 integrated transactional SQLite session CRUD; its complete required/integrated CI conclusion remains unverified using the available status tools. PR #26 integrated the opt-in synthetic physical-inference diagnostics. GitHub reported both PRs merged. Combined commit-status lookup returned no contexts for PR #26's merge commit; the available workflow-run query returned no associated PR runs. Do not represent this as a verified green CI run.

PR #27 is merged at `84944000710a716af3862adedd7e5ba91bd15a7b`; its integrated CI is not independently verified here. PR #28 merged from `2322145598138f971c6fb7883848f13b2a01d17e`. Its current-head workflow lookup returned no evidence.

## Owner-reported Mac and device evidence

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust; passing 55 Swift core tests; compiling simulator and physical-device targets; and packaging an unsigned IPA. The tested commit and logs were not supplied, so this remains owner-reported and is not attributed to a repository SHA.

Tim reported partial execution on a physical iPhone: four basic factual/creative prompts passed; a process explanation explicitly denying tools and memory failed; six semantic-memory prompts failed. Exact device, OS, tested commit and diagnostic logs/timings were not supplied. This is partial physical execution evidence only. It does not demonstrate current-build acceptance, reliable inference, performance or complete G5 validation. PR #26 adds an opt-in synthetic diagnostic runner and redacted report; its physical execution on a current build remains pending.

## CI and unsigned artifacts

PR #20 added a required security audit dependency, validated `ios-vX.Y.Z` tag handling, tag-derived version/build injection, unsigned IPA packaging and checksummed artifacts. PR #20/#21 integrated runs passed; artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277). PR #22 run 46082211356 and integrated run 46083177104 passed seven jobs, including 62 portable Swift tests, 10 Rust bridge tests/cross-build, 11 hosted native integration tests, security audits, iPhoneOS and simulator compilation, and artifact packaging; integrated artifact 15237619676 was uploaded. PR #23 run 46084387629 and integrated run 46085721355 passed seven jobs and uploaded artifact 15238954029.

PR #24 run 46086033077 executed 66 portable Swift tests, 10 Rust bridge tests, security validation, both unsigned native builds and 11 hosted integration tests and uploaded artifact 15239452414, but the native job ended cancelled during final diagnostics retention. It is not a passing required conclusion. PR #25 replaced it and merged; its integrated CI status is unknown here. For PR #26, the available GitHub commit-status and workflow-run endpoints returned no checks/runs for the merge commit. PRs #27/#28 currently have no workflow-run result exposed for the examined heads. Treat absent evidence as unknown, not passed.

The pipeline artifact is unsigned. Tag-specific versioned release publication has not been exercised. No signed, App Store or production release exists. Successful compilation and simulator tests are not physical-device runtime validation.

## Integrated SQLite session operations — PR #25

PR #25 integrated transactional create, rename, select, snapshot-save, delete and explicit-erase operations in `SQLiteSessionStore`. JSON remains the authoritative app store: SQLite is not wired into `SessionRepository`, `SessionCoordinator` or startup. No migration, data deletion, device file protection, or on-device SQLite behavior is claimed. Do not start production migration/cutover until the integrated foundation's required CI is confirmed and signed-device file protection, migration/recovery, backup exclusion and rollback behavior pass their gates. Never roll back to an old JSON snapshot after SQLite has accepted new writes without a lossless reconciliation path.

## Integrated inference diagnostics — PR #26

The opt-in runner executes eight fixed synthetic scenarios through the local Agent/Intelligence path and memory matcher. Its report omits prompts, answers, memory text and model error text, uses temporary synthetic session state, and refuses to run while live work is unresolved. The implementation is integrated at `8277355`; CI execution and current physical-device acceptance remain unverified. Owner-run diagnostics must be associated with the exact build, device and OS before those results can be treated as acceptance evidence.

## PR #27 — Swift-first upstream contract adapter

The owner selected Swift-first orchestration while retaining Apple Foundation Models. ADR-0009 accepts the adapter boundary: Swift mirrors pinned upstream `OjAgent`, `AgentContext`, `AgentResult` and `ToolResult` contracts. It does not link Rust `openjarvis-agents`, `rig-core` or `reqwest`. Local tool policy and request denial stay authoritative; memory writes require explicit human approval. Tests cover contract shape, context tampering, denials and approval. They have not run in this Linux environment. PR #27 is merged; its integrated CI remains unverified.

## PR #28 — permission-neutral native capability interface

PR #28 defines fixed capability IDs, trusted adapter registration, bounded typed values, independent exact authorization and fresh human approval per call; defaults deny. It registers no native provider, adds no usage descriptions/entitlements/permissions, and is not wired into the app. It does not implement Calendar, Reminders, Contacts, Photos or Location functionality. PR #28 includes the PR #27 merge commit and is now integrated. This does not establish runtime permissions or provider readiness.

## Diagnostic comparison increment

`fix/ios-diagnostic-stage-evidence` implements report schema 2, comparing plain local generation to the upstream-compatible agent path on identical fixed requests. It records bounded failure categories, generation timings and policy observations without recording prompt, output or error text. It also blocks normal task dispatch during a diagnostic run. The upstream pin remains `556ddf32456bdf5c40195714a3385b339b5f98f9`.

Local validation passed `git diff --check` and `mobile/ios/scripts/test-build-scripts.sh`. Swift, Rust, simulator, device compilation and physical execution were not run in this workspace. Current-head CI and artifact evidence remain pending. The owner can run the consolidated batch in `docs/DEVICE_INSTALL.md` once a verified build containing schema 2 is available.

Next independent work: harden deterministic agent reentry during an active task; design safe SQLite activation without changing the production backend; prepare scoped Calendar read validation behind the existing native capability boundary. Permission review precedes enabling any OS access.
