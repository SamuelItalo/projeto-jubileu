from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.config import Settings


def test_insecure_auth_is_allowed_only_locally() -> None:
    settings = Settings(app_environment="test", app_allow_insecure_test_auth=True)
    assert settings.app_allow_insecure_test_auth is True


def test_insecure_auth_is_rejected_outside_local_environments() -> None:
    with pytest.raises(ValidationError):
        Settings(app_environment="production", app_allow_insecure_test_auth=True, app_initial_password="safe-password")


def test_production_requires_initial_password() -> None:
    with pytest.raises(ValidationError):
        Settings(app_environment="production")


def test_postgres_password_is_url_encoded() -> None:
    settings = Settings(postgres_password="senha#com@caracteres")
    assert settings.database_url is not None
    assert "senha%23com%40caracteres" in settings.database_url
