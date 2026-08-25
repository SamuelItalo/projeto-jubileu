from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Literal


ActionType = Literal["create_task", "start_task", "pause_task", "resume_task", "complete_task", "add_note"]


@dataclass(frozen=True)
class ParsedAction:
    type: ActionType
    title: str
    note: str | None = None


@dataclass(frozen=True)
class ParsedCommand:
    actions: list[ParsedAction]
    clarification_question: str | None = None


def normalize(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text)
    no_accents = "".join(character for character in decomposed if not unicodedata.combining(character))
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s:]", " ", no_accents.lower())).strip()


def _match(pattern: str, original: str) -> str | None:
    match = re.fullmatch(pattern, normalize(original))
    if match is None:
        return None
    # O grupo normalizado é usado apenas para localizar a intenção; o texto original é preservado no título.
    return match.group(1).strip()


def parse_deterministic(transcript: str) -> ParsedCommand:
    actions: list[ParsedAction] = []
    for raw_part in transcript.split(";"):
        part = raw_part.strip()
        normalized = normalize(part)
        if not normalized:
            continue

        note_match = re.fullmatch(r"adicionar nota em (.+?)\s*:\s*(.+)", normalized)
        if note_match:
            title, note = part.split(":", 1)
            title = re.sub(r"^adicionar\s+nota\s+em\s+", "", title, flags=re.IGNORECASE).strip()
            if title and note.strip():
                actions.append(ParsedAction("add_note", title=title, note=note.strip()))
                continue

        patterns: list[tuple[ActionType, str]] = [
            ("create_task", r"(?:criar|crie) (?:a )?tarefa (.+)"),
            ("start_task", r"iniciar (.+)"),
            ("pause_task", r"pausar (.+)"),
            ("resume_task", r"retomar (.+)"),
            ("complete_task", r"concluir (.+)"),
        ]
        for action_type, pattern in patterns:
            matched_title = _match(pattern, part)
            if matched_title:
                # Remove o prefixo pelo padrão sem depender de caixa/acentos para manter a grafia do título.
                if action_type == "create_task":
                    title = re.sub(r"^(criar|crie)\s+(a\s+)?tarefa\s+", "", part, flags=re.IGNORECASE).strip()
                else:
                    title = re.sub(r"^(iniciar|pausar|retomar|concluir)\s+", "", part, flags=re.IGNORECASE).strip()
                if title:
                    actions.append(ParsedAction(action_type, title=title))
                    break
        else:
            return ParsedCommand(
                actions=[],
                clarification_question=(
                    "Não entendi. Experimente: ‘criar tarefa relatório’, ‘iniciar relatório’, "
                    "‘pausar relatório’, ‘retomar relatório’, ‘concluir relatório’ ou "
                    "‘adicionar nota em relatório: texto’."
                ),
            )

    if not actions:
        return ParsedCommand(actions=[], clarification_question="Diga um comando com uma tarefa.")
    return ParsedCommand(actions=actions)


def confirmation_decision(transcript: str) -> Literal["confirm", "cancel"] | None:
    normalized = normalize(transcript)
    if normalized in {"confirmo", "sim confirmar", "pode criar", "confirmar"}:
        return "confirm"
    if normalized in {"cancelo", "cancelar", "nao"}:
        return "cancel"
    return None
