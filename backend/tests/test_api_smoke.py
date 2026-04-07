from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

from main import create_app


ROOT = Path(__file__).resolve().parents[2]
SAMPLES_DIR = ROOT / "frontend" / "assets" / "samples"
HUNGRY_SAMPLE = SAMPLES_DIR / "hungry_sample.wav"


class ApiSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(create_app())

    def test_health(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_feedback(self) -> None:
        response = self.client.post(
            "/api/v1/feedback",
            json={
                "record_id": str(uuid4()),
                "user_id": "smoke-user",
                "actual_label": "Hungry",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "success"})

    def test_analyze_wav(self) -> None:
        response = self._post_media(HUNGRY_SAMPLE, "audio/wav")
        self._assert_analysis_response(response)

    def test_analyze_m4a(self) -> None:
        with self._transcode_sample(".m4a") as media_path:
            response = self._post_media(media_path, "audio/mp4")
        self._assert_analysis_response(response)

    def test_analyze_mp4(self) -> None:
        with self._wrap_sample_as_video() as media_path:
            response = self._post_media(media_path, "video/mp4")
        self._assert_analysis_response(response)

    def _post_media(self, media_path: Path, content_type: str):
        with media_path.open("rb") as handle:
            response = self.client.post(
                "/api/v1/analyze",
                files={
                    "media": (
                        media_path.name,
                        handle,
                        content_type,
                    )
                },
            )
        return response

    def _assert_analysis_response(self, response) -> None:
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertIn("record_id", payload)
        self.assertIn("predictions", payload)
        self.assertIn("top_result", payload)
        self.assertIn("analysis_family", payload)
        self.assertIn("normalized_audio_base64", payload)
        self.assertTrue(payload["normalized_audio_base64"])

    def _ffmpeg(self, *args: str) -> None:
        result = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr.strip() or "ffmpeg failed")

    def _transcode_sample(self, extension: str):
        class _TempMedia:
            def __init__(self, outer: "ApiSmokeTests", suffix: str) -> None:
                self.outer = outer
                self.suffix = suffix
                self.path = Path(tempfile.gettempdir()) / f"smoke_{uuid4().hex}{suffix}"

            def __enter__(self) -> Path:
                if self.suffix == ".m4a":
                    self.outer._ffmpeg(
                        "-i",
                        str(HUNGRY_SAMPLE),
                        "-c:a",
                        "aac",
                        str(self.path),
                    )
                else:
                    raise AssertionError(f"Unsupported suffix: {self.suffix}")
                return self.path

            def __exit__(self, exc_type, exc, tb) -> None:
                self.path.unlink(missing_ok=True)

        return _TempMedia(self, extension)

    def _wrap_sample_as_video(self):
        class _TempVideo:
            def __init__(self, outer: "ApiSmokeTests") -> None:
                self.outer = outer
                self.path = Path(tempfile.gettempdir()) / f"smoke_{uuid4().hex}.mp4"

            def __enter__(self) -> Path:
                self.outer._ffmpeg(
                    "-f",
                    "lavfi",
                    "-i",
                    "color=c=black:s=320x240:d=7",
                    "-i",
                    str(HUNGRY_SAMPLE),
                    "-shortest",
                    "-c:v",
                    "libx264",
                    "-pix_fmt",
                    "yuv420p",
                    "-c:a",
                    "aac",
                    str(self.path),
                )
                return self.path

            def __exit__(self, exc_type, exc, tb) -> None:
                self.path.unlink(missing_ok=True)

        return _TempVideo(self)


if __name__ == "__main__":
    unittest.main()
