"""Run from mobile/ios on a Mac with the original saved pointwise judgments."""
import argparse
import json
import re
import runpy
import subprocess
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parent
scorer = runpy.run_path(str(here / "analyze-retrieval.py"))


def qualified_candidates(group, stop_words):
    query = group["query"]
    terms = scorer["query_terms"](query, stop_words)
    if len(terms) < 2:
        return set()

    def tokens(text):
        return re.findall(r"[a-z0-9]+", text.lower())

    def phrases(sequence):
        return set(zip(sequence, sequence[1:]))

    query_pairs = {(left, right) for left, right in phrases(tokens(query))
                   if left in terms and right in terms}
    notes = {r["id"]: tokens(r["text"]) for r in group["candidates"]}
    observed = {pair for sequence in notes.values() for pair in phrases(sequence)}
    qualifiers = query_pairs & observed
    # If another note explicitly names the requested compound, veto a note
    # that mentions its head while omitting its qualifier.
    return {ident for ident, sequence in notes.items()
            if all(head not in sequence or modifier in sequence
                   for modifier, head in qualifiers)}


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
    eligible = {ident for group in groups for ident in qualified_candidates(group, words)}
    overlaps = {}
    qualified_by_time = set()
    for group in groups:
        terms = scorer["query_terms"](group["query"], words)
        if re.search(r"\b(?:after|before|until|since|during)\b", group["query"], re.IGNORECASE):
            qualified_by_time.update(note["id"] for note in group["candidates"])
        for note in group["candidates"]:
            overlaps[note["id"]] = terms.intersection(re.findall(r"[a-z0-9]+", note["text"].lower()))

    def policy(rows):
        accepted = {i for i in approvals(rows) if grounded[i]}
        if len(accepted) > 1 and accepted & qualified_by_time:
            return set()
        # Break a tie only if one verified note covers every matched term
        # of every competitor and contributes an additional matched term.
        return {i for i in accepted if i in eligible
                and all(overlaps[i] > overlaps[j] for j in accepted if j != i)}
    return scorer["metrics"](groups, policy)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--saved-singletons", type=Path)
    parser.add_argument("--saved-confirmation", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        binary = Path(tmp) / "judge"
        subprocess.run(["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
                        here / "MeasureAnswerability.swift", "-o", binary], check=True)
        directory = Path(tempfile.mkdtemp(prefix="confirmation-", dir=root / "audit"))
        print("Evidence directory", directory, flush=True)
        for dataset in ["semantic-retrieval", "retrieval-confirmation", "retrieval-replication"]:
            original = dataset == "semantic-retrieval"
            corpus = here / (dataset + ".json")
            groups = json.loads(corpus.read_text())
            point = directory / (dataset + "-pointwise.json")
            verified = directory / (dataset + "-verified.json")
            if original:
                point = root / "audit/memory-pointwise.json"
            if dataset == "retrieval-confirmation" and args.saved_confirmation:
                point = args.saved_confirmation / "fresh-pointwise.json"
                verified = args.saved_confirmation / (dataset + "-verified.json")
            else:
                if not original:
                    subprocess.run([binary, corpus, point, "--pointwise"], check=True)
                if original and args.saved_singletons:
                    verified = args.saved_singletons
                else:
                    mode = "--verify-singles" if original else "--verify-all"
                    subprocess.run([binary, corpus, verified, mode, point], check=True)
            decisions = json.loads(point.read_text())
            evidence = json.loads(verified.read_text())
            if original:
                evidence.extend(json.loads((root / "audit/memory-grounded.json").read_text()))
            for name in (["calibration", "previous-holdout"] if original else [dataset]):
                subset = groups if not original else [g for g in groups if g["split"] == name.removeprefix("previous-")]
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
