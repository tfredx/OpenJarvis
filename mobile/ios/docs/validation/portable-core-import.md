# Portable core import validation

Archive: OpenJarvis-Mobile-v0.2.0.zip
SHA-256: 151c029a383a8f94e932e6ac542b803bce6968a1915563c413ed6109276eb650

Fresh local test: 2026-11-27 02:48 UTC (Nov 26 ET).
Command: swift test --scratch-path /tmp/openjarvis-v021-build
Environment: Swift 6.2.1, x86_64-unknown-linux-gnu.
Result: 16 XCTest tests, 0 failures, 0 unexpected (10 agent, 6 bridge tests).
The Swift Testing library separately reports zero tests; this does not negate the XCTest run.
Test engine is deterministic; no model inference, native Rust execution or iOS SDK validation.

## Exact imported blob verification
The local git hash-object output and GitHub staged tree SHA e2abb849650108bd81a946d1f2ed7b959dd37139 agree for every portable file:

| Relative path | Git blob SHA |
| --- | --- |
| Package.swift | 0e0e8f674923cd3d49dd1f9d9be801ffcf516b8f |
| .gitignore | 2d16343e158018eb338e605b00989f9ca8f5c8ec |
| Sources/JarvisCore/Core.swift | 2cd72d8a37b13bc988d7fa74d276a3baec6baac7 |
| Sources/JarvisCore/UpstreamContract.swift | 528e79d8c7bb85887dfbbf6e314ea84b3dd13864 |
| Tests/JarvisCoreTests/AgentTests.swift | daa8ec4857f91144dcd9495610c20e2c56ef9fa6 |
| Tests/JarvisCoreTests/BridgeTests.swift | d2adbd5e31bdb5b13d266e0f3a69faa66444ed0a |

No source modifications from original archive. Full historical archive remains external; native files and scripts will be imported separately.

Observed test output excerpt:
```
Test Suite 'BridgeTests' passed at 2026-11-27 02:48:05.773
    Executed 6 tests, with 0 failures (0 unexpected) in 0.108 (0.108) seconds
Test Suite 'debug.xctest' passed at 2026-11-27 02:48:05.773
    Executed 16 tests, with 0 failures (0 unexpected) in 0.142 (0.142) seconds
Test Suite 'All tests' passed at 2026-11-27 02:48:05.773
    Executed 16 tests, with 0 failures (0 unexpected) in 0.142 (0.142) seconds
```
