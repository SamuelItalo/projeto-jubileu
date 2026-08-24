from __future__ import annotations

from datetime import datetime, timezone
from secrets import compare_digest

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.db import get_db
from app.dependencies import get_current_user
from app.models import SessionRecord, User, UserPreference
from app.schemas import LoginRequest, SessionInfoResponse, SessionResponse
from app.security import create_session_token, hash_password, hash_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])
_INSECURE_TEST_HASH = "insecure-test-auth"
bearer_scheme = HTTPBearer(auto_error=False)


def _bootstrap_or_validate_user(payload: LoginRequest, db: Session, settings: Settings) -> User:
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None:
        if payload.username != settings.app_initial_username:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
        if settings.app_initial_password:
            if not compare_digest(payload.password, settings.app_initial_password):
                raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
            password_hash = hash_password(payload.password)
        elif settings.app_allow_insecure_test_auth:
            password_hash = _INSECURE_TEST_HASH
        else:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
        user = User(username=payload.username, password_hash=password_hash)
        db.add(user)
        db.flush()
        db.add(UserPreference(user_id=user.id))
        return user

    if user.password_hash == _INSECURE_TEST_HASH and settings.app_allow_insecure_test_auth:
        return user
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
    return user


@router.post("/login", response_model=SessionResponse)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> SessionResponse:
    user = _bootstrap_or_validate_user(payload, db, settings)
    token = create_session_token()
    now = datetime.now(timezone.utc)
    db.add(SessionRecord(user_id=user.id, token_hash=hash_token(token), last_seen_at=now))
    db.commit()
    return SessionResponse(token=token, username=user.username)


@router.get("/session", response_model=SessionInfoResponse)
def session(user: User = Depends(get_current_user)) -> SessionInfoResponse:
    return SessionInfoResponse(username=user.username)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    response: Response,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> Response:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
    session_record = db.scalar(
        select(SessionRecord).where(
            SessionRecord.user_id == user.id,
            SessionRecord.token_hash == hash_token(credentials.credentials),
            SessionRecord.revoked_at.is_(None),
        )
    )
    if session_record is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthenticated"})
    session_record.revoked_at = datetime.now(timezone.utc)
    db.commit()
    return response
