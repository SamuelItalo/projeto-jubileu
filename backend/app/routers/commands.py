from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import AssistantResponse, VoiceCommandRequest
from app.services.commands import process_command as process_deterministic_command

router = APIRouter(tags=["commands"])


@router.post("/commands", response_model=AssistantResponse)
def process_command(
    payload: VoiceCommandRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AssistantResponse:
    return process_deterministic_command(db, user, payload)
