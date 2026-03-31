import shutil
import tempfile
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from services.audio_processor import analyze_audio_file
from services.llm_service import get_soothing_advice

router = APIRouter(tags=["analysis"])

ALLOWED_SUFFIXES = {".wav", ".m4a"}


class FeedbackRequest(BaseModel):
    record_id: str = Field(..., min_length=1)
    user_id: str = Field(..., min_length=1)
    actual_label: str = Field(..., min_length=1)


@router.post("/analyze")
async def analyze_cry(audio: UploadFile = File(...)) -> dict:
    suffix = Path(audio.filename or "").suffix.lower()
    if suffix not in ALLOWED_SUFFIXES:
        raise HTTPException(status_code=400, detail="Only .wav and .m4a files are supported.")

    record_id = str(uuid4())
    temp_path = Path(tempfile.gettempdir()) / f"{record_id}{suffix}"

    try:
        with temp_path.open("wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)

        predictions = analyze_audio_file(temp_path)
        top_result = max(predictions, key=predictions.get)
        llm_advice = await get_soothing_advice(top_result)

        return {
            "record_id": record_id,
            "predictions": predictions,
            "top_result": top_result,
            "llm_advice": llm_advice,
        }
    finally:
        if temp_path.exists():
            temp_path.unlink()
        await audio.close()


@router.post("/feedback")
async def submit_feedback(payload: FeedbackRequest) -> dict[str, str]:
    return {"status": "success"}
