# Physical-device memory diagnostics

Date reported: 2026-11-27. Source commit, device model, iOS version and raw logs/timings were not supplied; treat these results as owner-reported and do not attribute them to a particular build.

| Prompt | Reported result |
| --- | --- |
| What is the capital of France? | Pass |
| Explain why the sky is blue. | Pass |
| Write a five-sentence story about a dog. | Pass |
| What is a seed? Answer in one sentence. | Pass |
| Explain how a seed grows. Do not use tools or memory. | Fail |
| Describe the process of germination. | Fail |
| Explain how a plant grows from a seed. | Fail |
| Explain how a tree grows. | Fail |
| Explain how a battery works. | Fail |
| Explain how a seed grows. (exact reproduction, attempt one) | Fail |
| Explain how a seed grows. (exact reproduction, attempt two) | Fail |

These results show that the app was exercised on a physical device and basic generation worked for the four passing prompts. They do not identify whether semantic retrieval lacked an approved stored note, failed to select it, or failed later during model output. The unrelated battery prompt also failed, so the failures cannot be attributed solely to semantic recall from these results alone. The no-tools/no-memory request should be enforced in code regardless of model behavior.

The current regression increment adds local sentence-embedding ranking with lexical fallback and enforces explicit per-task tool/memory denials. Tests use synthetic notes and cover retrieval ranking, unrelated-note rejection, lexical fallback, request denials and legacy snapshot decoding. Simulator and physical-device retesting remain necessary; no latency, resource-use or broad feature-performance claim is made.
