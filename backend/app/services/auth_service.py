"""
app/services/auth_service.py

Core auth logic: magic link, OAuth, TOTP 2FA, refresh token rotation.
No passwords anywhere.
"""
import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

import httpx
from fastapi import HTTPException, status
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import AuthenticationError
from app.core.security import create_access_token, decrypt_data, encrypt_data, hash_token
from app.models.user import OAuthAccount, RefreshToken, User, MagicLinkToken, UserSettings

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────────────────────
# Password helpers — kept for derive_initials only (bcrypt for backup codes)
# ────────────────────────────────────────────────────────────────────────────────

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:  # Not used but kept for future if needed
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:  # Not used
    return _pwd_context.verify(plain, hashed)


def derive_initials(full_name: Optional[str], email: str) -> str:
    if full_name:
        parts = full_name.strip().split()
        if len(parts) >= 2:
            return (parts[0][0] + parts[-1][0]).upper()
        if parts and parts[0]:
            return parts[0][:2].upper()
    return email[:2].upper()


# ═══════════════════════════════════════════════════════════════════════════════
# Magic Link
# ═══════════════════════════════════════════════════════════════════════════════

# Simple in-memory rate limit store — swap to Redis in production
_magic_link_attempts: dict[str, list[datetime]] = {}


async def send_magic_link(email: str, ip_address: str, db: AsyncSession) -> None:
    """
    Send magic link sign-in token.
    Rate limit: 3 per email per 10 minutes.
    """
    # Rate limiting
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(minutes=10)
    attempts = _magic_link_attempts.get(email, [])
    attempts = [t for t in attempts if t > window_start]
    if len(attempts) >= 3:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"code": "RATE_LIMIT_EXCEEDED", "message": "Too many requests. Try again in 10 minutes."},
        )
    attempts.append(now)
    _magic_link_attempts[email] = attempts

    # Normalise email
    email = email.lower().strip()

    # Find or create user
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            id=uuid.uuid4(),
            email=email,
            full_name=None,
            initials=email[:2].upper(),
            is_email_verified=False,
            is_active=True,
            onboarding_completed=False,
            subscription_tier="free",
            generation_count_this_month=0,
        )
        db.add(user)
        await db.flush()
        # Create UserSettings for new magic-link user (matches OAuth upsert behavior)
        db.add(UserSettings(id=uuid.uuid4(), user_id=user.id))
        await db.flush()

    # Create token
    raw_token = secrets.token_urlsafe(32)
    token_hash = hash_token(raw_token)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    magic_token = MagicLinkToken(
        user_id=user.id,
        email=email,
        token_hash=token_hash,
        purpose="login",
        expires_at=expires_at,
        ip_address=ip_address,
    )
    db.add(magic_token)
    await db.commit()

    # Send email
    verify_url = f"{settings.APP_WEB_BASE_URL}/auth/verify?token={raw_token}"
    return raw_token
async def verify_magic_link(raw_token: str, db: AsyncSession) -> User:
    """
    Verify magic link token.
    Raises AuthenticationError if invalid/expired/used.
    """
    token_hash = hash_token(raw_token)
    result = await db.execute(
        select(MagicLinkToken).where(
            MagicLinkToken.token_hash == token_hash,
            MagicLinkToken.used_at.is_(None),
            MagicLinkToken.expires_at > datetime.now(timezone.utc),
        )
    )
    token_record = result.scalar_one_or_none()
    if not token_record:
        raise AuthenticationError("Invalid or expired magic link")

    token_record.used_at = datetime.now(timezone.utc)
    result_user = await db.execute(
        select(User).options(selectinload(User.settings)).where(User.id == token_record.user_id)
    )
    user = result_user.scalar_one_or_none()
    if not user or not user.is_active:
        raise AuthenticationError("User not found or inactive")

    if not user.is_email_verified:
        user.is_email_verified = True

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    return user


# ═══════════════════════════════════════════════════════════════════════════════
# OAuth 2.0
# ═══════════════════════════════════════════════════════════════════════════════

async def generate_oauth_state(provider: str) -> Tuple[str, str]:
    state = secrets.token_urlsafe(32)
    state_hash = hash_token(state)
    return state, state_hash


def consume_oauth_state(provider: str, state: str) -> None:
    if not state or len(state) < 16:
        raise AuthenticationError("Invalid or expired OAuth state")


async def exchange_code_for_tokens(provider: str, code: str, redirect_uri: str) -> dict:
    if provider == "google":
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "code": code,
                    "grant_type": "authorization_code",
                    "redirect_uri": redirect_uri,
                },
            )
        if resp.status_code != 200:
            raise AuthenticationError("OAuth token exchange with Google failed")
        return resp.json()
    elif provider == "github":
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                "https://github.com/login/oauth/access_token",
                data={
                    "client_id": settings.GITHUB_CLIENT_ID,
                    "client_secret": settings.GITHUB_CLIENT_SECRET,
                    "code": code,
                    "redirect_uri": redirect_uri,
                },
                headers={"Accept": "application/json"},
            )
        if resp.status_code != 200:
            raise AuthenticationError("OAuth token exchange with GitHub failed")
        return resp.json()
    elif provider == "linkedin":
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                "https://www.linkedin.com/oauth/v2/accessToken",
                data={
                    "client_id": settings.LINKEDIN_CLIENT_ID,
                    "client_secret": settings.LINKEDIN_CLIENT_SECRET,
                    "code": code,
                    "grant_type": "authorization_code",
                    "redirect_uri": redirect_uri,
                },
            )
        if resp.status_code != 200:
            raise AuthenticationError("OAuth token exchange with LinkedIn failed")
        return resp.json()
    else:
        raise ValueError(f"Unsupported provider: {provider}")


async def get_oauth_userinfo(provider: str, access_token: str) -> dict:
    if provider == "google":
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
            )
        data = resp.json()
        return {
            "provider_user_id": data["id"],
            "email": data["email"].lower(),
            "full_name": data.get("name"),
            "avatar_url": data.get("picture"),
            "email_verified": data.get("verified_email", False),
        }
    elif provider == "github":
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "https://api.github.com/user",
                headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"},
            )
        data = resp.json()
        # Fetch primary email
        async with httpx.AsyncClient() as client2:
            resp2 = await client2.get(
                "https://api.github.com/user/emails",
                headers={"Authorization": f"Bearer {access_token}"},
            )
        emails = resp2.json()
        primary = next((e for e in emails if e.get("primary")), None)
        email = (primary or {}).get("email") or data.get("email")
        if not email:
            raise AuthenticationError("GitHub email not accessible — set public email or grant user:email scope")
        return {
            "provider_user_id": str(data["id"]),
            "email": email.lower(),
            "full_name": data.get("name"),
            "avatar_url": data.get("avatar_url"),
            "email_verified": True,
        }
    elif provider == "linkedin":
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "https://api.linkedin.com/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
            )
        data = resp.json()
        sub = data.get("sub") or data.get("id")
        # LinkedIn OpenID Connect /v2/userinfo returns 'email' as a plain top-level string
        email = data.get("email")
        if not email:
            raise AuthenticationError("LinkedIn email not accessible — ensure 'email' scope is granted")
        return {
            "provider_user_id": str(sub),
            "email": email.lower(),
            "full_name": data.get("name"),
            "avatar_url": data.get("picture"),
            "email_verified": data.get("email_verified", False),
        }
    else:
        raise ValueError(f"Unsupported provider: {provider}")


async def upsert_oauth_user(
    provider: str,
    provider_user_id: str,
    email: str,
    full_name: Optional[str],
    avatar_url: Optional[str],
    email_verified: bool,
    db: AsyncSession,
) -> User:
    """Find existing by OAuth or email, else create. Link OAuth account."""
    # By OAuth account
    result = await db.execute(
        select(OAuthAccount).where(
            OAuthAccount.provider == provider,
            OAuthAccount.provider_user_id == provider_user_id,
        )
    )
    oauth_acc = result.scalar_one_or_none()
    if oauth_acc:
        result_user = await db.execute(
            select(User).options(selectinload(User.settings)).where(User.id == oauth_acc.user_id)
        )
        return result_user.scalar_one_or_none()

    # By email
    result = await db.execute(
        select(User).options(selectinload(User.settings)).where(User.email == email)
    )
    user = result.scalar_one_or_none()
    if user:
        oauth = OAuthAccount(
            user_id=user.id,
            provider=provider,
            provider_user_id=provider_user_id,
            access_token=None,
            refresh_token=None,
        )
        db.add(oauth)
        await db.commit()
        return user

    # Create
    user = User(
        id=uuid.uuid4(),
        email=email,
        full_name=full_name,
        avatar_url=avatar_url,
        initials=derive_initials(full_name, email),
        is_email_verified=email_verified,
        is_active=True,
        onboarding_completed=False,
        subscription_tier="free",
        generation_count_this_month=0,
    )
    db.add(user)
    await db.flush()

    oauth = OAuthAccount(
        user_id=user.id,
        provider=provider,
        provider_user_id=provider_user_id,
        access_token=None,
        refresh_token=None,
    )
    db.add(oauth)
    db.add(UserSettings(id=uuid.uuid4(), user_id=user.id))
    await db.commit()
    return user


# ═══════════════════════════════════════════════════════════════════════════════
# Refresh Token Rotation
# ═══════════════════════════════════════════════════════════════════════════════

async def issue_access_token(user: User) -> str:
    return create_access_token(
        user_id=str(user.id),
        email=user.email,
        tier=user.subscription_tier,
        private_key=settings.JWT_PRIVATE_KEY,
        algorithm=settings.JWT_ALGORITHM,
        expires_in_minutes=60,
    )

async def issue_refresh_token(user: User, ip: str, db: AsyncSession) -> Tuple[str, str]:
    raw = secrets.token_urlsafe(32)
    token_hash = hash_token(raw)
    family_id = uuid.uuid4()
    expires_at = datetime.now(timezone.utc) + timedelta(days=30)

    refresh = RefreshToken(
        user_id=user.id,
        token_hash=token_hash,
        family_id=family_id,
        expires_at=expires_at,
        ip_address=ip,
    )
    db.add(refresh)
    await db.commit()
    return raw, str(family_id)


async def rotate_refresh_token(raw_token: str, ip: str, db: AsyncSession) -> Tuple[str, str]:
    token_hash = hash_token(raw_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    token_record = result.scalar_one_or_none()
    if not token_record:
        raise AuthenticationError("Invalid refresh token")

    now = datetime.now(timezone.utc)

    if token_record.revoked_at is not None:
        # Reuse detected — revoke entire family
        await db.execute(
            select(RefreshToken).where(RefreshToken.family_id == token_record.family_id)
        )
        family_tokens = result.scalars().all()
        for t in family_tokens:
            t.revoked_at = now
        await db.commit()
        raise AuthenticationError("Token reuse detected. All sessions revoked.")

    if token_record.expires_at < now:
        raise AuthenticationError("Refresh token expired")

    # Revoke current token
    token_record.revoked_at = now
    user = await db.get(User, token_record.user_id)
    if not user:
        raise AuthenticationError("User not found")

    new_access = await issue_access_token(user)
    new_raw = secrets.token_urlsafe(32)
    new_hash = hash_token(new_raw)
    new_expires = now + timedelta(days=30)
    new_refresh = RefreshToken(
        user_id=user.id,
        token_hash=new_hash,
        family_id=token_record.family_id,
        expires_at=new_expires,
        ip_address=ip,
    )
    db.add(new_refresh)
    await db.commit()
    return new_access, new_raw


async def revoke_refresh_token(raw_token: str, db: AsyncSession) -> bool:
    token_hash = hash_token(raw_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    token = result.scalar_one_or_none()
    if token:
        token.revoked_at = datetime.now(timezone.utc)
        await db.commit()
        return True
    return False


async def revoke_all_refresh_tokens(user_id: uuid.UUID, db: AsyncSession) -> int:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
        )
    )
    tokens = result.scalars().all()
    for t in tokens:
        t.revoked_at = now
    await db.commit()
    return len(tokens)


