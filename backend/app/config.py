from __future__ import annotations

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy import URL


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_environment: str = "development"
    database_url: str | None = None
    database_host: str = "db"
    postgres_db: str = "jubileu"
    postgres_user: str = "jubileu"
    postgres_password: str | None = None
    app_initial_username: str = "Samuel"
    app_initial_password: str | None = None
    app_allow_insecure_test_auth: bool = False
    command_interpreter: str = "deterministic"
    ollama_base_url: str = "http://host.docker.internal:11434"
    ollama_model: str = "qwen3:4b-instruct"
    ollama_timeout_seconds: float = 20.0
    openai_api_key: str | None = None
    transcription_engine: str = "whisper"
    whisper_model_path: str = "/models/faster-whisper-small"
    vosk_model_path: str = "/models/vosk-model-small-pt-0.3"

    @model_validator(mode="after")
    def validate_security(self) -> "Settings":
        local_environments = {"development", "test"}
        if self.app_allow_insecure_test_auth and self.app_environment not in local_environments:
            raise ValueError("APP_ALLOW_INSECURE_TEST_AUTH só é permitido em development ou test")
        if self.app_environment not in local_environments and not self.app_initial_password:
            raise ValueError("APP_INITIAL_PASSWORD é obrigatória fora de development/test")
        if self.command_interpreter not in {"deterministic", "hybrid_ollama", "ollama_first"}:
            raise ValueError("COMMAND_INTERPRETER deve ser deterministic, hybrid_ollama ou ollama_first")
        if self.transcription_engine not in {"whisper", "vosk"}:
            raise ValueError("TRANSCRIPTION_ENGINE deve ser whisper ou vosk")
        if not self.database_url:
            if not self.postgres_password:
                raise ValueError("POSTGRES_PASSWORD ou DATABASE_URL é obrigatório")
            self.database_url = URL.create(
                drivername="postgresql+psycopg",
                username=self.postgres_user,
                password=self.postgres_password,
                host=self.database_host,
                port=5432,
                database=self.postgres_db,
            ).render_as_string(hide_password=False)
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
