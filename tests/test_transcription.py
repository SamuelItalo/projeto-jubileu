from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.services.transcription import transcribe_wav


def test_transcription_rejects_invalid_wav_before_loading_model() -> None:
    with pytest.raises(HTTPException) as error:
        transcribe_wav(b"not-a-wav", "/missing-model")

    assert error.value.status_code == 422
    assert error.value.detail == {"code": "invalid_audio"}
