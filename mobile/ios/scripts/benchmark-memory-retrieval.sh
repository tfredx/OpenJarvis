#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "${1:-}" == "--lexical-only" ]]; then
  exec python3 benchmarks/analyze-retrieval.py --lexical-only
fi
[[ $# -eq 0 ]] || { echo 'Usage: benchmark-memory-retrieval.sh [--lexical-only]' >&2; exit 2; }
[[ "$(uname -s)" == Darwin ]] || { echo 'Native measurements require macOS. Use --lexical-only for the portable baseline.' >&2; exit 2; }
mkdir -p audit
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
git rev-parse HEAD > audit/memory-benchmark-source.txt
xcodebuild -version >> audit/memory-benchmark-source.txt
uname -m >> audit/memory-benchmark-source.txt
xcrun swiftc -swift-version 6 Sources/JarvisCore/{Note,MemoryRetrieval}.swift benchmarks/MeasureNative.swift -o "$temp/measure"
"$temp/measure" benchmarks/semantic-retrieval.json audit/memory-distances.json
python3 benchmarks/analyze-retrieval.py --distances audit/memory-distances.json | tee audit/memory-benchmark.txt
