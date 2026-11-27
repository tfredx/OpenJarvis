# ADR-0001: Fork and mobile integration strategy

Status: proposed in governance PR.

Keep main as a clean upstream mirror. ios/main is the long-lived mobile integration branch, initialized from the verified pin. Short-lived feature branches target ios/main; synchronize upstream deliberately via reviewed merge PRs, never rewrite shared history. Use scoped Conventional Commits and squash merges for ordinary feature PRs; preserve merge history when integrating upstream. Tag validated mobile prereleases ios-vX.Y.Z, distinct from upstream tags.

Canonical mobile source directory is mobile/ios (replaces the standalone archive's proposed mobile/ios-prototype location). Keep mobile documentation and code scoped there; preserve upstream workflows and contribution templates. Mobile-specific workflow files may live in .github/workflows.

Owner should configure branch rules for ios/main (PR required, block force pushes/deletion, required checks after they exist; at least one independent approval when another reviewer is available). For a solo maintainer, require PR and checks rather than an impossible independent-approval gate. Do not imply rules are enabled before verifying.

Public repository: source and non-sensitive synthetic test evidence only. No actual user data, keys, signing profiles or tokens.
