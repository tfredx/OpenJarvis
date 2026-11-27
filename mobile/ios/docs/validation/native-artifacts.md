# Native build artifact proposal

Base: 17965e4b7f8121bcd57ff1570d1d4b55c4592810. PR #10 merged; both portable jobs for runs 45932108318 and 45932210379 succeeded. Native jobs were executing Rust cross-build at last observation. PR #9 previously passed native device and simulator compilation; no hosted runtime pass yet established.

This PR adds packaging only after the hosted test step succeeds. Requires expected app bundle identity, ARM64 binary and distinct device/simulator Mach-O platform markers using Xcode vtool, verifies ZIP integrity, records source commit and lockfile hash, and uploads both unsigned archives with manifest and SHA256SUMS. No signed artifact, no IPA, no secrets. Diagnostics upload remains unconditional. Existing CI checks remain intact. New packaging steps require CI validation; do not claim artifacts exist before successful run.

Next: inspect PR #10 native jobs, fix any test/build errors, then verify this PR's actual hosted test results, archive metadata, checksum and artifact upload. Enable required status checks via owner settings. Complete device validation in #4 before expanding runtime features.
