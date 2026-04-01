import shutil
import tempfile
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from services.audio_processor import analyze_audio_file
from services.llm_service import get_soothing_advice
from services.media_processor import (
    ALL_SUPPORTED_SUFFIXES,
    classify_source_type,
    encode_audio_base64,
    normalize_media_to_wav,
)

router = APIRouter(tags=["analysis"])


class FeedbackRequest(BaseModel):
    record_id: str = Field(..., min_length=1)
    user_id: str = Field(..., min_length=1)
    actual_label: str = Field(..., min_length=1)

@router.post("/analyze")
async def analyze_cry(
    audio: UploadFile | None = File(default=None),
    media: UploadFile | None = File(default=None),
) -> dict:
    upload = media or audio
    if upload is None:
        raise HTTPException(
            status_code=400,
            detail="Provide one media file in the 'media' or legacy 'audio' form field.",
        )

    suffix = Path(upload.filename or "").suffix.lower()
    if suffix not in ALL_SUPPORTED_SUFFIXES:
        raise HTTPException(
            status_code=400,
            detail="Supported formats: .wav, .m4a, .mp3, .aac, .caf, .3gp, .mp4, .mov, .m4v, .avi, .mkv, .webm",
        )

    source_type = classify_source_type(Path(upload.filename or f"input{suffix}"))
    record_id = str(uuid4())
    temp_input_path = Path(tempfile.gettempdir()) / f"{record_id}{suffix}"
    normalized_audio_path = Path(tempfile.gettempdir()) / f"{record_id}_normalized.wav"

    try:
        with temp_input_path.open("wb") as buffer:
            shutil.copyfileobj(upload.file, buffer)

        normalize_media_to_wav(temp_input_path, normalized_audio_path)
        predictions = analyze_audio_file(normalized_audio_path)
        top_result = max(predictions, key=predictions.get)
        llm_advice = await get_soothing_advice(top_result)

        return {
            "record_id": record_id,
            "predictions": predictions,
            "top_result": top_result,
            "llm_advice": llm_advice,
            "source_type": source_type,
            "normalized_audio_format": "wav",
            "normalized_audio_base64": encode_audio_base64(normalized_audio_path),
        }
    finally:
        if temp_input_path.exists():
            temp_input_path.unlink()
        if normalized_audio_path.exists():
            normalized_audio_path.unlink()
        await upload.close()


@router.post("/feedback")
async def submit_feedback(payload: FeedbackRequest) -> dict[str, str]:
    return {"status": "success"}
