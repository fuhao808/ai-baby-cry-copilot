#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import Dataset
from transformers import (
    AutoFeatureExtractor,
    AutoModelForAudioClassification,
    Trainer,
    TrainingArguments,
)

from run_audio_model_bakeoff import MODEL_REGISTRY, load_waveform
from train_baseline import (
    SampleRecord,
    balanced_subset,
    build_class_weights,
    collect_records,
    ensure_dataset,
    pick_device,
    set_seed,
    split_records,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fine-tune a pretrained audio model on Donate-a-Cry."
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="Training workspace directory.",
    )
    parser.add_argument(
        "--model",
        default="ast",
        choices=sorted(MODEL_REGISTRY.keys()),
        help="Model registry key to fine-tune.",
    )
    parser.add_argument("--epochs", type=float, default=3.0)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--learning-rate", type=float, default=2e-5)
    parser.add_argument("--warmup-ratio", type=float, default=0.1)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument("--sample-rate", type=int, default=16000)
    parser.add_argument("--duration-seconds", type=int, default=7)
    parser.add_argument("--train-ratio", type=float, default=0.7)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Override output directory. Defaults to training/outputs/finetune/<model>/latest.",
    )
    parser.add_argument(
        "--skip-save-model",
        action="store_true",
        help="Run training and evaluation without saving checkpoints or the final model.",
    )
    return parser.parse_args()


class HFAudioDataset(Dataset):
    def __init__(
        self,
        records: list[SampleRecord],
        feature_extractor,
        label_to_index: dict[str, int],
        *,
        sample_rate: int,
        duration_seconds: int,
    ) -> None:
        self.records = records
        self.feature_extractor = feature_extractor
        self.label_to_index = label_to_index
        self.sample_rate = sample_rate
        self.duration_seconds = duration_seconds
        self.target_length = sample_rate * duration_seconds

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> dict[str, torch.Tensor]:
        record = self.records[index]
        waveform = load_waveform(
            Path(record.audio_path),
            sample_rate=self.sample_rate,
            duration_seconds=self.duration_seconds,
            target_length=self.target_length,
        )
        encoded = self.feature_extractor(
            waveform,
            sampling_rate=self.sample_rate,
            return_tensors="pt",
            padding=False,
        )
        item = {key: value.squeeze(0) for key, value in encoded.items()}
        item["labels"] = torch.tensor(
            self.label_to_index[record.app_label],
            dtype=torch.long,
        )
        return item


class AudioDataCollator:
    def __init__(self, feature_extractor) -> None:
        self.feature_extractor = feature_extractor

    def __call__(self, features: list[dict[str, torch.Tensor]]) -> dict[str, torch.Tensor]:
        labels = torch.tensor([feature["labels"] for feature in features], dtype=torch.long)
        feature_dicts = [{k: v for k, v in feature.items() if k != "labels"} for feature in features]
        batch = self.feature_extractor.pad(feature_dicts, return_tensors="pt")
        batch["labels"] = labels
        return batch


class WeightedAudioTrainer(Trainer):
    def __init__(self, class_weights: torch.Tensor | None = None, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.class_weights = class_weights

    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        labels = inputs.pop("labels")
        outputs = model(**inputs)
        logits = outputs.logits
        loss_fct = nn.CrossEntropyLoss(
            weight=self.class_weights.to(logits.device) if self.class_weights is not None else None
        )
        loss = loss_fct(logits.view(-1, model.config.num_labels), labels.view(-1))
        return (loss, outputs) if return_outputs else loss


def compute_metrics(eval_pred):
    from sklearn.metrics import accuracy_score, balanced_accuracy_score, f1_score
    import numpy as np

    logits, labels = eval_pred
    probabilities = torch.softmax(torch.tensor(logits), dim=-1).numpy()
    predictions = probabilities.argmax(axis=1)
    top2 = np.argsort(probabilities, axis=1)[:, -2:]
    top2_hits = [int(target in row) for target, row in zip(labels, top2)]
    return {
        "accuracy": float(accuracy_score(labels, predictions)),
        "balanced_accuracy": float(balanced_accuracy_score(labels, predictions)),
        "macro_f1": float(f1_score(labels, predictions, average="macro")),
        "top2_accuracy": float(np.mean(top2_hits)),
    }


def main() -> None:
    args = parse_args()
    assert round(args.train_ratio + args.val_ratio + args.test_ratio, 5) == 1.0
    set_seed(args.seed)

    workspace = args.workspace.resolve()
    output_dir = (
        args.output_dir.resolve()
        if args.output_dir is not None
        else workspace / "outputs" / "finetune" / args.model / "latest"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

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
    labels = sorted({record.app_label for record in all_records})
    label_to_index = {label: index for index, label in enumerate(labels)}
    index_to_label = {index: label for label, index in label_to_index.items()}

    model_id = MODEL_REGISTRY[args.model]["hf_id"]
    feature_extractor = AutoFeatureExtractor.from_pretrained(model_id)
    model = AutoModelForAudioClassification.from_pretrained(
        model_id,
        num_labels=len(labels),
        label2id=label_to_index,
        id2label=index_to_label,
        ignore_mismatched_sizes=True,
    )

    train_dataset = HFAudioDataset(
        train_records,
        feature_extractor,
        label_to_index,
        sample_rate=args.sample_rate,
        duration_seconds=args.duration_seconds,
    )
    val_dataset = HFAudioDataset(
        val_records,
        feature_extractor,
        label_to_index,
        sample_rate=args.sample_rate,
        duration_seconds=args.duration_seconds,
    )
    test_dataset = HFAudioDataset(
        test_records,
        feature_extractor,
        label_to_index,
        sample_rate=args.sample_rate,
        duration_seconds=args.duration_seconds,
    )

    class_weights = build_class_weights(train_records, label_to_index)
    training_args = TrainingArguments(
        output_dir=str(output_dir),
        do_train=True,
        do_eval=True,
        eval_strategy="epoch",
        save_strategy="no" if args.skip_save_model else "epoch",
        logging_strategy="steps",
        logging_steps=5,
        learning_rate=args.learning_rate,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        num_train_epochs=args.epochs,
        warmup_ratio=args.warmup_ratio,
        load_best_model_at_end=not args.skip_save_model,
        metric_for_best_model="macro_f1",
        greater_is_better=True,
        report_to="none",
        save_total_limit=2,
        fp16=torch.cuda.is_available(),
        remove_unused_columns=False,
        seed=args.seed,
        data_seed=args.seed,
    )

    trainer = WeightedAudioTrainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        data_collator=AudioDataCollator(feature_extractor),
        compute_metrics=compute_metrics,
        class_weights=class_weights,
    )

    trainer.train()
    val_metrics = trainer.evaluate(val_dataset)
    test_metrics = trainer.evaluate(test_dataset, metric_key_prefix="test")

    summary = {
        "dataset": "Donate-a-Cry",
        "model_key": args.model,
        "model_id": model_id,
        "sample_rate": args.sample_rate,
        "duration_seconds": args.duration_seconds,
        "split_sizes": {
            "train": len(train_records),
            "val": len(val_records),
            "test": len(test_records),
        },
        "labels": labels,
        "device_hint": str(pick_device()),
        "skip_save_model": args.skip_save_model,
        "val_metrics": val_metrics,
        "test_metrics": test_metrics,
    }
    (output_dir / "final_metrics.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )
    if not args.skip_save_model:
        trainer.save_model(str(output_dir / "best_model"))
        feature_extractor.save_pretrained(str(output_dir / "best_model"))
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
