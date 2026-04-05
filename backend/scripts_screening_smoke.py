from __future__ import annotations

import json
import math
import shutil
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

from services.audio_processor import analyze_audio_file


ROOT = Path(__file__).resolve().parents[1]
FRONTEND_SAMPLES = ROOT / "frontend" / "assets" / "samples"


def main() -> None:
    temp_dir = Path(tempfile.mkdtemp(prefix="baby-cry-screening-"))
    try:
        samples = build_samples(temp_dir)
        report = []
        for sample in samples:
            result = analyze_audio_file(sample["path"])
            passed = (
                result["analysis_family"] == sample["expected_family"]
                and result["top_result"] == sample["expected_top"]
            )
            report.append(
                {
                    "name": sample["name"],
                    "expected_family": sample["expected_family"],
                    "expected_top": sample["expected_top"],
                    "actual_family": result["analysis_family"],
                    "actual_top": result["top_result"],
                    "passed": passed,
                    "predictions": result["predictions"],
                }
            )

        summary = {
            "passed": sum(1 for item in report if item["passed"]),
            "total": len(report),
            "results": report,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def build_samples(temp_dir: Path) -> list[dict]:
    samples = [
        {
            "name": "hungry_sample",
            "path": FRONTEND_SAMPLES / "hungry_sample.wav",
            "expected_family": "baby_cry",
            "expected_top": "Hungry",
        },
        {
            "name": "sleepy_sample",
            "path": FRONTEND_SAMPLES / "sleepy_sample.wav",
            "expected_family": "baby_cry",
            "expected_top": "Sleepy",
        },
    ]

    silence_path = temp_dir / "silence.wav"
    create_silence(silence_path)
    samples.append(
        {
            "name": "silence",
            "path": silence_path,
            "expected_family": "unclear_audio",
            "expected_top": "Unclear Audio",
        }
    )

    knocks_path = temp_dir / "knocks.wav"
    create_knocks(knocks_path)
    samples.append(
        {
            "name": "knocks",
            "path": knocks_path,
            "expected_family": "non_baby_audio",
            "expected_top": "Impact / Knock",
        }
    )

    adult_speech_path = temp_dir / "adult_speech.wav"
    if create_adult_speech(adult_speech_path):
        samples.append(
            {
                "name": "adult_speech",
                "path": adult_speech_path,
                "expected_family": "non_baby_audio",
                "expected_top": "Adult Voice",
            }
        )

    return samples


def create_silence(path: Path) -> None:
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(16_000)
        handle.writeframes(b"\x00\x00" * 16_000)


def create_knocks(path: Path) -> None:
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(16_000)
        frames = []
        for index in range(16_000):
            amplitude = 0
            if any(abs(index - center) < 120 for center in [2_000, 6_000, 10_000, 14_000]):
                amplitude = int(22_000 * math.exp(-abs((index % 400) - 200) / 45))
            frames.append(struct.pack("<h", max(-32_767, min(32_767, amplitude))))
        handle.writeframes(b"".join(frames))


def create_adult_speech(path: Path) -> bool:
    say_binary = shutil.which("say")
    ffmpeg_binary = shutil.which("ffmpeg")
    if not say_binary or not ffmpeg_binary:
        return False

    aiff_path = path.with_suffix(".aiff")
    subprocess.run(
        [
            say_binary,
            "-o",
            str(aiff_path),
            "Hello baby, I am speaking near the microphone right now.",
        ],
        check=True,
    )
    subprocess.run(
        [
            ffmpeg_binary,
            "-y",
            "-i",
            str(aiff_path),
            "-ar",
            "16000",
            "-ac",
            "1",
            str(path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return path.exists()


if __name__ == "__main__":
    main()
