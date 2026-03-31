import random
import time
from pathlib import Path

LABELS = ["Hungry", "Sleepy", "Pain/Gas", "Fussy"]


def analyze_audio_file(file_path: Path) -> dict[str, float]:
    if not file_path.exists():
        raise FileNotFoundError(f"Audio file not found: {file_path}")

    time.sleep(2)

    weights = [random.random() for _ in LABELS]
    total = sum(weights)
    normalized = [weight / total for weight in weights]

    predictions = {
        label: round(score, 4)
        for label, score in zip(LABELS[:-1], normalized[:-1], strict=True)
    }
    predictions[LABELS[-1]] = round(1 - sum(predictions.values()), 4)
    return predictions
