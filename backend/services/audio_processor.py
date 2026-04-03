from __future__ import annotations

import hashlib
import random
import time
from dataclasses import dataclass
import json
from functools import lru_cache
from pathlib import Path

import librosa
import numpy as np

try:
    import torch
    from torch import nn
except ImportError:  # pragma: no cover - runtime fallback when torch is unavailable
    torch = None
    nn = None

CRY_LABELS = ["Hungry", "Sleepy", "Pain/Gas", "Fussy"]
INFANT_VOICE_LABELS = ["Excited", "Seeking Attention", "Content/Playful"]
NON_BABY_LABELS = ["Adult Voice", "Impact / Knock", "Background Noise", "Unclear Audio"]
MODEL_ARTIFACTS_DIR = Path(__file__).resolve().parents[1] / "model_artifacts"
MODEL_STATE_PATH = MODEL_ARTIFACTS_DIR / "baby_cry_cnn_state.pt"
MODEL_LABELS_PATH = MODEL_ARTIFACTS_DIR / "baby_cry_label_to_index.json"


@dataclass(frozen=True)
class AudioFeatures:
    rms_mean: float
    rms_peak: float
    zero_crossing_mean: float
    spectral_centroid_mean: float
    onset_mean: float
    onset_peak: float
    transient_ratio: float
    voiced_ratio: float
    pitch_median: float
    pitch_std: float
    burst_ratio: float
    dynamic_range: float


class BabyCryCNN(nn.Module if nn is not None else object):
    def __init__(self, num_classes: int) -> None:
        if nn is None:
            raise RuntimeError("torch is required to initialize BabyCryCNN")
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

    def forward(self, inputs):
        return self.classifier(self.features(inputs))


def analyze_audio_file(file_path: Path) -> dict:
    if not file_path.exists():
        raise FileNotFoundError(f"Audio file not found: {file_path}")

    time.sleep(2)
    features = _extract_features(file_path)
    return _classify_audio(file_path, features)


def _extract_features(file_path: Path) -> AudioFeatures:
    signal, sample_rate = librosa.load(file_path, sr=16_000, mono=True, duration=7)
    if signal.size == 0:
        signal = np.zeros(16_000, dtype=np.float32)

    signal = signal.astype(np.float32)
    rms = librosa.feature.rms(y=signal, frame_length=1024, hop_length=256)[0]
    zcr = librosa.feature.zero_crossing_rate(
        signal,
        frame_length=1024,
        hop_length=256,
    )[0]
    centroid = librosa.feature.spectral_centroid(
        y=signal,
        sr=sample_rate,
        n_fft=1024,
        hop_length=256,
    )[0]
    onset = librosa.onset.onset_strength(y=signal, sr=sample_rate, hop_length=256)

    pitch_track = librosa.yin(
        signal,
        fmin=80,
        fmax=1_200,
        sr=sample_rate,
        frame_length=1024,
        hop_length=256,
    )
    voiced = pitch_track[np.isfinite(pitch_track)]
    voiced_ratio = float(voiced.size / max(len(pitch_track), 1))
    pitch_median = float(np.median(voiced)) if voiced.size else 0.0
    pitch_std = float(np.std(voiced)) if voiced.size else 0.0

    rms_mean = float(np.mean(rms))
    rms_peak = float(np.max(rms))
    onset_mean = float(np.mean(onset)) if onset.size else 0.0
    onset_peak = float(np.max(onset)) if onset.size else 0.0
    transient_ratio = onset_peak / max(onset_mean, 1e-6)
    burst_threshold = rms_mean + float(np.std(rms))
    burst_ratio = float(np.mean(rms > burst_threshold))
    dynamic_range = float(np.percentile(signal, 95) - np.percentile(signal, 5))

    return AudioFeatures(
        rms_mean=rms_mean,
        rms_peak=rms_peak,
        zero_crossing_mean=float(np.mean(zcr)),
        spectral_centroid_mean=float(np.mean(centroid)),
        onset_mean=onset_mean,
        onset_peak=onset_peak,
        transient_ratio=float(transient_ratio),
        voiced_ratio=voiced_ratio,
        pitch_median=pitch_median,
        pitch_std=pitch_std,
        burst_ratio=burst_ratio,
        dynamic_range=dynamic_range,
    )


def _classify_audio(file_path: Path, features: AudioFeatures) -> dict:
    if features.rms_peak < 0.012 or (
        features.rms_mean < 0.008 and features.voiced_ratio < 0.15
    ):
        predictions = _normalize_probabilities(
            {
                "Unclear Audio": 0.72,
                "Background Noise": 0.18,
                "Adult Voice": 0.06,
                "Impact / Knock": 0.04,
            }
        )
        return _build_result(
            analysis_family="unclear_audio",
            screening_label="No clear baby signal",
            predictions=predictions,
            top_result="Unclear Audio",
            cry_detected=False,
            baby_voice_detected=False,
            result_summary="No reliable infant vocal signal was detected in this clip.",
            detected_sound="Low-level or ambiguous ambient sound",
            phonetic_patterns=[],
            mixed_types=[],
        )

    if (
        features.transient_ratio > 18
        and features.burst_ratio < 0.12
        and features.dynamic_range < 0.012
    ) or (
        features.transient_ratio > 10
        and features.zero_crossing_mean < 0.01
        and features.rms_peak > 0.06
    ):
        predictions = _normalize_probabilities(
            {
                "Impact / Knock": 0.72,
                "Background Noise": 0.16,
                "Adult Voice": 0.08,
                "Unclear Audio": 0.04,
            }
        )
        return _build_result(
            analysis_family="non_baby_audio",
            screening_label="Non-baby audio",
            predictions=predictions,
            top_result="Impact / Knock",
            cry_detected=False,
            baby_voice_detected=False,
            result_summary="The clip sounds more like a knock, tap, or other sharp transient than baby crying.",
            detected_sound="Short impact, tap, or knock-like transient",
            phonetic_patterns=[],
            mixed_types=[],
        )

    if (
        90 <= features.pitch_median <= 320
        and features.pitch_std < 145
        and features.transient_ratio < 6.5
        and features.spectral_centroid_mean < 1_450
    ):
        predictions = _normalize_probabilities(
            {
                "Adult Voice": 0.72,
                "Background Noise": 0.14,
                "Unclear Audio": 0.08,
                "Impact / Knock": 0.06,
            }
        )
        return _build_result(
            analysis_family="non_baby_audio",
            screening_label="Non-baby audio",
            predictions=predictions,
            top_result="Adult Voice",
            cry_detected=False,
            baby_voice_detected=False,
            result_summary="The strongest signal sounds like adult speech or a nearby voice, not infant crying.",
            detected_sound="Adult speech or nearby spoken voice",
            phonetic_patterns=[],
            mixed_types=[],
        )

    baby_voice_candidate = (
        ((220 <= features.pitch_median <= 1_050) or features.pitch_std >= 150)
        and features.zero_crossing_mean > 0.018
    )
    distress_index = _distress_index(features)

    if baby_voice_candidate and distress_index >= 0.42:
        predictions = _build_cry_predictions(file_path, features)
        top_result = max(predictions, key=predictions.get)
        phonetic_patterns = _estimate_phonetic_patterns(top_result, features)
        mixed_types = _estimate_mixed_types(predictions, top_result)
        return _build_result(
            analysis_family="baby_cry",
            screening_label="Baby cry detected",
            predictions=predictions,
            top_result=top_result,
            cry_detected=True,
            baby_voice_detected=True,
            result_summary="An infant cry-like signal was detected, so the app estimated the most likely need state below.",
            detected_sound="Infant cry-like vocal pattern",
            phonetic_patterns=phonetic_patterns,
            mixed_types=mixed_types,
        )

    if baby_voice_candidate:
        predictions = _build_infant_voice_predictions(features)
        top_result = max(predictions, key=predictions.get)
        phonetic_patterns = _estimate_non_cry_patterns(top_result, features)
        return _build_result(
            analysis_family="baby_voice_non_cry",
            screening_label="Baby voice detected",
            predictions=predictions,
            top_result=top_result,
            cry_detected=False,
            baby_voice_detected=True,
            result_summary="An infant vocal signal was detected, but it does not sound like a distress cry.",
            detected_sound=f"Infant vocalization that sounds more {top_result.lower()} than distressed",
            phonetic_patterns=phonetic_patterns,
            mixed_types=[],
        )

    predictions = _normalize_probabilities(
        {
            "Background Noise": 0.58,
            "Adult Voice": 0.18,
            "Unclear Audio": 0.16,
            "Impact / Knock": 0.08,
        }
    )
    return _build_result(
        analysis_family="non_baby_audio",
        screening_label="Non-baby audio",
        predictions=predictions,
        top_result="Background Noise",
        cry_detected=False,
        baby_voice_detected=False,
        result_summary="The clip did not screen as infant crying. Background or environmental audio was more dominant.",
        detected_sound="Ambient room noise or non-vocal background sound",
        phonetic_patterns=[],
        mixed_types=[],
    )


def _distress_index(features: AudioFeatures) -> float:
    energy_score = _clamp((features.rms_mean - 0.004) / 0.03)
    burst_score = _clamp((features.burst_ratio - 0.14) / 0.40)
    pitch_variation_score = _clamp(features.pitch_std / 180)
    transient_score = _clamp((features.transient_ratio - 1.1) / 2.5)
    centroid_score = _clamp((features.spectral_centroid_mean - 850) / 900)
    return (
        (0.22 * energy_score)
        + (0.18 * burst_score)
        + (0.28 * pitch_variation_score)
        + (0.20 * transient_score)
        + (0.12 * centroid_score)
    )


def _build_cry_predictions(file_path: Path, features: AudioFeatures) -> dict[str, float]:
    model_predictions = _predict_with_trained_model(file_path)
    if model_predictions is not None:
        return model_predictions

    seed = _stable_seed(file_path, features)
    rng = random.Random(seed)

    energy_score = _clamp((features.rms_mean - 0.004) / 0.045)
    pitch_score = _clamp((features.pitch_median - 220) / 500)
    variability_score = _clamp(features.pitch_std / 210)
    burst_score = _clamp((features.burst_ratio - 0.12) / 0.42)

    weights = {
        "Hungry": 0.28 + (0.16 * (1 - abs(energy_score - 0.55))) + (0.08 * (1 - variability_score)),
        "Sleepy": 0.24 + (0.18 * (1 - energy_score)) + (0.08 * (1 - burst_score)),
        "Pain/Gas": 0.22 + (0.20 * pitch_score) + (0.12 * variability_score),
        "Fussy": 0.24 + (0.15 * variability_score) + (0.08 * energy_score),
    }

    jittered = {
        label: value + rng.uniform(0.0, 0.035)
        for label, value in weights.items()
    }
    return _normalize_probabilities(jittered)


@lru_cache(maxsize=1)
def _load_cry_model_bundle():
    if torch is None or nn is None:
        return None
    if not MODEL_STATE_PATH.exists() or not MODEL_LABELS_PATH.exists():
        return None

    label_to_index = json.loads(MODEL_LABELS_PATH.read_text(encoding="utf-8"))
    ordered_labels = [
        label
        for label, _ in sorted(label_to_index.items(), key=lambda item: item[1])
    ]
    model = BabyCryCNN(num_classes=len(ordered_labels))
    state = torch.load(MODEL_STATE_PATH, map_location="cpu")
    model.load_state_dict(state)
    model.eval()
    return model, ordered_labels


def _predict_with_trained_model(file_path: Path) -> dict[str, float] | None:
    bundle = _load_cry_model_bundle()
    if bundle is None:
        return None

    model, ordered_labels = bundle
    mel = _load_log_mel(file_path)
    with torch.no_grad():
        logits = model(torch.from_numpy(mel).unsqueeze(0).unsqueeze(0))
        probabilities = torch.softmax(logits, dim=1)[0].cpu().numpy()

    return {
        label: round(float(probabilities[index]), 4)
        for index, label in enumerate(ordered_labels)
    }


def _load_log_mel(
    audio_path: Path,
    *,
    sample_rate: int = 16_000,
    duration_seconds: int = 7,
    n_mels: int = 128,
    target_frames: int = 128,
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


def _build_infant_voice_predictions(features: AudioFeatures) -> dict[str, float]:
    energy_score = _clamp((features.rms_mean - 0.015) / 0.06)
    pitch_score = _clamp((features.pitch_median - 360) / 420)
    burst_score = _clamp((features.burst_ratio - 0.10) / 0.36)

    weights = {
        "Excited": 0.26 + (0.18 * energy_score) + (0.18 * pitch_score),
        "Seeking Attention": 0.24 + (0.20 * burst_score) + (0.10 * energy_score),
        "Content/Playful": 0.28 + (0.18 * (1 - burst_score)) + (0.10 * (1 - energy_score)),
    }
    return _normalize_probabilities(weights)


def _build_result(
    *,
    analysis_family: str,
    screening_label: str,
    predictions: dict[str, float],
    top_result: str,
    cry_detected: bool,
    baby_voice_detected: bool,
    result_summary: str,
    detected_sound: str | None,
    phonetic_patterns: list[str],
    mixed_types: list[str],
) -> dict:
    return {
        "analysis_family": analysis_family,
        "screening_label": screening_label,
        "predictions": predictions,
        "top_result": top_result,
        "cry_detected": cry_detected,
        "baby_voice_detected": baby_voice_detected,
        "result_summary": result_summary,
        "detected_sound": detected_sound,
        "primary_pattern": phonetic_patterns[0] if phonetic_patterns else None,
        "phonetic_patterns": phonetic_patterns,
        "mixed_types": mixed_types,
    }


def _normalize_probabilities(weights: dict[str, float]) -> dict[str, float]:
    total = sum(max(weight, 0.0) for weight in weights.values())
    if total <= 0:
        even = round(1 / len(weights), 4)
        result = {label: even for label in weights}
        first_label = next(iter(result))
        result[first_label] = round(1 - sum(v for k, v in result.items() if k != first_label), 4)
        return result

    normalized = {
        label: round(max(weight, 0.0) / total, 4)
        for label, weight in weights.items()
    }
    labels = list(normalized.keys())
    running = sum(normalized[label] for label in labels[:-1])
    normalized[labels[-1]] = round(max(0.0, 1 - running), 4)
    return normalized


def _stable_seed(file_path: Path, features: AudioFeatures) -> int:
    fingerprint = (
        f"{file_path.name}|{features.pitch_median:.2f}|{features.pitch_std:.2f}|"
        f"{features.rms_mean:.5f}|{features.burst_ratio:.5f}"
    )
    return int(hashlib.sha256(fingerprint.encode("utf-8")).hexdigest()[:8], 16)


def _clamp(value: float) -> float:
    return float(max(0.0, min(1.0, value)))


def _estimate_phonetic_patterns(top_result: str, features: AudioFeatures) -> list[str]:
    if top_result == "Hungry":
        if features.burst_ratio > 0.22:
            return ["neh-neh", "eh-neh"]
        return ["neh", "neh-eh"]
    if top_result == "Sleepy":
        if features.pitch_std < 180:
            return ["owh", "ahh-owh"]
        return ["owh-ah", "owh"]
    if top_result == "Pain/Gas":
        if features.transient_ratio > 7:
            return ["eairh", "ehyo"]
        return ["eairh", "ah-eh"]
    if top_result == "Fussy":
        if features.burst_ratio > 0.2:
            return ["heh-heh", "eh-eh"]
        return ["heh", "ah-eh"]
    return []


def _estimate_non_cry_patterns(top_result: str, features: AudioFeatures) -> list[str]:
    if top_result == "Excited":
        return ["ah-ah", "ei-yo"] if features.pitch_std > 160 else ["ahh", "ei"]
    if top_result == "Seeking Attention":
        return ["eh-eh", "ah-eh"]
    if top_result == "Content/Playful":
        return ["oo-ah", "hee-hee"] if features.rms_mean > 0.018 else ["oo", "ahh"]
    return []


def _estimate_mixed_types(
    predictions: dict[str, float],
    top_result: str,
) -> list[str]:
    ordered = sorted(predictions.items(), key=lambda item: item[1], reverse=True)
    if len(ordered) < 2:
        return []

    primary_score = ordered[0][1]
    mixed: list[str] = []
    for label, score in ordered[1:]:
        if score >= 0.24 or primary_score - score <= 0.12:
            mixed.append(label)
        if len(mixed) == 2:
            break
    return mixed
