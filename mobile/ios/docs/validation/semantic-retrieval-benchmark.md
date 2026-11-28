# Apple sentence embedding regression and relevance benchmark

## Recorded failure

On Apple Silicon with Xcode 27.2 build 27B52, the owner ran commit `f3f7570cb5f7963cd4d156602f2edc6d9c2e4cf5` twice. Both runs executed 84 Swift tests with 83 passing. `NativeMemoryEmbeddingTests.testSentenceEmbeddingRanksSeedGerminationCloserThanBattery` passed relative ordering and failed the absolute assertion at MemoryRetrievalTests.swift:58. The observed distance was 1.0654124021530151 and the required bound was 0.45. The original test and threshold remain in force.

## What the implementation does

The matcher requests Apple's default English sentence embedding on every lookup. It does not pin a revision, identify query language or normalize input. It uses the original query and note strings. The corrective branch computes cosine distance directly from the sentence vectors and retains the framework string distance separately for benchmark replay. Apple documents cosine distance as one minus cosine similarity in the range 0 to 2. Lower means closer. The observed sentence output on the runner used a different scale, as shown below. Availability is optional and nonfinite or out-of-range values now count as unavailable. The probes report supported, current and actual revision, dimension, operating system, self-distance, raw distance, vector-derived cosine distance and the sample coverage of both vectors. Results also compare canonical Unicode plus collapsed whitespace against the current raw input. Revision and asset availability are independent of the Xcode version number.

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

## Hosted native evidence

[Mobile iOS CI run 46106681604](https://github.com/tfredx/OpenJarvis/actions/runs/46106681604) measured the synthetic corpus on arm64 macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), English embedding revision 1, dimension 512. All 120 pairs returned distances. The probe's self-distance was zero. The original assertion reproduced the owner's exact value. The [native diagnostics ZIP](https://github.com/tfredx/OpenJarvis/actions/runs/46106681604/artifacts/15247178492) contains independent raw readings, revision metadata and the unmodified regression log.

| Measurement | Relevant pairs (24) | Irrelevant pairs (96) |
| --- | --- | --- |
| Framework distance min / median / max | 0.962878 / 1.101164 / 1.305291 | 0.794519 / 1.183024 / 1.362074 |
| Vector cosine distance min / median / max | 0.463567 / 0.606281 / 0.851893 | 0.315630 / 0.699773 / 0.927622 |

For all pairs, squaring the framework distance and dividing by two reproduced independently computed vector cosine distance within 0.000000624. This is consistent with chord distance between unit vectors on this revision. It is an observed relationship, not a guarantee for other revisions. NFC and whitespace normalization produced identical distances for this corpus, including the two whitespace stress queries. The germination and battery framework distances were 1.065412 and 1.265337, respectively. Their vector cosine distances were 0.567552 and 0.800539. Metric conversion alone still fails the preserved 0.45 germination bound. The distributions overlap substantially on either scale.

On the calibration split a framework cutoff of 1.15 had 28.00% precision, 58.33% recall, 37.50% FPR and 41.67% FNR, with injection on all three no-answer queries. A vector cosine cutoff of 0.65 had 26.09% precision, 50.00% recall, 35.42% FPR and 50.00% FNR. Rescoring the downloaded observations with both scales found no candidate that met calibration criteria, so no candidate was carried into holdout. CI passed the portable and five security jobs, then stopped on the original native assertion ahead of device and simulator builds.

## Policy decision and device diagnosis

Evaluate absolute cutoffs and top-one score floors with relative margins and confidence abstention, with or without lexical fusion, on both distance scales. Choose one candidate using only calibration data, requiring precision at least 90%, recall at least 65%, pair false-positive rate at most 5%, and no injection for no-answer queries. Rank qualifying candidates by recall, then lowest false-positive rate. Apply the same gates on holdout without retuning. If none qualifies, leave the production policy unchanged and collect more representative evidence. The macOS CI job requires a qualifying candidate and the preserved native assertion before resuming the full build. A qualifying candidate is still provisional until reproduced on the owner's Mac and iPhone embedding revision and accepted by the preserved regression gate. The small synthetic corpus is useful for detecting unsafe behavior and cannot establish population-level quality.

Relative ordering alone can coexist with a rejected injection. This defect could explain missing context for paraphrases. It cannot by itself explain an inference failure in a request where memory was explicitly disabled. Run the same eight comparative diagnostics twice on the same signed build. Keep model/structured-output failures, agent errors and memory selection observations separate. Use no personal data in artifacts. SQLite storage and native permissions are outside this change.


## Corrective candidate experiment

The matcher now computes one minus cosine similarity from native vectors, rather than assuming the string-distance return scale. The original germination threshold assertion remains unchanged. The candidate evaluator also measures directed query-term coverage with the OS English word embedding. Exact lexical matches have full weight, weak and missing associations contribute zero, and the highest-scoring note must meet an absolute score floor and a separation margin. The sentence score may corroborate the term signal. The experiment is evaluated on the unchanged query splits and does not enable a new relevance policy in the application.

For a quick result after the native benchmark, run:

```bash
grep -E 'metadata|^candidate|^holdout word-alignment|^word-alignment-unavailable' audit/memory-benchmark.txt
```

Evidence is admissible only with the word embedding available and the unchanged calibration and holdout gates satisfied. An experimental winner still requires policy implementation parity and independent validation before integration.


## Owner Mac validation of answerability

Hosted run [46108460427](https://github.com/tfredx/OpenJarvis/actions/runs/46108460427) showed vector-derived germination distance 0.5675518626625164 and preserved the failing 0.45 assertion. No native word-alignment configuration qualified. One setting that had zero false positives found just two of 12 relevant calibration notes. The sentence matcher ranked the relevant note first for three of 12 answer-bearing calibration queries and five of 12 holdout queries on the earlier artifact.

The opt-in experiment uses Apple Foundation Models locally to select a single note that directly answers a synthetic query, or abstain. The model sees only the question and note texts, without candidate IDs, labels or splits. Two fresh sessions see opposite note order. A note is selected only if both valid verdicts identify the same note. Disagreement abstains. Any failed verdict prevents a candidate decision for the experiment. No runtime retrieval uses this model. No production note is read or exported.

On macOS with Apple Intelligence ready, run `./scripts/benchmark-memory-retrieval.sh --answerability` from `mobile/ios`. It performs 60 model calls and writes `audit/memory-answerability.json` and the metric report. Look for `answerability`, `calibration answerability-consensus`, `holdout answerability-consensus` and `candidate` in the summary. A candidate must satisfy the same 90% precision, 65% recall, 5% false-positive ceiling and zero no-answer injections in both splits. A scorer-only synthetic fixture validated the report plumbing. Native answerability performance is unmeasured.
