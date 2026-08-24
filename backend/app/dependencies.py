from __future__ import annotations

from datetime import datetime, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import SessionRecord, User
from app.security import hash_token

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})

    session_record = db.scalar(
        select(SessionRecord).where(
            SessionRecord.token_hash == hash_token(credentials.credentials),
            SessionRecord.revoked_at.is_(None),
        )
    )
    if session_record is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})

    user = db.get(User, session_record.user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})

    session_record.last_seen_at = datetime.now(timezone.utc)
    db.commit()
    return user

