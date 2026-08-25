from __future__ import annotations

from app.services.interpreter import confirmation_decision, parse_deterministic


def test_parses_task_creation_preserving_title() -> None:
    parsed = parse_deterministic("Crie tarefa Preparar Relatório")
    assert parsed.clarification_question is None
    assert parsed.actions[0].type == "create_task"
    assert parsed.actions[0].title == "Preparar Relatório"


def test_parses_multiple_creations_separated_by_semicolon() -> None:
    parsed = parse_deterministic("criar tarefa relatório; criar tarefa orçamento")
    assert [action.title for action in parsed.actions] == ["relatório", "orçamento"]


def test_parses_note_with_title_and_content() -> None:
    parsed = parse_deterministic("adicionar nota em relatório: revisei a introdução")
    assert parsed.actions[0].type == "add_note"
    assert parsed.actions[0].title == "relatório"
    assert parsed.actions[0].note == "revisei a introdução"


def test_unknown_command_requests_clarification() -> None:
    parsed = parse_deterministic("organize meu dia")
    assert not parsed.actions
    assert parsed.clarification_question is not None


def test_confirmation_is_explicit() -> None:
    assert confirmation_decision("Confirmo!") == "confirm"
    assert confirmation_decision("Não") == "cancel"
    assert confirmation_decision("acho que sim") is None
