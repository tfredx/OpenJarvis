#!/usr/bin/env python3
"""Score a labeled, query-grouped synthetic corpus. Uses the standard library."""
import argparse
import json
import math
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent


def lexical(query, note, stop_words):
    terms = {t for t in re.findall(r"[a-z0-9]+", query.lower()) if len(t) > 2} - stop_words
    return len(terms.intersection(re.findall(r"[a-z0-9]+", note.lower()))) / len(terms) if terms else 0


def ranked(rows, score, minimum=0, cap=3, margin=None):
    scores = [(score(row), row["id"]) for row in rows]
    scores = sorted(((s, ident) for s, ident in scores if s is not None), reverse=True, key=lambda x: x[0])
    if margin is not None and (len(scores) < 2 or scores[0][0] - scores[1][0] < margin):
        return set()
    return {ident for s, ident in scores[:cap] if s > minimum}


def production(rows):
    def score(row):
        d = row["distance"]
        semantic = 0.5 * (1 - d / 0.45) if d is not None and 0 <= d <= 0.45 else 0
        return max(row["lexical"], semantic)
    return ranked(rows, score)


def select_absolute(rows, threshold):
    return ranked(rows, lambda r: -r["distance"] if r["distance"] is not None
                  and r["distance"] <= threshold else None, minimum=-math.inf)


def select_confident(rows, threshold, margin, lexical_weight):
    if any(row["distance"] is None for row in rows):
        return set()
    def score(row):
        return (1 - lexical_weight) * (1 - row["distance"] / 2) + lexical_weight * row["lexical"]
    return ranked(rows, score, minimum=threshold, cap=1, margin=margin)


def pointwise_policy(evidence, ids):
    judgments = {row["id"]: row.get("answers") for row in evidence}
    if set(judgments) != ids or len(judgments) != len(evidence):
        raise SystemExit("Pointwise measurements do not match candidate pairs.")
    if any(value is not None and type(value) is not bool for value in judgments.values()):
        raise SystemExit("Invalid pointwise verdict.")

    def evidence_for(rows):
        return [row["id"] for row in rows if judgments[row["id"]] is True]

    def select(rows):
        approved = evidence_for(rows)
        return set(approved) if len(approved) == 1 else set()

    return judgments, evidence_for, select


def pointwise_tiebreak(rows, approvals, cosine_margin, word_margin):
    approved = set(approvals(rows))
    if len(approved) <= 1:
        return approved
    eligible = [r for r in rows if r["id"] in approved]
    for row in eligible:
        for field, maximum in (("matcher_cosine", 2), ("word_coverage", 1)):
            value = row.get(field)
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= maximum:
                return set()

    cosine = sorted(eligible, key=lambda r: r["matcher_cosine"])
    words = sorted(eligible, key=lambda r: r["word_coverage"], reverse=True)
    if cosine[0]["id"] != words[0]["id"]:
        return set()
    if cosine[1]["matcher_cosine"] - cosine[0]["matcher_cosine"] < cosine_margin:
        return set()
    if words[0]["word_coverage"] - words[1]["word_coverage"] < word_margin:
        return set()
    return {cosine[0]["id"]}


def divide(num, den):
    return num / den if den else None


def metrics(groups, policy):
    tp = fp = tn = fn = abstained = no_answer_injected = 0
    for group in groups:
        rows = group["candidates"]
        selected = policy(rows)
        abstained += not selected
        no_answer_injected += bool(selected) and not any(r["relevant"] for r in rows)
        for row in rows:
            predicted = row["id"] in selected
            expected = row["relevant"]
            tp += expected and predicted
            fp += not expected and predicted
            tn += not expected and not predicted
            fn += expected and not predicted
    return dict(tp=tp, fp=fp, tn=tn, fn=fn, precision=divide(tp, tp + fp), recall=divide(tp, tp + fn),
                fpr=divide(fp, fp + tn), fnr=divide(fn, tp + fn),
                abstained=abstained, no_answer_injected=no_answer_injected)


def distribution(values):
    values = sorted(v for v in values if v is not None)
    if not values:
        return {"n": 0}
    return {"n": len(values), **{f"p{pct}": round(values[round((len(values) - 1) * pct / 100)], 6)
                               for pct in (0, 10, 25, 50, 75, 90, 100)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--distances", type=Path)
    mode.add_argument("--lexical-only", action="store_true")
    parser.add_argument("--answerability", type=Path)
    parser.add_argument("--pointwise", type=Path)
    parser.add_argument("--grounded", type=Path)
    args = parser.parse_args()
    if args.grounded and not args.pointwise:
        parser.error("--grounded requires --pointwise")
    if (args.answerability or args.pointwise) and args.lexical_only:
        parser.error("Model experiments require --distances")

    groups = json.loads((HERE / "semantic-retrieval.json").read_text())
    candidates = [row for group in groups for row in group["candidates"]]
    ids = {row["id"] for row in candidates}
    if len(ids) != len(candidates) or len(ids) < 100:
        raise SystemExit("Corpus requires at least 100 uniquely labeled pairs.")
    metadata = {"available": False, "mode": "lexical-only"}
    if args.distances:
        evidence = json.loads(args.distances.read_text())
        native = {row["id"]: row for row in evidence["rows"]}
        if set(native) != ids or len(native) != len(evidence["rows"]):
            raise SystemExit("Native measurements do not match the corpus.")
        metadata = evidence["metadata"]
    else:
        swift = (HERE.parent / "Sources/JarvisCore/MemoryRetrieval.swift").read_text()
        stop_words = set(re.findall(r'"([a-z]+)"', swift.split("private static let stopWords", 1)[1].split("]", 1)[0]))
        native = {row["id"]: {"distance": None, "lexical": lexical(g["query"], row["text"], stop_words)}
                  for g in groups for row in g["candidates"]}
    for row in candidates:
        row.update(native[row["id"]])

    print(json.dumps({"pairs": len(ids), "queries": len(groups), "metadata": metadata}, sort_keys=True))
    calibration = [g for g in groups if g["split"] == "calibration"]
    holdout = [g for g in groups if g["split"] == "holdout"]
    for name, subset in [("calibration", calibration), ("holdout", holdout)]:
        print(name, "lexical-baseline", json.dumps(metrics(subset, lambda rows: ranked(rows, lambda r: r["lexical"]))))
        print(name, "production", json.dumps(metrics(subset, production)))

    if args.lexical_only:
        return
    rows = list(native.values())
    for row in candidates:
        d = row["distance"]
        if d is not None and (not isinstance(d, (float, int)) or not math.isfinite(d) or not 0 <= d <= 2):
            raise SystemExit("Native matcher returned an invalid cosine distance.")
    for label in (True, False):
        for field in ("distance", "normalized", "cosine_from_vectors"):
            print("distance-distribution", label, field,
                  json.dumps(distribution(r.get(field) for r in candidates if r["relevant"] == label)))
    for field in ("normalized", "cosine_from_vectors"):
        print("absolute-difference-from-production", field,
              json.dumps(distribution(abs(r["distance"] - r[field]) for r in rows
                                      if r["distance"] is not None and r.get(field) is not None)))
    print("germination-regression", json.dumps({r["id"]: r for r in rows if r["id"] in ("germination-1", "germination-2")}))
    missing = sum(r["distance"] is None for r in rows)
    print("native-missing", missing)
    if not metadata["available"] or missing or metadata.get("self_distance") is None:
        raise SystemExit("Native evidence is incomplete. No candidate policy may be selected.")

    print("chord-transform-residual",
          json.dumps(distribution(abs(r["distance"] ** 2 / 2 - r["cosine_from_vectors"])
                                  for r in rows if r.get("cosine_from_vectors") is not None)))

    policies = {}
    # Score both scales using calibration only. The bool binds the adapter for
    # each policy, so only one selected candidate is checked on holdout.
    def scale(policy, use_vectors):
        if not use_vectors:
            return policy
        return lambda rs: policy([{**r, "distance": r["cosine_from_vectors"]} for r in rs])

    for name, cutoffs, use_vectors in [
        ("framework", (0.45, 0.7, 0.9, 1.05, 1.15, 1.3), False),
        ("vectors", (0.45, 0.55, 0.65, 0.75, 0.85, 0.95), True)
    ]:
        if use_vectors and any(r.get("cosine_from_vectors") is None for r in rows):
            print("vector-policy-unavailable: missing vector-derived cosine distances")
            continue
        for cutoff in cutoffs:
            policies[f"absolute-{name}-{cutoff}"] = scale(
                lambda rs, cutoff=cutoff: select_absolute(rs, cutoff), use_vectors
            )
        for weight in (0, 0.25, 0.5):
            for floor in (0.35, 0.50, 0.65):
                for gap in (0.03, 0.08, 0.15):
                    policies[f"confidence-fusion-{name}-{weight}-{floor}-{gap}"] = scale(
                        lambda rs, floor=floor, gap=gap, weight=weight: select_confident(rs, floor, gap, weight),
                        use_vectors
                    )
    if all(r.get("word_coverage") is not None and r.get("matcher_cosine") is not None for r in rows):
        for word_weight in (0.5, 0.75, 1):
            for floor in (0.2, 0.35, 0.5, 0.65):
                for gap in (0.03, 0.08, 0.15):
                    policies[f"word-alignment-{word_weight}-{floor}-{gap}"] = (
                        lambda rs, w=word_weight, floor=floor, gap=gap: ranked(
                            rs, lambda r: w * r["word_coverage"] + (1 - w) * (1 - r["matcher_cosine"]),
                            minimum=floor, cap=1, margin=gap
                        )
                    )
    else:
        print("word-alignment-unavailable: native word or matcher measurements missing")
    listwise_endorsements = None
    if args.answerability:
        evidence = json.loads(args.answerability.read_text())
        judgments = {row["id"]: row for row in evidence}
        if set(judgments) != {g["id"] for g in groups} or len(judgments) != len(evidence):
            raise SystemExit("Answerability measurements do not match query groups.")
        selected = set()
        endorsed = set()
        failures = disagreements = 0
        for group in groups:
            row = judgments[group["id"]]
            valid = {candidate["id"] for candidate in group["candidates"]} | {None}
            forward, reverse = row.get("forward"), row.get("reversed")
            if forward not in valid or reverse not in valid or row["failures"] not in (0, 1, 2):
                raise SystemExit("Invalid answerability measurement.")
            failures += row["failures"]
            disagreements += forward != reverse
            if row["failures"] == 0:
                endorsed.update(ident for ident in (forward, reverse) if ident is not None)
                if forward is not None and forward == reverse:
                    selected.add(forward)
        print("answerability", json.dumps({"failed_verdicts": failures, "order_disagreements": disagreements}))
        if failures == 0:
            listwise_endorsements = endorsed
            policies["answerability-consensus"] = lambda rs: {r["id"] for r in rs if r["id"] in selected}
        else:
            print("answerability-ineligible: incomplete model evidence")

    if args.pointwise:
        evidence = json.loads(args.pointwise.read_text())
        judgments, approvals, select = pointwise_policy(evidence, ids)
        failures = sum(value is None for value in judgments.values())
        ambiguous = sum(len(approvals(g["candidates"])) > 1 for g in calibration)
        print("pointwise", json.dumps({"failed_verdicts": failures,
                                       "calibration_multiple_approvals": ambiguous}))
        if failures == 0:
            policies["pointwise-single-answer"] = select
            # Preserve all unique approvals. For ambiguous groups require the
            # same winner on both native signals and a margin on each.
            for cosine_gap in (0.02, 0.05, 0.10):
                for word_gap in (0.025, 0.075, 0.15):
                    policies[f"pointwise-tiebreak-{cosine_gap}-{word_gap}"] = (
                        lambda rs, cg=cosine_gap, wg=word_gap: pointwise_tiebreak(rs, approvals, cg, wg)
                    )
        else:
            print("pointwise-ineligible: incomplete model evidence")

    if args.grounded:
        evidence = json.loads(args.grounded.read_text())
        grounded = {row["id"]: row.get("answers") for row in evidence}
        expected = {ident for group in groups
                    if len(approved := approvals(group["candidates"])) > 1
                    for ident in approved}
        if set(grounded) != expected or len(grounded) != len(evidence):
            raise SystemExit("Grounded measurements do not match ambiguous approvals.")
        if any(value is not None and type(value) is not bool for value in grounded.values()):
            raise SystemExit("Invalid grounded verdict.")

        def select_grounded(rs, endorsements=None):
            approved = approvals(rs)
            if len(approved) <= 1:
                return set(approved)
            supported = [ident for ident in approved if grounded[ident] is True]
            if len(supported) != 1:
                return set()
            if endorsements is not None and supported[0] not in endorsements:
                return set()
            return {supported[0]}

        failed = sum(value is None for value in grounded.values())
        print("grounded", json.dumps({"checked_approvals": len(grounded), "failed_verdicts": failed}))
        if failures == 0 and failed == 0:
            policies["grounded-single-answer"] = select_grounded
            if listwise_endorsements is not None:
                # Corroborate an already unique grounded winner. A listwise
                # endorsement cannot break a tie or replace a rejected note.
                policies["grounded-listwise-corroborated"] = (
                    lambda rs: select_grounded(rs, listwise_endorsements)
                )
        else:
            print("grounded-ineligible: incomplete model evidence")

    results = {name: metrics(calibration, policy) for name, policy in policies.items()}
    for name, result in results.items():
        print("calibration", name, json.dumps(result))
    def acceptable(result):
        return ((result["precision"] or 0) >= 0.9 and (result["recall"] or 0) >= 0.65
                and result["fpr"] <= 0.05 and result["no_answer_injected"] == 0)
    eligible = [name for name, result in results.items() if acceptable(result)]
    if not eligible:
        print("candidate none: calibration safety or recall criterion not met")
        return
    picked = sorted(eligible, key=lambda n: (-results[n]["recall"], results[n]["fpr"], n))[0]
    result = metrics(holdout, policies[picked])
    print("holdout", picked, json.dumps(result))
    for category in sorted({g["category"] for g in holdout}):
        print("holdout-category", category, json.dumps(metrics([g for g in holdout if g["category"] == category], policies[picked])))
    print("candidate", picked if acceptable(result) else "none: holdout criterion not met")


if __name__ == "__main__":
    main()
