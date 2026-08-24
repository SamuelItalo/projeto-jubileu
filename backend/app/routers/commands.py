from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import AssistantResponse, VoiceCommandRequest

router = APIRouter(tags=["commands"])


@router.post("/commands", response_model=AssistantResponse)
def process_command(
    payload: VoiceCommandRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AssistantResponse:
    raise HTTPException(
        status.HTTP_501_NOT_IMPLEMENTED,
        detail={"code": "implementation_pending", "message": "Processamento de comandos será entregue no próximo incremento."},
    )

