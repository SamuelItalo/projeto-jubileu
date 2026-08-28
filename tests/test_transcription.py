from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.services import transcription
from app.services.transcription import transcribe_wav


def test_transcription_rejects_invalid_wav_before_loading_model() -> None:
    with pytest.raises(HTTPException) as error:
        transcribe_wav(b"not-a-wav", "/missing-model")

    assert error.value.status_code == 422
    assert error.value.detail == {"code": "invalid_audio"}


def test_whisper_is_the_primary_engine(monkeypatch) -> None:
    monkeypatch.setattr(transcription, "_read_wav", lambda audio: (object(), 16000))
    monkeypatch.setattr(transcription, "_transcribe_with_whisper", lambda samples, path: "texto do whisper")
    monkeypatch.setattr(
        transcription,
        "_transcribe_with_vosk",
        lambda *args: pytest.fail("Vosk não deve ser chamado quando Whisper funciona"),
    )

    assert transcribe_wav(b"audio", "/vosk", "/whisper") == "texto do whisper"


def test_vosk_is_used_when_whisper_is_unavailable(monkeypatch) -> None:
    monkeypatch.setattr(transcription, "_read_wav", lambda audio: (object(), 16000))

    def unavailable(samples, path):
        raise transcription._ModelUnavailable

    monkeypatch.setattr(transcription, "_transcribe_with_whisper", unavailable)
    monkeypatch.setattr(transcription, "_transcribe_with_vosk", lambda *args: "texto de reserva")

    assert transcribe_wav(b"audio", "/vosk", "/whisper") == "texto de reserva"
