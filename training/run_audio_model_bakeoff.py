#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import librosa
import numpy as np
import torch
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, balanced_accuracy_score, f1_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from tqdm import tqdm
from transformers import AutoFeatureExtractor, AutoModel

from train_baseline import (
    SampleRecord,
    balanced_subset,
    collect_records,
    ensure_dataset,
    pick_device,
    set_seed,
    split_records,
)

MODEL_REGISTRY = {
    "ast": {
        "hf_id": "MIT/ast-finetuned-audioset-10-10-0.4593",
        "family": "spectrogram-transformer",
        "notes": "Strong broad-audio transformer baseline for non-linguistic acoustic events.",
    },
    "beats": {
        "hf_id": "microsoft/beats-base",
        "family": "general-audio-ssl",
        "notes": "General audio SSL model trained with acoustic token prediction.",
    },
    "wavlm": {
        "hf_id": "microsoft/wavlm-base-plus",
        "family": "speech-ssl",
        "notes": "Strong speech SSL model that often transfers well to paralinguistic tasks.",
    },
    "wav2vec2": {
        "hf_id": "facebook/wav2vec2-base",
        "family": "speech-ssl",
        "notes": "Older but useful speech SSL transfer baseline.",
    },
}


@dataclass(frozen=True)
class SplitBundle:
    train: list[SampleRecord]
    val: list[SampleRecord]
    test: list[SampleRecord]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare pretrained audio encoders on Donate-a-Cry using frozen embedding probes."
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="Training workspace directory.",
    )
    parser.add_argument(
        "--models",
        default="ast,beats,wavlm,wav2vec2",
        help="Comma-separated model keys to compare.",
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument("--duration-seconds", type=int, default=7)
    parser.add_argument("--sample-rate", type=int, default=16000)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--train-ratio", type=float, default=0.7)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Override output directory. Defaults to training/outputs/bakeoff/latest.",
    )
    parser.add_argument(
        "--cache-embeddings",
        action="store_true",
        help="Cache extracted embeddings to disk to avoid recomputing them between runs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    assert round(args.train_ratio + args.val_ratio + args.test_ratio, 5) == 1.0
    set_seed(args.seed)

    workspace = args.workspace.resolve()
    output_root = (
        args.output_dir.resolve()
        if args.output_dir is not None
        else workspace / "outputs" / "bakeoff" / "latest"
    )
    output_root.mkdir(parents=True, exist_ok=True)

    model_keys = [key.strip() for key in args.models.split(",") if key.strip()]
    unknown = [key for key in model_keys if key not in MODEL_REGISTRY]
    if unknown:
        raise ValueError(f"Unknown model keys: {unknown}")

    cleaned_root = ensure_dataset(workspace / "data")
    all_records = collect_records(cleaned_root)
    if args.max_samples > 0:
        all_records = balanced_subset(all_records, args.max_samples, args.seed)

    train_records, val_records, test_records = split_records(
        all_records,
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        test_ratio=args.test_ratio,
        seed=args.seed,
    )
    splits = SplitBundle(train=train_records, val=val_records, test=test_records)
    labels = sorted({record.app_label for record in all_records})
    label_to_index = {label: index for index, label in enumerate(labels)}

    device = pick_device()
    summary = {
        "dataset": "Donate-a-Cry",
        "sample_rate": args.sample_rate,
        "duration_seconds": args.duration_seconds,
        "split_sizes": {
            "train": len(train_records),
            "val": len(val_records),
            "test": len(test_records),
        },
        "labels": labels,
        "device": str(device),
        "models": [],
    }

    cnn_baseline_path = workspace / "outputs" / "latest" / "metrics.json"
    if cnn_baseline_path.exists():
        cnn_metrics = json.loads(cnn_baseline_path.read_text(encoding="utf-8"))
        summary["cnn_baseline"] = {
            "model": "cnn_logmel_baseline",
            "family": "cnn",
            "test_metrics": cnn_metrics.get("test_metrics", {}),
            "best_val_macro_f1": cnn_metrics.get("best_val_macro_f1"),
        }

    embedding_cache_dir = output_root / "embedding_cache"
    if args.cache_embeddings:
        embedding_cache_dir.mkdir(parents=True, exist_ok=True)

    for model_key in model_keys:
        config = MODEL_REGISTRY[model_key]
        model_output_dir = output_root / model_key
        model_output_dir.mkdir(parents=True, exist_ok=True)
        try:
            model, feature_extractor = load_hf_model(config["hf_id"], device)

            split_embeddings: dict[str, np.ndarray] = {}
            split_targets: dict[str, np.ndarray] = {}

            for split_name, split_records_current in {
                "train": splits.train,
                "val": splits.val,
                "test": splits.test,
            }.items():
                cache_path = embedding_cache_dir / f"{model_key}_{split_name}.npz"
                if args.cache_embeddings and cache_path.exists():
                    payload = np.load(cache_path)
                    split_embeddings[split_name] = payload["embeddings"]
                    split_targets[split_name] = payload["targets"]
                    continue

                embeddings, targets = extract_embeddings(
                    model=model,
                    feature_extractor=feature_extractor,
                    records=split_records_current,
                    label_to_index=label_to_index,
                    device=device,
                    sample_rate=args.sample_rate,
                    duration_seconds=args.duration_seconds,
                    batch_size=args.batch_size,
                )
                split_embeddings[split_name] = embeddings
                split_targets[split_name] = targets

                if args.cache_embeddings:
                    np.savez_compressed(
                        cache_path,
                        embeddings=embeddings,
                        targets=targets,
                    )

            probe = build_probe()
            probe.fit(split_embeddings["train"], split_targets["train"])
            val_metrics = evaluate_probe(
                probe,
                split_embeddings["val"],
                split_targets["val"],
            )
            test_metrics = evaluate_probe(
                probe,
                split_embeddings["test"],
                split_targets["test"],
            )
            result = {
                "model": model_key,
                "hf_id": config["hf_id"],
                "family": config["family"],
                "notes": config["notes"],
                "val_metrics": val_metrics,
                "test_metrics": test_metrics,
            }
        except Exception as error:
            result = {
                "model": model_key,
                "hf_id": config["hf_id"],
                "family": config["family"],
                "notes": config["notes"],
                "error": str(error),
            }
        summary["models"].append(result)
        (model_output_dir / "metrics.json").write_text(
            json.dumps(result, indent=2),
            encoding="utf-8",
        )

    summary["models"].sort(
        key=lambda row: (
            row.get("val_metrics", {}).get("macro_f1", -1.0),
            row.get("test_metrics", {}).get("macro_f1", -1.0),
        ),
        reverse=True,
    )
    summary["recommended_next_finetune"] = (
        next(
            (
                row["model"]
                for row in summary["models"]
                if row.get("val_metrics") is not None
            ),
            None,
        )
    )
    (output_root / "summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))


def load_hf_model(model_id: str, device: torch.device):
    feature_extractor = AutoFeatureExtractor.from_pretrained(model_id)
    model = AutoModel.from_pretrained(model_id)
    model.to(device)
    model.eval()
    return model, feature_extractor


def extract_embeddings(
    *,
    model,
    feature_extractor,
    records: list[SampleRecord],
    label_to_index: dict[str, int],
    device: torch.device,
    sample_rate: int,
    duration_seconds: int,
    batch_size: int,
) -> tuple[np.ndarray, np.ndarray]:
    target_length = sample_rate * duration_seconds
    embeddings: list[np.ndarray] = []
    targets: list[int] = []

    for batch_start in tqdm(
        range(0, len(records), batch_size),
        desc=f"embed:{getattr(model.config, 'model_type', 'audio')}",
        leave=False,
    ):
        batch = records[batch_start : batch_start + batch_size]
        waveforms = [
            load_waveform(
                Path(record.audio_path),
                sample_rate=sample_rate,
                duration_seconds=duration_seconds,
                target_length=target_length,
            )
            for record in batch
        ]
        features = feature_extractor(
            waveforms,
            sampling_rate=sample_rate,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=target_length,
        )
        features = {
            key: value.to(device)
            for key, value in features.items()
            if isinstance(value, torch.Tensor)
        }

        with torch.no_grad():
            outputs = model(**features)

        batch_embeddings = pool_output(outputs, features.get("attention_mask"))
        embeddings.append(batch_embeddings.cpu().numpy())
        targets.extend(label_to_index[record.app_label] for record in batch)

    return np.concatenate(embeddings, axis=0), np.asarray(targets, dtype=np.int64)


def load_waveform(
    audio_path: Path,
    *,
    sample_rate: int,
    duration_seconds: int,
    target_length: int,
) -> np.ndarray:
    waveform, _ = librosa.load(
        audio_path,
        sr=sample_rate,
        mono=True,
        duration=duration_seconds,
    )
    if waveform.shape[0] < target_length:
        waveform = np.pad(waveform, (0, target_length - waveform.shape[0]))
    else:
        waveform = waveform[:target_length]
    return waveform.astype(np.float32)


def pool_output(outputs, attention_mask: torch.Tensor | None) -> torch.Tensor:
    if getattr(outputs, "pooler_output", None) is not None:
        return outputs.pooler_output

    if getattr(outputs, "last_hidden_state", None) is not None:
        hidden = outputs.last_hidden_state
        if (
            attention_mask is None
            or attention_mask.ndim != 2
            or attention_mask.shape[1] != hidden.shape[1]
        ):
            return hidden.mean(dim=1)
        weights = attention_mask.unsqueeze(-1).to(hidden.dtype)
        return (hidden * weights).sum(dim=1) / weights.sum(dim=1).clamp(min=1.0)

    if getattr(outputs, "extract_features", None) is not None:
        features = outputs.extract_features
        return features.mean(dim=1)

    if isinstance(outputs, tuple) and outputs:
        return outputs[0].mean(dim=1)

    raise RuntimeError("Unsupported model output for embedding extraction.")


def build_probe() -> Pipeline:
    return Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            (
                "classifier",
                LogisticRegression(
                    max_iter=5000,
                    class_weight="balanced",
                    random_state=42,
                ),
            ),
        ]
    )


def evaluate_probe(
    probe: Pipeline,
    features: np.ndarray,
    targets: np.ndarray,
) -> dict[str, float]:
    probabilities = probe.predict_proba(features)
    predictions = probabilities.argmax(axis=1)
    top2 = np.argsort(probabilities, axis=1)[:, -2:]
    top2_hits = [int(target in row) for target, row in zip(targets, top2)]
    return {
        "accuracy": float(accuracy_score(targets, predictions)),
        "balanced_accuracy": float(balanced_accuracy_score(targets, predictions)),
        "macro_f1": float(f1_score(targets, predictions, average="macro")),
        "top2_accuracy": float(np.mean(top2_hits)),
    }


if __name__ == "__main__":
    main()
