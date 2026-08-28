from __future__ import annotations

import json
import wave
from functools import lru_cache
from io import BytesIO
from pathlib import Path

import numpy as np
from fastapi import HTTPException, status
from faster_whisper import WhisperModel
from vosk import KaldiRecognizer, Model

_WHISPER_PROMPT = (
    "Comandos do Jubileu: criar tarefa, iniciar tarefa, pausar tarefa, retomar tarefa, "
    "concluir tarefa, finalizar tarefa, adicionar nota, revisar orçamento, confirmar, confirmo, "
    "enviar, cancelar, cancelo, descartar."
)


class _ModelUnavailable(Exception):
    pass


class _TranscriptionFailed(Exception):
    pass


@lru_cache
def _vosk_model(path: str) -> Model:
    if not Path(path).is_dir():
        raise _ModelUnavailable
    return Model(path)


@lru_cache
def _whisper_model(path: str) -> WhisperModel:
    if not Path(path).is_dir():
        raise _ModelUnavailable
    return WhisperModel(path, device="cpu", compute_type="int8")


def _read_wav(audio: bytes) -> tuple[np.ndarray, int]:
    try:
        with wave.open(BytesIO(audio), "rb") as wav:
            if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getframerate() != 16000:
                raise ValueError("unsupported wav format")
            if wav.getnframes() / wav.getframerate() > 30:
                raise ValueError("audio too long")
            frames = wav.readframes(wav.getnframes())
            return np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0, wav.getframerate()
    except (wave.Error, ValueError, EOFError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "invalid_audio"}) from None


def _transcribe_with_whisper(samples: np.ndarray, model_path: str) -> str:
    try:
        segments, _ = _whisper_model(model_path).transcribe(
            samples,
            language="pt",
            task="transcribe",
            beam_size=5,
            vad_filter=True,
            condition_on_previous_text=False,
            initial_prompt=_WHISPER_PROMPT,
        )
        return " ".join(segment.text.strip() for segment in segments if segment.text.strip()).strip()
    except _ModelUnavailable:
        raise
    except (RuntimeError, OSError, ValueError) as error:
        raise _TranscriptionFailed from error


def _transcribe_with_vosk(samples: np.ndarray, sample_rate: int, model_path: str) -> str:
    recognizer = KaldiRecognizer(_vosk_model(model_path), sample_rate)
    pcm_audio = (samples * 32768.0).astype(np.int16).tobytes()
    for start in range(0, len(pcm_audio), 8000):
        recognizer.AcceptWaveform(pcm_audio[start : start + 8000])
    return json.loads(recognizer.FinalResult()).get("text", "").strip()


def transcribe_wav(
    audio: bytes,
    vosk_model_path: str,
    whisper_model_path: str | None = None,
    engine: str = "whisper",
) -> str:
    if len(audio) > 5 * 1024 * 1024:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "invalid_audio"})
    samples, sample_rate = _read_wav(audio)

    transcript = ""
    if engine == "whisper" and whisper_model_path:
        try:
            transcript = _transcribe_with_whisper(samples, whisper_model_path)
        except (_ModelUnavailable, _TranscriptionFailed):
            transcript = ""
    if not transcript:
        try:
            transcript = _transcribe_with_vosk(samples, sample_rate, vosk_model_path)
        except _ModelUnavailable:
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, detail={"code": "transcription_unavailable"}) from None
    if not transcript:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail={"code": "no_speech_recognized"})
    return transcript
