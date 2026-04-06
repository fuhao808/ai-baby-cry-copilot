#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import librosa
import numpy as np
import onnx
import torch
from sklearn.metrics import accuracy_score, f1_score
from torch import nn
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from tqdm import tqdm

PATTERN_LABELS = ["neh", "owh", "eairh", "heh"]
CLASS_TO_PATTERN = {
    "Hungry": "neh",
    "Sleepy": "owh",
    "Pain/Gas": "eairh",
    "Fussy": "heh",
}


@dataclass(frozen=True)
class PatternRecord:
    audio_path: str
    app_label: str
    pattern_label: str
    group_id: str


class PatternMelDataset(Dataset):
    def __init__(
        self,
        records: list[PatternRecord],
        label_to_index: dict[str, int],
        *,
        sample_rate: int = 16_000,
        clip_seconds: float = 1.0,
        n_mels: int = 64,
        target_frames: int = 96,
        train_mode: bool = False,
    ) -> None:
        self.records = records
        self.label_to_index = label_to_index
        self.sample_rate = sample_rate
        self.clip_seconds = clip_seconds
        self.n_mels = n_mels
        self.target_frames = target_frames
        self.train_mode = train_mode

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        record = self.records[index]
        mel = load_pattern_mel(
            Path(record.audio_path),
            sample_rate=self.sample_rate,
            clip_seconds=self.clip_seconds,
            n_mels=self.n_mels,
            target_frames=self.target_frames,
            jitter_seconds=0.12 if self.train_mode else 0.0,
        )
        target = self.label_to_index[record.pattern_label]
        return (
            torch.from_numpy(mel).unsqueeze(0),
            torch.tensor(target, dtype=torch.long),
        )


class PatternCNN(nn.Module):
    def __init__(self, num_classes: int) -> None:
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 24, kernel_size=3, padding=1),
            nn.BatchNorm2d(24),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(24, 48, kernel_size=3, padding=1),
            nn.BatchNorm2d(48),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(48, 96, kernel_size=3, padding=1),
            nn.BatchNorm2d(96),
            nn.ReLU(),
            nn.AdaptiveAvgPool2d((1, 1)),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.2),
            nn.Linear(96, 48),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(48, num_classes),
        )

    def forward(self, inputs: torch.Tensor) -> torch.Tensor:
        return self.classifier(self.features(inputs))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--workspace",
        type=Path,
        default=Path(__file__).resolve().parent,
    )
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--learning-rate", type=float, default=8e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--export-backend-artifacts", action="store_true")
    parser.add_argument("--skip-onnx-export", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    set_seed(args.seed)

    latest_root = args.workspace / "outputs" / "latest"
    output_root = args.workspace / "outputs" / "pattern_latest"
    output_root.mkdir(parents=True, exist_ok=True)

    train_records = load_records(latest_root / "train_manifest.csv")
    val_records = load_records(latest_root / "val_manifest.csv")
    test_records = load_records(latest_root / "test_manifest.csv")

    label_to_index = {label: idx for idx, label in enumerate(PATTERN_LABELS)}
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    train_dataset = PatternMelDataset(
        train_records,
        label_to_index,
        train_mode=True,
    )
    val_dataset = PatternMelDataset(val_records, label_to_index)
    test_dataset = PatternMelDataset(test_records, label_to_index)

    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        sampler=build_balanced_sampler(train_records, label_to_index),
        num_workers=0,
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
    )
    test_loader = DataLoader(
        test_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
    )

    model = PatternCNN(num_classes=len(PATTERN_LABELS)).to(device)
    class_weights = build_class_weights(train_records, label_to_index).to(device)
    criterion = nn.CrossEntropyLoss(weight=class_weights)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)

    best_state = None
    best_val_f1 = -1.0
    history: list[dict[str, float]] = []

    for epoch in range(1, args.epochs + 1):
        train_loss = train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_metrics = evaluate(model, val_loader, device)
        val_metrics["train_loss"] = train_loss
        val_metrics["epoch"] = epoch
        history.append(val_metrics)
        print(
            f"epoch={epoch} train_loss={train_loss:.4f} "
            f"val_accuracy={val_metrics['accuracy']:.4f} "
            f"val_macro_f1={val_metrics['macro_f1']:.4f}"
        )
        if val_metrics["macro_f1"] > best_val_f1:
            best_val_f1 = val_metrics["macro_f1"]
            best_state = {k: v.detach().cpu() for k, v in model.state_dict().items()}

    if best_state is None:
        raise RuntimeError("Pattern detector training did not produce a checkpoint.")

    model.load_state_dict(best_state)
    test_metrics = evaluate(model, test_loader, device)

    metrics = {
        "pattern_label_mapping": CLASS_TO_PATTERN,
        "device": str(device),
        "split_sizes": {
            "train": len(train_records),
            "val": len(val_records),
            "test": len(test_records),
        },
        "label_distribution": dict(
            Counter(record.pattern_label for record in train_records + val_records + test_records)
        ),
        "best_val_macro_f1": best_val_f1,
        "test_metrics": test_metrics,
        "history": history,
        "notes": [
            "Pattern labels are proxy labels derived from app class labels.",
            "This detector is a short-window cue model, not a hand-labeled DBL benchmark.",
        ],
    }
    (output_root / "metrics.json").write_text(
        json.dumps(metrics, indent=2),
        encoding="utf-8",
    )
    (output_root / "label_to_index.json").write_text(
        json.dumps(label_to_index, indent=2),
        encoding="utf-8",
    )
    torch.save(best_state, output_root / "model.pt")
    write_manifest(output_root / "train_manifest.csv", train_records)
    write_manifest(output_root / "val_manifest.csv", val_records)
    write_manifest(output_root / "test_manifest.csv", test_records)

    if not args.skip_onnx_export:
        export_onnx(model, output_root / "pattern_detector.onnx", device)

    if args.export_backend_artifacts:
        export_backend_artifacts(output_root)

    print(json.dumps(metrics["test_metrics"], indent=2))


def load_records(path: Path) -> list[PatternRecord]:
    rows = csv.DictReader(path.open())
    records: list[PatternRecord] = []
    for row in rows:
        app_label = row["app_label"]
        pattern_label = CLASS_TO_PATTERN.get(app_label)
        if pattern_label is None:
            continue
        records.append(
            PatternRecord(
                audio_path=row["audio_path"],
                app_label=app_label,
                pattern_label=pattern_label,
                group_id=row["group_id"],
            )
        )
    return records


def load_pattern_mel(
    audio_path: Path,
    *,
    sample_rate: int,
    clip_seconds: float,
    n_mels: int,
    target_frames: int,
    jitter_seconds: float = 0.0,
) -> np.ndarray:
    signal, _ = librosa.load(audio_path, sr=sample_rate, mono=True, duration=7)
    if signal.size == 0:
        signal = np.zeros(int(sample_rate * clip_seconds), dtype=np.float32)
    hop_length = 160
    onset = librosa.onset.onset_strength(y=signal, sr=sample_rate, hop_length=hop_length)
    onset_frame = int(np.argmax(onset)) if onset.size else 0
    center_sample = onset_frame * hop_length
    window_samples = int(sample_rate * clip_seconds)
    if jitter_seconds > 0:
        max_jitter = int(sample_rate * jitter_seconds)
        center_sample += int(np.random.randint(-max_jitter, max_jitter + 1))
        center_sample = int(np.clip(center_sample, 0, max(signal.shape[0] - 1, 0)))
    start = max(0, center_sample - (window_samples // 2))
    end = start + window_samples
    if end > signal.shape[0]:
        end = signal.shape[0]
        start = max(0, end - window_samples)
    window = signal[start:end]
    if window.shape[0] < window_samples:
        window = np.pad(window, (0, window_samples - window.shape[0]))

    mel = librosa.feature.melspectrogram(
        y=window,
        sr=sample_rate,
        n_fft=512,
        hop_length=hop_length,
        n_mels=n_mels,
    )
    mel = librosa.power_to_db(mel, ref=np.max)
    mel = (mel - mel.mean()) / (mel.std() + 1e-6)
    if mel.shape[1] < target_frames:
        mel = np.pad(mel, ((0, 0), (0, target_frames - mel.shape[1])))
    else:
        mel = mel[:, :target_frames]
    return mel.astype(np.float32)


def build_class_weights(
    records: list[PatternRecord],
    label_to_index: dict[str, int],
) -> torch.Tensor:
    counts = Counter(record.pattern_label for record in records)
    total = sum(counts.values())
    weights = []
    for label in sorted(label_to_index, key=label_to_index.get):
        count = counts[label]
        weights.append(total / (len(label_to_index) * count))
    return torch.tensor(weights, dtype=torch.float32)


def build_balanced_sampler(
    records: list[PatternRecord],
    label_to_index: dict[str, int],
) -> WeightedRandomSampler:
    counts = Counter(record.pattern_label for record in records)
    sample_weights = [
        1.0 / counts[record.pattern_label]
        for record in records
    ]
    return WeightedRandomSampler(
        weights=torch.DoubleTensor(sample_weights),
        num_samples=len(records),
        replacement=True,
    )


def train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: torch.optim.Optimizer,
    device: torch.device,
) -> float:
    model.train()
    losses: list[float] = []
    for features, targets in tqdm(loader, desc="train", leave=False):
        features = features.to(device)
        targets = targets.to(device)
        optimizer.zero_grad()
        logits = model(features)
        loss = criterion(logits, targets)
        loss.backward()
        optimizer.step()
        losses.append(float(loss.item()))
    return float(np.mean(losses)) if losses else 0.0


@torch.no_grad()
def evaluate(
    model: nn.Module,
    loader: DataLoader,
    device: torch.device,
) -> dict[str, float]:
    model.eval()
    all_targets: list[int] = []
    all_predictions: list[int] = []
    all_top2_hits: list[int] = []

    for features, targets in tqdm(loader, desc="eval", leave=False):
        features = features.to(device)
        logits = model(features)
        probabilities = torch.softmax(logits, dim=1)
        predictions = probabilities.argmax(dim=1).cpu().tolist()
        top2 = probabilities.topk(k=min(2, probabilities.shape[1]), dim=1).indices.cpu()
        target_list = targets.tolist()

        all_targets.extend(target_list)
        all_predictions.extend(predictions)
        for index, target in enumerate(target_list):
            all_top2_hits.append(int(target in top2[index].tolist()))

    return {
        "accuracy": float(accuracy_score(all_targets, all_predictions)),
        "macro_f1": float(f1_score(all_targets, all_predictions, average="macro")),
        "top2_accuracy": float(np.mean(all_top2_hits)),
    }


def export_onnx(model: nn.Module, output_path: Path, device: torch.device) -> None:
    model = model.to(device)
    model.eval()
    dummy = torch.randn(1, 1, 64, 96, device=device)
    torch.onnx.export(
        model,
        dummy,
        output_path,
        input_names=["input"],
        output_names=["logits"],
        dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}},
        opset_version=17,
    )
    onnx.checker.check_model(str(output_path))


def export_backend_artifacts(output_root: Path) -> None:
    backend_dir = output_root.parents[2] / "backend" / "model_artifacts"
    backend_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(output_root / "pattern_detector.onnx", backend_dir / "baby_cry_pattern.onnx")
    shutil.copy2(output_root / "label_to_index.json", backend_dir / "baby_cry_pattern_label_to_index.json")


def write_manifest(path: Path, records: list[PatternRecord]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["audio_path", "app_label", "pattern_label", "group_id"])
        for record in records:
            writer.writerow(
                [
                    record.audio_path,
                    record.app_label,
                    record.pattern_label,
                    record.group_id,
                ]
            )


def set_seed(seed: int) -> None:
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


if __name__ == "__main__":
    main()
