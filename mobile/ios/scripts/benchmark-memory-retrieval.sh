#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "${1:-}" == "--lexical-only" ]]; then
  exec python3 benchmarks/analyze-retrieval.py --lexical-only
fi
answerability=false
if [[ "${1:-}" == "--answerability" ]]; then
  answerability=true
  shift
fi
[[ $# -eq 0 ]] || { echo 'Usage: benchmark-memory-retrieval.sh [--lexical-only|--answerability]' >&2; exit 2; }
[[ "$(uname -s)" == Darwin ]] || { echo 'Native measurements require macOS. Use --lexical-only for the portable baseline.' >&2; exit 2; }
mkdir -p audit
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
git rev-parse HEAD > audit/memory-benchmark-source.txt
xcodebuild -version >> audit/memory-benchmark-source.txt
uname -m >> audit/memory-benchmark-source.txt
xcrun swiftc -swift-version 6 Sources/JarvisCore/{Note,MemoryRetrieval}.swift benchmarks/MeasureNative.swift -o "$temp/measure"
"$temp/measure" benchmarks/semantic-retrieval.json audit/memory-distances.json
analysis=(--distances audit/memory-distances.json)
if [[ "$answerability" == true ]]; then
  xcrun swiftc -parse-as-library -swift-version 6 benchmarks/MeasureAnswerability.swift -o "$temp/answerability"
  "$temp/answerability" benchmarks/semantic-retrieval.json audit/memory-answerability.json
  analysis+=(--answerability audit/memory-answerability.json)
fi
python3 benchmarks/analyze-retrieval.py "${analysis[@]}" | tee audit/memory-benchmark.txt
