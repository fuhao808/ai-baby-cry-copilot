import base64
import subprocess
from pathlib import Path

AUDIO_SUFFIXES = {".wav", ".m4a", ".mp3", ".aac", ".caf", ".3gp"}
VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}
ALL_SUPPORTED_SUFFIXES = AUDIO_SUFFIXES | VIDEO_SUFFIXES


def classify_source_type(file_path: Path) -> str:
    suffix = file_path.suffix.lower()
    if suffix in VIDEO_SUFFIXES:
        return "uploaded_video"
    if suffix in AUDIO_SUFFIXES:
        return "uploaded_audio"
    raise ValueError(f"Unsupported media format: {suffix}")


def normalize_media_to_wav(
    input_path: Path,
    output_path: Path,
    *,
    duration_seconds: int = 7,
) -> Path:
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(input_path),
        "-vn",
        "-ac",
        "1",
        "-ar",
        "16000",
        "-t",
        str(duration_seconds),
        str(output_path),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip() or "Failed to normalize media with ffmpeg."
        )

    if not output_path.exists():
        raise RuntimeError("ffmpeg completed without creating normalized audio output.")

    return output_path


def encode_audio_base64(file_path: Path) -> str:
    return base64.b64encode(file_path.read_bytes()).decode("ascii")
