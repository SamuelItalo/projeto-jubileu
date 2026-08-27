from __future__ import annotations

import json
import wave
from functools import lru_cache
from io import BytesIO
from pathlib import Path

from fastapi import HTTPException, status
from vosk import KaldiRecognizer, Model


@lru_cache
def _model(path: str) -> Model:
    if not Path(path).is_dir():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, detail={"code": "transcription_unavailable"})
    return Model(path)


def transcribe_wav(audio: bytes, model_path: str) -> str:
    if len(audio) > 5 * 1024 * 1024:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "invalid_audio"})
    try:
        with wave.open(BytesIO(audio), "rb") as wav:
            if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getframerate() != 16000:
                raise ValueError("unsupported wav format")
            if wav.getnframes() / wav.getframerate() > 30:
                raise ValueError("audio too long")
            recognizer = KaldiRecognizer(_model(model_path), wav.getframerate())
            while chunk := wav.readframes(4000):
                recognizer.AcceptWaveform(chunk)
            transcript = json.loads(recognizer.FinalResult()).get("text", "").strip()
    except HTTPException:
        raise
    except (wave.Error, ValueError, EOFError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "invalid_audio"}) from None
    if not transcript:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "no_speech_recognized"})
    return transcript
