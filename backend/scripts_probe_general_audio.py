#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_ROOT))

from services.general_audio_screener import screen_general_audio  # noqa: E402


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts_probe_general_audio.py <audio_path>")

    audio_path = Path(sys.argv[1]).expanduser().resolve()
    result = screen_general_audio(audio_path)
    print(
        json.dumps(
            None
            if result is None
            else {
                "available": result.available,
                "provider": result.provider,
                "coarse_label": result.coarse_label,
                "coarse_confidence": result.coarse_confidence,
                "top_label": result.top_label,
                "top_score": result.top_score,
                "top_labels": result.top_labels,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
