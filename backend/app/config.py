from __future__ import annotations

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_environment: str = "development"
    database_url: str = "postgresql+psycopg://jubileu:jubileu@db:5432/jubileu"
    app_initial_username: str = "Samuel"
    app_initial_password: str | None = None
    app_allow_insecure_test_auth: bool = False
    openai_api_key: str | None = None

    @model_validator(mode="after")
    def validate_security(self) -> "Settings":
        local_environments = {"development", "test"}
        if self.app_allow_insecure_test_auth and self.app_environment not in local_environments:
            raise ValueError("APP_ALLOW_INSECURE_TEST_AUTH só é permitido em development ou test")
        if self.app_environment not in local_environments and not self.app_initial_password:
            raise ValueError("APP_INITIAL_PASSWORD é obrigatória fora de development/test")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()

