import json

from app.config import Settings
from app.services.ollama import parse_with_ollama


class FakeResponse:
    def __init__(self, body: dict[str, str]) -> None:
        self.body = body

    def raise_for_status(self) -> None:
        pass

    def json(self) -> dict[str, str]:
        return self.body


def test_parse_with_ollama_accepts_valid_action(monkeypatch) -> None:
    def fake_post(*args, **kwargs):
        assert kwargs["json"]["format"] == "json"
        return FakeResponse(
            {
                "response": json.dumps(
                    {
                        "actions": [
                            {"type": "create_task", "title": "Revisar orçamento", "note": None}
                        ],
                        "clarification_question": None,
                    }
                )
            }
        )

    monkeypatch.setattr("app.services.ollama.httpx.post", fake_post)

    parsed = parse_with_ollama("preciso revisar o orçamento", Settings())

    assert parsed is not None
    assert parsed.actions[0].type == "create_task"
    assert parsed.actions[0].title == "Revisar orçamento"


def test_parse_with_ollama_rejects_invalid_model_json(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.ollama.httpx.post",
        lambda *args, **kwargs: FakeResponse({"response": "não é json"}),
    )

    assert parse_with_ollama("qualquer frase", Settings()) is None
