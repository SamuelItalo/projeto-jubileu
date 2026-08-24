from __future__ import annotations

from app.security import create_session_token, hash_password, hash_token, verify_password


def test_password_hash_round_trip() -> None:
    password_hash = hash_password("senha-de-teste")
    assert verify_password("senha-de-teste", password_hash)
    assert not verify_password("outra-senha", password_hash)


def test_session_tokens_are_opaque_and_hashable() -> None:
    token = create_session_token()
    assert len(token) >= 32
    assert len(hash_token(token)) == 64
    assert hash_token(token) != token

