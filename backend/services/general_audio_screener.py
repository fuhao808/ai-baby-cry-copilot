from __future__ import annotations

import csv
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import librosa
import numpy as np

try:
    import tensorflow as tf
    import tensorflow_hub as hub
except ImportError:  # pragma: no cover
    tf = None
    hub = None

YAMNET_HANDLE = "https://tfhub.dev/google/yamnet/1"


@dataclass(frozen=True)
class GeneralAudioScreening:
    available: bool
    provider: str
    coarse_label: str | None
    coarse_confidence: float
    top_label: str | None
    top_score: float
    top_labels: list[tuple[str, float]]


def screen_general_audio(file_path: Path) -> GeneralAudioScreening | None:
    bundle = _load_yamnet_bundle()
    if bundle is None:
        return None

    model, class_names = bundle
    waveform, _ = librosa.load(file_path, sr=16_000, mono=True)
    if waveform.size == 0:
        return GeneralAudioScreening(
            available=True,
            provider="yamnet",
            coarse_label="Unclear Audio",
            coarse_confidence=0.0,
            top_label=None,
            top_score=0.0,
            top_labels=[],
        )

    scores, _, _ = model(waveform.astype(np.float32))
    mean_scores = np.asarray(scores).mean(axis=0)
    top_indices = np.argsort(mean_scores)[::-1][:8]
    ranked = [
        (class_names[index], float(mean_scores[index]))
        for index in top_indices
    ]

    coarse_scores: dict[str, float] = {}
    for label, score in ranked:
        coarse = _map_yamnet_label(label)
        if coarse is None:
            continue
        coarse_scores[coarse] = coarse_scores.get(coarse, 0.0) + score

    if not coarse_scores:
        return GeneralAudioScreening(
            available=True,
            provider="yamnet",
            coarse_label=None,
            coarse_confidence=0.0,
            top_label=ranked[0][0] if ranked else None,
            top_score=ranked[0][1] if ranked else 0.0,
            top_labels=ranked,
        )

    coarse_label = max(coarse_scores, key=coarse_scores.get)
    coarse_confidence = float(coarse_scores[coarse_label])
    return GeneralAudioScreening(
        available=True,
        provider="yamnet",
        coarse_label=coarse_label,
        coarse_confidence=coarse_confidence,
        top_label=ranked[0][0] if ranked else None,
        top_score=ranked[0][1] if ranked else 0.0,
        top_labels=ranked,
    )


@lru_cache(maxsize=1)
def _load_yamnet_bundle():
    if tf is None or hub is None:
        return None
    model = hub.load(YAMNET_HANDLE)
    class_map_path = model.class_map_path().numpy().decode("utf-8")
    class_names = _load_class_names(Path(class_map_path))
    return model, class_names


def _load_class_names(class_map_path: Path) -> list[str]:
    with class_map_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return [row["display_name"] for row in reader]


def _map_yamnet_label(label: str) -> str | None:
    lowered = label.lower()

    if any(
        token in lowered
        for token in [
            "speech",
            "conversation",
            "narration",
            "male voice",
            "female voice",
            "inside, small room",
        ]
    ):
        return "Adult Voice"

    if any(
        token in lowered
        for token in [
            "tap",
            "knock",
            "hammer",
            "wood block",
            "percussion",
            "clatter",
            "slam",
            "thump",
        ]
    ):
        return "Impact / Knock"

    if any(
        token in lowered
        for token in [
            "baby cry",
            "crying",
            "sobbing",
            "whimper",
            "babbling",
            "coo",
            "giggle",
            "laughter",
        ]
    ):
        return "Infant Vocalization"

    if any(
        token in lowered
        for token in [
            "silence",
            "inside, quiet room",
            "rustle",
            "breathing",
            "noise",
            "static",
            "engine",
            "air conditioning",
            "white noise",
            "television",
            "music",
        ]
    ):
        return "Background Noise"

    return None
