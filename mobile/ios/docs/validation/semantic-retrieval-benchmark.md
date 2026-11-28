# Apple sentence embedding regression and relevance benchmark

## Recorded failure

On Apple Silicon with Xcode 27.2 build 27B52, the owner ran commit `f3f7570cb5f7963cd4d156602f2edc6d9c2e4cf5` twice. Both runs executed 84 Swift tests with 83 passing. `NativeMemoryEmbeddingTests.testSentenceEmbeddingRanksSeedGerminationCloserThanBattery` passed relative ordering and failed the absolute assertion at MemoryRetrievalTests.swift:58. The observed distance was 1.0654124021530151 and the required bound was 0.45. The original test and threshold remain in force.

## What the implementation does

The matcher requests Apple's default English sentence embedding on every lookup. It does not pin a revision, identify query language or normalize input. It uses the original query and note strings and requests cosine distance. The theoretical cosine-distance range is 0 to 2. Lower means closer. Availability is optional and nonfinite or out-of-range values now count as unavailable. The probes report supported, current and actual revision, dimension, operating system, self-distance, raw distance, vector-derived cosine distance and the sample coverage of both vectors. Results also compare canonical Unicode plus collapsed whitespace against the current raw input. Revision and asset availability are independent of the Xcode version number.

The existing ranker uses the greater of lexical coverage and a capped semantic score. A single overlapping term can therefore admit a negative even when the native score is unavailable or above the cutoff. The benchmark evaluates the automatic context cap of three. It does not estimate the separate five-item explicit search limit. Requests denying memory remain blocked before retrieval.

## Reproduce without Actions

From the PR checkout on macOS with the intended Xcode selected:

```bash
cd mobile/ios
./scripts/benchmark-memory-retrieval.sh
swift test --filter '^JarvisCoreTests.MemoryRetrievalTests'
swift test --filter NativeMemoryEmbeddingTests
```

The benchmark writes `audit/memory-benchmark-source.txt`, `audit/memory-distances.json`, and `audit/memory-benchmark.txt`. A native run prints metadata, 30 queries and 120 unique labeled pairs, positive and negative distance percentiles, the exact germination scores, missing counts and per-policy confusion counts and rates. Undefined precision or recall is JSON null. A missing native embedding produces explicit missing-data output and exits nonzero. Native acceptance runs separately from the deterministic mocked tests. Continue to `swift test`, then `./scripts/setup-ios.sh --native` and hosted simulator validation after the relevance policy and original native acceptance regression are resolved.

For the portable lexical baseline, run `./scripts/benchmark-memory-retrieval.sh --lexical-only`. The corpus uses four manually labeled candidates per query, query-level calibration and holdout, and three no-answer groups per split. The lexical baseline on this corpus retrieved 5 TP / 23 FP in calibration and 11 TP / 27 FP in holdout, for precision 17.86% / 28.95%, recall 41.67% / 91.67%, FPR 47.92% / 56.25% and FNR 58.33% / 8.33%. These results describe synthetic cases and are not native semantic measurements.

## Policy decision and device diagnosis

Evaluate absolute cutoffs, then top-one score floors with relative margins, and confidence abstention with or without lexical fusion. Choose one candidate using only calibration data, requiring precision at least 90%, recall at least 65%, pair false-positive rate at most 5%, and no injection for no-answer queries. Rank qualifying candidates by recall, then lowest false-positive rate. Apply the same gates on holdout without retuning. If none qualifies, leave the production policy unchanged and collect more representative evidence. A qualifying candidate is still provisional until reproduced on the owner's Mac and iPhone embedding revision and accepted by the preserved regression gate. The small synthetic corpus is useful for detecting unsafe behavior and cannot establish population-level quality.

Relative ordering alone can coexist with a rejected injection. This defect could explain missing context for paraphrases. It cannot by itself explain an inference failure in a request where memory was explicitly disabled. Run the same eight comparative diagnostics twice on the same signed build. Keep model/structured-output failures, agent errors and memory selection observations separate. Use no personal data in artifacts. SQLite storage and native permissions are outside this change.
