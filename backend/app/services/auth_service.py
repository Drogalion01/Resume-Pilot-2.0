"""
app/services/auth_service.py

JWT creation/decoding, password hashing, Google OAuth token verification,
and helper utilities for user identity.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

# ── Password hashing ──────────────────────────────────────────────────────────

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_context.verify(plain, hashed)


# ── JWT tokens ────────────────────────────────────────────────────────────────


def create_access_token(user_id: str, email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": str(user_id),
        "email": email,
        "iat": datetime.now(timezone.utc),
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_verification_token(email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=24)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "email_verify",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_reset_token(email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=1)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "reset",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT. Returns payload dict or None on failure."""
    try:
        return jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
    except JWTError:
        return None


# ── Google OAuth ──────────────────────────────────────────────────────────────


async def verify_google_token(id_token: str) -> Optional[dict]:
    """
    Verify a Google Sign-In ID token by calling Google's tokeninfo endpoint.
    Returns a normalised user-info dict on success, None on failure.
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
        )

    if resp.status_code != 200:
        return None

    data = resp.json()

    # Validate audience — must match our Google client ID
    if settings.GOOGLE_CLIENT_ID and data.get("aud") != settings.GOOGLE_CLIENT_ID:
        return None

    email = data.get("email")
    if not email:
        return None

    return {
        "google_id": data.get("sub"),
        "email": email.lower(),
        "full_name": data.get("name"),
        "avatar_url": data.get("picture"),
        "email_verified": data.get("email_verified") == "true",
    }


# ── Identity helpers ──────────────────────────────────────────────────────────


def derive_initials(full_name: Optional[str], email: str) -> str:
    """Generate 1–2 character initials for the avatar fallback."""
    if full_name:
        parts = full_name.strip().split()
        if len(parts) >= 2:
            return (parts[0][0] + parts[-1][0]).upper()
        if parts and parts[0]:
            return parts[0][:2].upper()
    return email[:2].upper()
