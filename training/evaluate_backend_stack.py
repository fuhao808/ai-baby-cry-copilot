from __future__ import annotations

import csv
import json
import math
import statistics
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = ROOT / "backend"
TEST_MANIFEST = ROOT / "training" / "outputs" / "latest" / "test_manifest.csv"
CRY_LABELS = ["Hungry", "Sleepy", "Pain/Gas", "Fussy"]

sys.path.insert(0, str(BACKEND_DIR))

from services.audio_processor import analyze_audio_file  # noqa: E402


def main() -> None:
    rows = load_rows(TEST_MANIFEST)
    predictions = []
    for row in rows:
        audio_path = Path(row["audio_path"])
        if not audio_path.exists():
            continue
        result = analyze_audio_file(audio_path)
        predictions.append(
            {
                "file_name": audio_path.name,
                "true_label": row["app_label"],
                "analysis_family": result["analysis_family"],
                "top_result": result["top_result"],
                "predictions": result["predictions"],
                "top_confidence": result["predictions"].get(result["top_result"], 0.0),
            }
        )

    report = build_report(predictions)
    print(json.dumps(report, ensure_ascii=False, indent=2))


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [row for row in csv.DictReader(handle) if row["app_label"] in CRY_LABELS]


def build_report(items: list[dict]) -> dict:
    total = len(items)
    correct = sum(1 for item in items if item["top_result"] == item["true_label"])
    top2 = sum(
        1
        for item in items
        if item["true_label"] in top_k_labels(item["predictions"], 2)
    )
    family_counts = Counter(item["analysis_family"] for item in items)
    confusion = confusion_matrix(items)
    per_class = per_class_metrics(items)
    macro_f1 = statistics.fmean(metric["f1"] for metric in per_class.values())
    balanced_accuracy = statistics.fmean(
        metric["recall"] for metric in per_class.values()
    )
    top_confidences = [item["top_confidence"] for item in items]

    return {
        "count": total,
        "accuracy": round(safe_div(correct, total), 4),
        "macro_f1": round(macro_f1, 4),
        "balanced_accuracy": round(balanced_accuracy, 4),
        "top2_accuracy": round(safe_div(top2, total), 4),
        "family_counts": dict(family_counts),
        "avg_top_confidence": round(statistics.fmean(top_confidences), 4),
        "max_top_confidence": round(max(top_confidences), 4),
        "min_top_confidence": round(min(top_confidences), 4),
        "brier_score": round(multiclass_brier_score(items), 4),
        "ece_10bins": round(expected_calibration_error(items, bins=10), 4),
        "confusion_matrix": confusion,
        "per_class": per_class,
        "abstain_sweep": abstain_sweep(items),
        "highest_confidence_examples": top_examples(items, reverse=True),
        "lowest_confidence_examples": top_examples(items, reverse=False),
    }


def confusion_matrix(items: list[dict]) -> dict[str, dict[str, int]]:
    labels = CRY_LABELS + ["REJECTED_NON_CRY"]
    matrix = {label: {pred: 0 for pred in labels} for label in CRY_LABELS}
    for item in items:
        predicted = (
            item["top_result"]
            if item["analysis_family"] == "baby_cry" and item["top_result"] in CRY_LABELS
            else "REJECTED_NON_CRY"
        )
        matrix[item["true_label"]][predicted] += 1
    return matrix


def per_class_metrics(items: list[dict]) -> dict[str, dict[str, float]]:
    results = {}
    for label in CRY_LABELS:
        tp = sum(
            1
            for item in items
            if item["true_label"] == label and item["top_result"] == label
        )
        fp = sum(
            1
            for item in items
            if item["true_label"] != label and item["top_result"] == label
        )
        fn = sum(
            1
            for item in items
            if item["true_label"] == label and item["top_result"] != label
        )
        precision = safe_div(tp, tp + fp)
        recall = safe_div(tp, tp + fn)
        f1 = safe_div(2 * precision * recall, precision + recall)
        results[label] = {
            "precision": round(precision, 4),
            "recall": round(recall, 4),
            "f1": round(f1, 4),
        }
    return results


def multiclass_brier_score(items: list[dict]) -> float:
    total = 0.0
    for item in items:
        probs = item["predictions"]
        for label in CRY_LABELS:
            truth = 1.0 if item["true_label"] == label else 0.0
            total += (probs.get(label, 0.0) - truth) ** 2
    return total / max(len(items), 1)


def expected_calibration_error(items: list[dict], bins: int = 10) -> float:
    grouped: list[list[dict]] = [[] for _ in range(bins)]
    for item in items:
        confidence = float(item["top_confidence"])
        index = min(int(confidence * bins), bins - 1)
        grouped[index].append(item)

    ece = 0.0
    total = len(items)
    for bucket in grouped:
        if not bucket:
            continue
        avg_conf = statistics.fmean(item["top_confidence"] for item in bucket)
        avg_acc = statistics.fmean(
            1.0 if item["top_result"] == item["true_label"] else 0.0
            for item in bucket
        )
        ece += (len(bucket) / total) * abs(avg_conf - avg_acc)
    return ece


def abstain_sweep(items: list[dict]) -> list[dict[str, float]]:
    thresholds = [0.25, 0.28, 0.3, 0.32, 0.35, 0.4]
    output = []
    for threshold in thresholds:
        kept = [item for item in items if item["top_confidence"] >= threshold]
        rejected = len(items) - len(kept)
        accuracy = (
            safe_div(sum(1 for item in kept if item["top_result"] == item["true_label"]), len(kept))
            if kept
            else 0.0
        )
        output.append(
            {
                "threshold": threshold,
                "coverage": round(safe_div(len(kept), len(items)), 4),
                "rejected": rejected,
                "kept_accuracy": round(accuracy, 4),
            }
        )
    return output


def top_examples(items: list[dict], *, reverse: bool) -> list[dict]:
    ordered = sorted(items, key=lambda item: item["top_confidence"], reverse=reverse)
    selected = ordered[:10]
    return [
        {
            "file_name": item["file_name"],
            "true_label": item["true_label"],
            "analysis_family": item["analysis_family"],
            "top_result": item["top_result"],
            "top_confidence": round(item["top_confidence"], 4),
            "predictions": item["predictions"],
        }
        for item in selected
    ]


def top_k_labels(probabilities: dict[str, float], k: int) -> list[str]:
    return [
        label
        for label, _ in sorted(
            probabilities.items(),
            key=lambda item: item[1],
            reverse=True,
        )[:k]
    ]


def safe_div(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator else 0.0


if __name__ == "__main__":
    main()
