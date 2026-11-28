#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "${1:-}" == "--lexical-only" ]]; then
  exec python3 benchmarks/analyze-retrieval.py --lexical-only
fi
mode=embedding
case "${1:-}" in
  --answerability) mode=answerability; shift ;;
  --pointwise) mode=pointwise; shift ;;
  --grounded) mode=grounded; shift ;;
esac
[[ $# -eq 0 ]] || { echo 'Usage: benchmark-memory-retrieval.sh [--lexical-only|--answerability|--pointwise|--grounded]' >&2; exit 2; }
[[ "$(uname -s)" == Darwin ]] || { echo 'Native measurements require macOS. Use --lexical-only for the portable baseline.' >&2; exit 2; }
mkdir -p audit
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
if [[ "$mode" == grounded ]]; then
  for input in audit/memory-distances.json audit/memory-pointwise.json; do
    [[ -s "$input" ]] || { echo "Missing saved benchmark input: $input" >&2; exit 2; }
  done
  xcrun swiftc -parse-as-library -swift-version 6 benchmarks/MeasureAnswerability.swift -o "$temp/answerability"
  "$temp/answerability" benchmarks/semantic-retrieval.json audit/memory-grounded.json --grounded audit/memory-pointwise.json
  git rev-parse HEAD > audit/memory-grounded-source.txt
  python3 benchmarks/analyze-retrieval.py --distances audit/memory-distances.json --pointwise audit/memory-pointwise.json --grounded audit/memory-grounded.json | tee audit/memory-grounded-benchmark.txt
  exit
fi
git rev-parse HEAD > audit/memory-benchmark-source.txt
xcodebuild -version >> audit/memory-benchmark-source.txt
uname -m >> audit/memory-benchmark-source.txt
xcrun swiftc -swift-version 6 Sources/JarvisCore/{Note,MemoryRetrieval}.swift benchmarks/MeasureNative.swift -o "$temp/measure"
"$temp/measure" benchmarks/semantic-retrieval.json audit/memory-distances.json
analysis=(--distances audit/memory-distances.json)
if [[ "$mode" != embedding ]]; then
  xcrun swiftc -parse-as-library -swift-version 6 benchmarks/MeasureAnswerability.swift -o "$temp/answerability"
  if [[ "$mode" == pointwise ]]; then
    "$temp/answerability" benchmarks/semantic-retrieval.json audit/memory-pointwise.json --pointwise
    analysis+=(--pointwise audit/memory-pointwise.json)
  else
    "$temp/answerability" benchmarks/semantic-retrieval.json audit/memory-answerability.json
    analysis+=(--answerability audit/memory-answerability.json)
  fi
fi
python3 benchmarks/analyze-retrieval.py "${analysis[@]}" | tee audit/memory-benchmark.txt
