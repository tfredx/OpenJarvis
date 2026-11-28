"""Run from mobile/ios on a Mac with the original saved pointwise judgments."""
import json
import re
import runpy
import subprocess
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parent
scorer = runpy.run_path(str(here / "analyze-retrieval.py"))


def score(groups, pointwise, verified):
    ids = {r["id"] for g in groups for r in g["candidates"]}
    judgments, approvals, _ = scorer["pointwise_policy"](pointwise, ids)
    if None in judgments.values():
        raise ValueError("Incomplete pointwise evidence")
    expected = {i for i in ids if judgments[i]}
    grounded, _, _ = scorer["pointwise_policy"](verified, expected)
    if None in grounded.values():
        raise ValueError("Incomplete grounding evidence")
    source = (root / "Sources/JarvisCore/MemoryRetrieval.swift").read_text()
    words = set(re.findall(r'"([a-z]+)"', source.split("private static let stopWords", 1)[1].split("]", 1)[0]))
    eligible = {r["id"] for g in groups if len(scorer["query_terms"](g["query"], words)) >= 2
                for r in g["candidates"]}
    def policy(rows):
        accepted = {i for i in approvals(rows) if i in eligible and grounded[i]}
        return accepted if len(accepted) == 1 else set()
    return scorer["metrics"](groups, policy)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        binary = Path(tmp) / "judge"
        subprocess.run(["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
                        here / "MeasureAnswerability.swift", "-o", binary], check=True)
        directory = Path(tempfile.mkdtemp(prefix="confirmation-", dir=root / "audit"))
        print("Evidence directory", directory, flush=True)
        for fresh in (False, True):
            corpus = here / ("retrieval-confirmation.json" if fresh else "semantic-retrieval.json")
            groups = json.loads(corpus.read_text())
            point = root / "audit/memory-pointwise.json"
            if fresh:
                point = directory / "fresh-pointwise.json"
                subprocess.run([binary, corpus, point, "--pointwise"], check=True)
            verified = directory / (corpus.stem + "-verified.json")
            mode = "--verify-all" if fresh else "--verify-singles"
            subprocess.run([binary, corpus, verified, mode, point], check=True)
            decisions = json.loads(point.read_text())
            evidence = json.loads(verified.read_text())
            if not fresh:
                evidence.extend(json.loads((root / "audit/memory-grounded.json").read_text()))
            for name in (["confirmation"] if fresh else ["calibration", "previous-holdout"]):
                subset = groups if fresh else [g for g in groups if g["split"] == name.removeprefix("previous-")]
                ids = {c["id"] for g in subset for c in g["candidates"]}
                result = score(subset, [r for r in decisions if r["id"] in ids],
                               [r for r in evidence if r["id"] in ids])
                print(name, json.dumps(result), flush=True)
                if ((result["precision"] or 0) < .90 or result["recall"] < .65
                        or result["fpr"] > .05 or result["no_answer_injected"]):
                    raise SystemExit("Rejected on " + name)
        print("Benchmark acceptance passed")


if __name__ == "__main__":
    main()
