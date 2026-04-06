#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import random
import re
import subprocess
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import librosa
import numpy as np
import torch
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import GroupShuffleSplit
from torch import nn
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from tqdm import tqdm

DATASET_REPO_URL = "https://github.com/gveres/donateacry-corpus.git"
FILENAME_PATTERN = re.compile(
    r"^(?P<group>[0-9a-fA-F-]{36})-(?P<timestamp>\d+)-(?P<app_version>[\d.]+)-(?P<gender>[mf])-(?P<age>\d+)-(?P<reason>[a-z]+)\.wav$"
)
SOURCE_FOLDER_TO_LABEL = {
    "hungry": "Hungry",
    "tired": "Sleepy",
    "belly_pain": "Pain/Gas",
    "burping": "Pain/Gas",
    "discomfort": "Fussy",
}


@dataclass(frozen=True)
class SampleRecord:
    audio_path: str
    app_label: str
    raw_label: str
    group_id: str
    age_bucket: str
    gender: str
    source_folder: str


class MelDataset(Dataset):
    def __init__(
        self,
        records: list[SampleRecord],
        label_to_index: dict[str, int],
        *,
        sample_rate: int = 16000,
        duration_seconds: int = 7,
        n_mels: int = 128,
        target_frames: int = 128,
    ) -> None:
        self.records = records
        self.label_to_index = label_to_index
        self.sample_rate = sample_rate
        self.duration_seconds = duration_seconds
        self.n_mels = n_mels
        self.target_frames = target_frames

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        record = self.records[index]
        mel = load_log_mel(
            Path(record.audio_path),
            sample_rate=self.sample_rate,
            duration_seconds=self.duration_seconds,
            n_mels=self.n_mels,
            target_frames=self.target_frames,
        )
        label_index = self.label_to_index[record.app_label]
        return (
            torch.from_numpy(mel).unsqueeze(0),
            torch.tensor(label_index, dtype=torch.long),
        )


class BabyCryCNN(nn.Module):
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
            nn.MaxPool2d(2),
            nn.Conv2d(96, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.AdaptiveAvgPool2d((1, 1)),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.25),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(0.15),
            nn.Linear(64, num_classes),
        )

    def forward(self, inputs: torch.Tensor) -> torch.Tensor:
        return self.classifier(self.features(inputs))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a baby-cry CNN baseline.")
    parser.add_argument(
        "--workspace",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="Training workspace directory.",
    )
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--loss",
        choices=["cross_entropy", "focal"],
        default="cross_entropy",
    )
    parser.add_argument("--focal-gamma", type=float, default=1.5)
    parser.add_argument("--balanced-sampler", action="store_true")
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument("--train-ratio", type=float, default=0.7)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    assert round(args.train_ratio + args.val_ratio + args.test_ratio, 5) == 1.0
    set_seed(args.seed)

    data_root = args.workspace / "data"
    output_root = args.workspace / "outputs" / "latest"
    output_root.mkdir(parents=True, exist_ok=True)

    cleaned_root = ensure_dataset(data_root)
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

    labels = sorted({record.app_label for record in all_records})
    label_to_index = {label: index for index, label in enumerate(labels)}

    train_dataset = MelDataset(train_records, label_to_index)
    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=not args.balanced_sampler,
        sampler=build_balanced_sampler(train_records, label_to_index)
        if args.balanced_sampler
        else None,
        num_workers=0,
    )
    val_loader = DataLoader(
        MelDataset(val_records, label_to_index),
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
    )
    test_loader = DataLoader(
        MelDataset(test_records, label_to_index),
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
    )

    device = pick_device()
    model = BabyCryCNN(num_classes=len(labels)).to(device)
    class_weights = build_class_weights(train_records, label_to_index).to(device)
    criterion = build_criterion(
        loss_name=args.loss,
        class_weights=class_weights,
        gamma=args.focal_gamma,
    )
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)

    best_val_f1 = -1.0
    best_state: dict[str, torch.Tensor] | None = None
    history: list[dict[str, float]] = []

    for epoch in range(1, args.epochs + 1):
        train_loss = train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_metrics = evaluate(model, val_loader, device)
        val_metrics["train_loss"] = train_loss
        val_metrics["epoch"] = float(epoch)
        history.append(val_metrics)
        print(
            f"epoch={epoch} train_loss={train_loss:.4f} val_accuracy={val_metrics['accuracy']:.4f} "
            f"val_macro_f1={val_metrics['macro_f1']:.4f} val_top2={val_metrics['top2_accuracy']:.4f}"
        )

        if val_metrics["macro_f1"] > best_val_f1:
            best_val_f1 = val_metrics["macro_f1"]
            best_state = {
                key: value.detach().cpu().clone()
                for key, value in model.state_dict().items()
            }

    if best_state is None:
        raise RuntimeError("Training did not produce a valid checkpoint.")

    model.load_state_dict(best_state)
    test_metrics = evaluate(model, test_loader, device)

    torch.save(best_state, output_root / "model.pt")
    (output_root / "label_to_index.json").write_text(
        json.dumps(label_to_index, indent=2),
        encoding="utf-8",
    )
    metrics = {
        "dataset_repo": DATASET_REPO_URL,
        "device": str(device),
        "training_config": {
            "loss": args.loss,
            "focal_gamma": args.focal_gamma,
            "balanced_sampler": args.balanced_sampler,
        },
        "label_distribution": dict(Counter(record.app_label for record in all_records)),
        "split_sizes": {
            "train": len(train_records),
            "val": len(val_records),
            "test": len(test_records),
        },
        "train_groups": len({record.group_id for record in train_records}),
        "val_groups": len({record.group_id for record in val_records}),
        "test_groups": len({record.group_id for record in test_records}),
        "best_val_macro_f1": best_val_f1,
        "test_metrics": test_metrics,
        "history": history,
    }
    (output_root / "metrics.json").write_text(
        json.dumps(metrics, indent=2),
        encoding="utf-8",
    )

    write_manifest(output_root / "train_manifest.csv", train_records)
    write_manifest(output_root / "val_manifest.csv", val_records)
    write_manifest(output_root / "test_manifest.csv", test_records)

    print(json.dumps(metrics["test_metrics"], indent=2))


def ensure_dataset(data_root: Path) -> Path:
    repo_root = data_root / "donateacry-corpus"
    cleaned_root = repo_root / "donateacry_corpus_cleaned_and_updated_data"

    if cleaned_root.exists():
        return cleaned_root

    data_root.mkdir(parents=True, exist_ok=True)
    run_command([
        "git",
        "clone",
        "--depth",
        "1",
        DATASET_REPO_URL,
        str(repo_root),
    ])

    if not cleaned_root.exists():
        raise FileNotFoundError(
            "Expected cleaned WAV subset was not found in the downloaded dataset."
        )

    return cleaned_root


def collect_records(cleaned_root: Path) -> list[SampleRecord]:
    records: list[SampleRecord] = []
    for folder_name, app_label in SOURCE_FOLDER_TO_LABEL.items():
        folder = cleaned_root / folder_name
        for audio_path in sorted(folder.glob("*.wav")):
            match = FILENAME_PATTERN.match(audio_path.name)
            if match is None:
                continue
            records.append(
                SampleRecord(
                    audio_path=str(audio_path),
                    app_label=app_label,
                    raw_label=folder_name,
                    group_id=match.group("group"),
                    age_bucket=match.group("age"),
                    gender=match.group("gender"),
                    source_folder=folder_name,
                )
            )

    if not records:
        raise RuntimeError("No records were collected from the cleaned dataset.")

    return records


def balanced_subset(
    records: list[SampleRecord],
    max_samples: int,
    seed: int,
) -> list[SampleRecord]:
    if max_samples >= len(records):
        return records

    random.seed(seed)
    grouped: dict[str, list[SampleRecord]] = {}
    for record in records:
        grouped.setdefault(record.app_label, []).append(record)

    per_label = max(1, max_samples // len(grouped))
    subset: list[SampleRecord] = []
    for label_records in grouped.values():
        shuffled = label_records[:]
        random.shuffle(shuffled)
        subset.extend(shuffled[:per_label])

    random.shuffle(subset)
    return subset[:max_samples]


def split_records(
    records: list[SampleRecord],
    *,
    train_ratio: float,
    val_ratio: float,
    test_ratio: float,
    seed: int,
) -> tuple[list[SampleRecord], list[SampleRecord], list[SampleRecord]]:
    indices = np.arange(len(records))
    groups = np.array([record.group_id for record in records])
    labels = np.array([record.app_label for record in records])

    test_split = GroupShuffleSplit(n_splits=1, test_size=test_ratio, random_state=seed)
    train_val_indices, test_indices = next(test_split.split(indices, labels, groups))

    train_val_records = [records[index] for index in train_val_indices]
    test_records = [records[index] for index in test_indices]

    remaining_groups = np.array([record.group_id for record in train_val_records])
    remaining_labels = np.array([record.app_label for record in train_val_records])
    remaining_indices = np.arange(len(train_val_records))
    val_size = val_ratio / (train_ratio + val_ratio)
    val_split = GroupShuffleSplit(n_splits=1, test_size=val_size, random_state=seed)
    train_indices, val_indices = next(
        val_split.split(remaining_indices, remaining_labels, remaining_groups)
    )

    train_records = [train_val_records[index] for index in train_indices]
    val_records = [train_val_records[index] for index in val_indices]
    return train_records, val_records, test_records


def load_log_mel(
    audio_path: Path,
    *,
    sample_rate: int,
    duration_seconds: int,
    n_mels: int,
    target_frames: int,
) -> np.ndarray:
    signal, _ = librosa.load(
        audio_path,
        sr=sample_rate,
        mono=True,
        duration=duration_seconds,
    )
    target_length = sample_rate * duration_seconds
    if signal.shape[0] < target_length:
        signal = np.pad(signal, (0, target_length - signal.shape[0]))
    else:
        signal = signal[:target_length]

    mel = librosa.feature.melspectrogram(
        y=signal,
        sr=sample_rate,
        n_fft=1024,
        hop_length=256,
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
    records: list[SampleRecord],
    label_to_index: dict[str, int],
) -> torch.Tensor:
    counts = Counter(record.app_label for record in records)
    total = sum(counts.values())
    weights = []
    for label, index in sorted(label_to_index.items(), key=lambda item: item[1]):
        count = counts[label]
        weights.append(total / (len(label_to_index) * count))
    return torch.tensor(weights, dtype=torch.float32)


def build_balanced_sampler(
    records: list[SampleRecord],
    label_to_index: dict[str, int],
) -> WeightedRandomSampler:
    counts = Counter(record.app_label for record in records)
    sample_weights = [1.0 / counts[record.app_label] for record in records]
    return WeightedRandomSampler(
        weights=torch.DoubleTensor(sample_weights),
        num_samples=len(records),
        replacement=True,
    )


def build_criterion(
    *,
    loss_name: str,
    class_weights: torch.Tensor,
    gamma: float,
) -> nn.Module:
    if loss_name == "focal":
        return FocalLoss(class_weights=class_weights, gamma=gamma)
    return nn.CrossEntropyLoss(weight=class_weights)


class FocalLoss(nn.Module):
    def __init__(self, *, class_weights: torch.Tensor, gamma: float) -> None:
        super().__init__()
        self.register_buffer("class_weights", class_weights)
        self.gamma = gamma

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        ce = nn.functional.cross_entropy(
            logits,
            targets,
            reduction="none",
            weight=self.class_weights,
        )
        pt = torch.exp(-ce)
        loss = ((1 - pt) ** self.gamma) * ce
        return loss.mean()


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
        optimizer.zero_grad(set_to_none=True)
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


def write_manifest(output_path: Path, records: list[SampleRecord]) -> None:
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "audio_path",
                "app_label",
                "raw_label",
                "group_id",
                "age_bucket",
                "gender",
                "source_folder",
            ]
        )
        for record in records:
            writer.writerow(
                [
                    record.audio_path,
                    record.app_label,
                    record.raw_label,
                    record.group_id,
                    record.age_bucket,
                    record.gender,
                    record.source_folder,
                ]
            )


def pick_device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def run_command(command: list[str]) -> None:
    print(" ".join(command))
    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
