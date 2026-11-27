# Mobile development instructions

Scope: mobile/ios and mobile-specific workflows. Respect upstream instructions outside this directory.

- Read HANDOFF.md, ROADMAP.md, docs/decisions/0001-repository-strategy.md and the linked PRs before editing.
- Use ios/main as the integration base and a short-lived feat/ios-*, fix/ios-* or chore/ios-* branch. Never push to main or upstream; never force-push shared branches.
- Keep each PR focused; include acceptance criteria, regression tests, actual command output, security/privacy implications and a handoff update.
- Preserve upstream attribution and Apache-2.0 notices. Do not commit signing keys, credentials, device data, personal memory or generated build products.
- Do not report unexecuted tests as passed. Distinguish portable Swift, Rust host, cross-target, Xcode and physical-device evidence.
- Record source provenance, exact upstream pin, dependencies, decisions, changed paths, test environment, blockers and next commands. Reference the PR/commit in the next handoff rather than attempting a self-referential commit hash.
- Do not merge or release without owner approval and applicable CI checks. No scope expansion while a failed build gate is unresolved.
