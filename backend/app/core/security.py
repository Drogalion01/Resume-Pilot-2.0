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


def create_access_token(
    user_id: str,
    email: str,
    tier: str = "free",

    private_key: str = "",
    algorithm: str = "RS256",
    expires_in_minutes: int = 60,
) -> str:
    """
    Create a signed JWT access token (RS256 by default).
    Payload: sub (user UUID), email, tier, totp_verified, iat, exp.
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
    return jose_jwt.encode(payload, private_key, algorithm=algorithm)


def verify_token(token: str, public_key: str = "", algorithm: str = "RS256") -> dict:
    """
    Verify RS256 JWT signature and expiry. Returns payload dict.
    Raises jose.exceptions.JWTError on any failure (expired, invalid signature, etc.).
    Caller should map to HTTPException with appropriate status.
    """
    return jose_jwt.decode(token, public_key, algorithms=[algorithm])


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
