from __future__ import annotations

import json

import httpx

from app.config import Settings
from app.services.interpreter import ParsedAction, ParsedCommand

_ALLOWED_ACTIONS = {"create_task", "start_task", "pause_task", "resume_task", "complete_task", "add_note"}
_SYSTEM_PROMPT = """Você interpreta comandos de produtividade em português do Brasil.
Responda APENAS JSON válido neste formato:
{"actions":[{"type":"create_task|start_task|pause_task|resume_task|complete_task|add_note","title":"texto","note":"texto ou null"}],"clarification_question":null}
Use actions vazias e uma pergunta curta em clarification_question quando não houver certeza.
Nunca invente títulos, datas, tarefas ou ações. Uma nota exige title e note."""


def parse_with_ollama(transcript: str, settings: Settings) -> ParsedCommand | None:
    try:
        response = httpx.post(
            f"{settings.ollama_base_url.rstrip('/')}/api/generate",
            json={
                "model": settings.ollama_model,
                "system": _SYSTEM_PROMPT,
                "prompt": transcript,
                "stream": False,
                "format": "json",
                "options": {"num_ctx": 4096, "num_predict": 180, "temperature": 0},
            },
            timeout=settings.ollama_timeout_seconds,
        )
        response.raise_for_status()
        payload = json.loads(response.json()["response"])
        actions_data = payload.get("actions")
        question = payload.get("clarification_question")
        if not isinstance(actions_data, list) or not isinstance(question, (str, type(None))):
            return None
        actions: list[ParsedAction] = []
        for item in actions_data:
            if not isinstance(item, dict) or item.get("type") not in _ALLOWED_ACTIONS:
                return None
            title = item.get("title")
            note = item.get("note")
            if not isinstance(title, str) or not title.strip() or (note is not None and not isinstance(note, str)):
                return None
            if item["type"] == "add_note" and (not isinstance(note, str) or not note.strip()):
                return None
            actions.append(ParsedAction(item["type"], title.strip(), note.strip() if isinstance(note, str) else None))
        if not actions and not question:
            return None
        return ParsedCommand(actions=actions, clarification_question=question)
    except (httpx.HTTPError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None
