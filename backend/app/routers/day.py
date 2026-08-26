from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import DayResponse
from app.services.day import get_day_summary

router = APIRouter(tags=["day"])


@router.get("/day", response_model=DayResponse)
def get_day(
    requested_date: date | None = Query(default=None, alias="date"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DayResponse:
    return get_day_summary(db, user, requested_date)
