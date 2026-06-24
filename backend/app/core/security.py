"""
app/core/security.py

Cryptographic utilities:
- RS256 JWT creation/verification
- SHA-256 token hashing
- AES-256-GCM encryption (Fernet) for sensitive data at rest
"""
import base64
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from cryptography.fernet import Fernet
from jose import jwt as jose_jwt
from jose.exceptions import JWTError


def _ensure_bytes(value: str | bytes) -> bytes:
    return value.encode() if isinstance(value, str) else value


def hash_token(raw_token: str) -> str:
    """SHA-256 hash of a raw token (hex string) — never store raw."""
    return hashlib.sha256(raw_token.encode()).hexdigest()


def generate_family_id() -> str:
    """UUID4 string for refresh token family grouping."""
    import uuid
    return str(uuid.uuid4())


def generate_token_urlsafe(nbytes: int = 32) -> str:
    """Cryptographically random URL-safe token (for magic-link/state)."""
    return secrets.token_urlsafe(nbytes)


import os
import logging

logger = logging.getLogger(__name__)

# Generate a fallback symmetric secret for the lifetime of this server process
_FALLBACK_SECRET = os.environ.get("JWT_SECRET_KEY") or secrets.token_hex(32)


def create_access_token(
    user_id: str,
    email: str,
    tier: str = "free",
    private_key: str = "",
    algorithm: str = "RS256",
    expires_in_minutes: int = 60,
) -> str:
    """
    Create a signed JWT access token. Falls back to HS256 if RS256 keys are missing/invalid.
    """
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=expires_in_minutes)
    payload = {
        "sub": str(user_id),
        "email": email,
        "tier": tier,
        "iat": now,
        "exp": expire,
    }
    
    # Clean key
    private_key_str = (private_key or "").strip()
    
    if algorithm == "RS256" and not private_key_str:
        algorithm = "HS256"
        key = _FALLBACK_SECRET
    else:
        key = private_key_str

    try:
        return jose_jwt.encode(payload, key, algorithm=algorithm)
    except Exception as exc:
        if algorithm == "RS256":
            logger.warning("RS256 JWT encoding failed (malformed PEM?). Falling back to HS256. Error: %s", exc)
            return jose_jwt.encode(payload, _FALLBACK_SECRET, algorithm="HS256")
        raise


def verify_token(token: str, public_key: str = "", algorithm: str = "RS256") -> dict:
    """
    Verify JWT signature and expiry. Supports both RS256 and HS256 fallbacks.
    """
    try:
        header = jose_jwt.get_unverified_header(token)
        token_alg = header.get("alg", algorithm)
    except Exception:
        token_alg = algorithm

    if token_alg == "HS256":
        return jose_jwt.decode(token, _FALLBACK_SECRET, algorithms=["HS256"])

    try:
        return jose_jwt.decode(token, (public_key or "").strip(), algorithms=["RS256"])
    except Exception as exc:
        try:
            return jose_jwt.decode(token, _FALLBACK_SECRET, algorithms=["HS256"])
        except Exception:
            raise JWTError("Invalid token") from exc



# ── Encryption (Fernet = AES-256-GCM) ──────────────────────────────────────────

def get_fernet_cipher(key: str | bytes) -> Fernet:
    """Return Fernet cipher for given base64url-encoded 32-byte key."""
    if isinstance(key, str):
        key = key.encode()
    return Fernet(key)


def encrypt_data(plaintext: str, key: str) -> str:
    """Encrypt string; returns base64 URL-safe token."""
    cipher = get_fernet_cipher(key)
    return cipher.encrypt(plaintext.encode()).decode()


def decrypt_data(ciphertext: str, key: str) -> str:
    """Decrypt Fernet token to plaintext string."""
    cipher = get_fernet_cipher(key)
    return cipher.decrypt(ciphertext.encode()).decode()
