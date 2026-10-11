"""Short-lived bearer tokens used to bind marketplace payments to accounts."""

import base64
import binascii
import hashlib
import hmac
import json
import os
import time

from fastapi import HTTPException


def issue_access_token(user_id: int, email: str) -> str:
    secret = os.getenv("JWT_SECRET_KEY")
    if not secret:
        raise HTTPException(
            status_code=500,
            detail="JWT_SECRET_KEY is not configured on the backend.",
        )

    header = _encode({"alg": "HS256", "typ": "JWT"})
    payload = _encode(
        {
            "sub": str(user_id),
            "email": email,
            "exp": int(time.time()) + 60 * 60 * 24,
        }
    )
    signing_input = f"{header}.{payload}"
    signature = hmac.new(
        secret.encode(), signing_input.encode(), hashlib.sha256
    ).digest()
    return f"{signing_input}.{_base64url(signature)}"


def authenticated_user(token: str) -> dict:
    secret = os.getenv("JWT_SECRET_KEY")
    if not secret:
        raise HTTPException(
            status_code=500,
            detail="JWT_SECRET_KEY is not configured on the backend.",
        )

    try:
        header, payload, supplied_signature = token.split(".")
        signing_input = f"{header}.{payload}"
        expected_signature = _base64url(
            hmac.new(
                secret.encode(), signing_input.encode(), hashlib.sha256
            ).digest()
        )
        if not hmac.compare_digest(supplied_signature, expected_signature):
            raise ValueError("Invalid signature")

        claims = json.loads(_base64url_decode(payload))
        if int(claims["exp"]) <= int(time.time()):
            raise ValueError("Expired token")
        user_id = int(claims["sub"])
        email = str(claims["email"]).strip().lower()
        if not email:
            raise ValueError("Missing email")
    except (
        KeyError,
        TypeError,
        ValueError,
        json.JSONDecodeError,
        binascii.Error,
    ) as error:
        raise HTTPException(
            status_code=401, detail="Please sign in again to continue."
        ) from error

    return {"user_id": user_id, "email": email}


def _encode(value: dict) -> str:
    return _base64url(json.dumps(value, separators=(",", ":")).encode())


def _base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def _base64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
