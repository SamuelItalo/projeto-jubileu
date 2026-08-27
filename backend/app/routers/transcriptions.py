from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.config import Settings, get_settings
from app.dependencies import get_current_user
from app.models import User
from app.schemas import TranscriptionResponse
from app.services.transcription import transcribe_wav

router = APIRouter(tags=["audio"])


@router.post("/transcriptions", response_model=TranscriptionResponse)
async def create_transcription(
    audio: UploadFile = File(...),
    user: User = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
) -> TranscriptionResponse:
    del user
    if audio.content_type not in {"audio/wav", "audio/x-wav", "application/octet-stream"}:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "invalid_audio"})
    content = await audio.read(5 * 1024 * 1024 + 1)
    return TranscriptionResponse(transcript=transcribe_wav(content, settings.vosk_model_path))
