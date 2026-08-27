from __future__ import annotations

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(default="", max_length=512)


class SessionResponse(BaseModel):
    token: str
    username: str


class SessionInfoResponse(BaseModel):
    username: str


class TranscriptionResponse(BaseModel):
    transcript: str


class ConfirmationContext(BaseModel):
    group_id: UUID
    action_id: UUID | None = None


class VoiceCommandRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    request_id: UUID
    occurred_at: datetime
    timezone: str = Field(min_length=1, max_length=64)
    source: Literal["voice"]
    transcript: str = Field(min_length=1, max_length=10_000)
    confirmation_context: ConfirmationContext | None = None


class TaskResponse(BaseModel):
    id: UUID
    title: str
    status: Literal["pending", "in_progress", "paused", "completed"]
    total_duration_seconds: int
    notes: list["TaskNoteResponse"] = []


class TaskNoteResponse(BaseModel):
    content: str
    created_at: datetime


class AssistantResponse(BaseModel):
    request_id: UUID
    status: Literal["awaiting_confirmation", "completed", "needs_clarification", "rejected", "error"]
    message: str
    tasks: list[TaskResponse] = []
    suggestions: list[str] = []
    requires_confirmation: bool = False
    clarification_question: str | None = None
    confirmation_context: ConfirmationContext | None = None


class DayResponse(BaseModel):
    date: date
    tasks: list[TaskResponse] = []
    active_task: TaskResponse | None = None
    total_duration_seconds: int = 0
