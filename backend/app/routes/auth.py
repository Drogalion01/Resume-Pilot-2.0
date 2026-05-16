"""
app/routes/auth.py — Passwordless authentication
"""
import logging
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.dependencies import CurrentUser, get_db
from app.core.exceptions import AuthenticationError
from app.limiter import limiter
from app.models.user import OAuthAccount, RefreshToken, User
from app.schemas.auth import (
    AuthResponse,
    MFARequiredResponse,
    OAuthAuthorizeRequest,
    OAuthCallbackRequest,
    RefreshTokenRequest,
    TOTPConfirmRequest,
    TOTPSetupResponse,
    TOTPVerifyRequest,
)
from app.schemas.user import CompleteOnboardingRequest, MeResponse
from app.services import auth_service, email_service

router = APIRouter(prefix="/auth", tags=["Auth"])
logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════════════
# Magic Link
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/magic-link/send", status_code=status.HTTP_200_OK)
@limiter.limit("5/minute")
async def magic_link_send(
    request: Request,
    email: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    try:
        await auth_service.send_magic_link(
            email=email,
            ip_address=request.client.host if request.client else "0.0.0.0",
            db=db,
        )
        return {"message": "Magic link sent", "expires_in": 900}
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Magic link send failed")
        raise HTTPException(status_code=500, detail="Failed to send magic link")


@router.post("/magic-link/verify", response_model=AuthResponse | MFARequiredResponse)
async def magic_link_verify(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    try:
        user, mfa_required = await auth_service.verify_magic_link(token, db)
    except Exception as exc:
        logger.warning("Magic link verify failed: %s", exc)
        raise HTTPException(status_code=401, detail=str(exc))

    if mfa_required:
        mfa_token = auth_service.create_access_token(
            user_id=str(user.id),
            email=user.email,
            tier=user.subscription_tier,
            totp_verified=False,
            private_key=settings.JWT_PRIVATE_KEY,
            algorithm=settings.JWT_ALGORITHM,
            expires_delta_minutes=5,
        )
        return MFARequiredResponse(mfa_token=mfa_token)

    access = await auth_service.issue_access_token(user, totp_verified=True)
    refresh, _ = await auth_service.issue_refresh_token(user, "0.0.0.0", db)
    return AuthResponse(
        access_token=access,
        refresh_token=refresh,
        user=MeResponse.user.model_validate(user),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# OAuth
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/oauth/{provider}/authorize", response_model=dict)
async def oauth_authorize(provider: str, redirect_uri: str):
    if provider not in ("google", "github", "linkedin"):
        raise HTTPException(status_code=400, detail="Unsupported provider")

    state, _ = await auth_service.generate_oauth_state(provider)

    if provider == "google":
        auth_url = (
            "https://accounts.google.com/o/oauth2/v2/auth?"
            f"client_id={settings.GOOGLE_CLIENT_ID}"
            "&response_type=code&scope=openid%20email%20profile"
            f"&redirect_uri={redirect_uri}&state={state}&access_type=offline"
        )
    elif provider == "github":
        auth_url = (
            "https://github.com/login/oauth/authorize?"
            f"client_id={settings.GITHUB_CLIENT_ID}"
            "&scope=read:user%20user:email"
            f"&redirect_uri={redirect_uri}&state={state}"
        )
    else:
        auth_url = (
            "https://www.linkedin.com/oauth/v2/authorization?"
            f"client_id={settings.LINKEDIN_CLIENT_ID}"
            "&response_type=code&scope=openid%20profile%20email"
            f"&redirect_uri={redirect_uri}&state={state}"
        )

    return {"authorization_url": auth_url, "state": state}


@router.post("/oauth/{provider}/callback", response_model=AuthResponse | MFARequiredResponse)
async def oauth_callback(
    provider: str,
    body: OAuthCallbackRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    try:
        tokens = await auth_service.exchange_code_for_tokens(provider, body.code, body.redirect_uri)
        access_token = tokens.get("access_token")
        if not access_token:
            raise AuthenticationError("No access token from provider")
        profile = await auth_service.get_oauth_userinfo(provider, access_token)
    except Exception as exc:
        logger.error("OAuth callback error: %s", exc)
        raise HTTPException(status_code=401, detail="OAuth failed")

    user = await auth_service.upsert_oauth_user(
        provider=provider,
        provider_user_id=profile["provider_user_id"],
        email=profile["email"],
        full_name=profile.get("full_name"),
        avatar_url=profile.get("avatar_url"),
        email_verified=profile.get("email_verified", False),
        db=db,
    )

    if user.totp_enabled:
        mfa_token = auth_service.create_access_token(
            user_id=str(user.id),
            email=user.email,
            tier=user.subscription_tier,
            totp_verified=False,
            private_key=settings.JWT_PRIVATE_KEY,
            algorithm=settings.JWT_ALGORITHM,
            expires_delta_minutes=5,
        )
        return MFARequiredResponse(mfa_token=mfa_token)

    access = await auth_service.issue_access_token(user, totp_verified=True)
    refresh, _ = await auth_service.issue_refresh_token(user, request.client.host if request.client else "0.0.0.0", db)
    return AuthResponse(
        access_token=access,
        refresh_token=refresh,
        user=MeResponse.user.model_validate(user),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# TOTP 2FA
# ═══════════════════════════════════════════════════════════════════════════════

# Note: Some TOTP endpoints require an mfa_token (short-lived JWT with scope=mfa_pending)
# For MVP we'll accept mfa_token as query param or header via custom dependency. Simplify: as query.

@router.post("/totp/verify", response_model=AuthResponse)
async def totp_verify(
    code: str,
    mfa_token: str,
    db: AsyncSession = Depends(get_db),
):
    user = await auth_service.verify_totp_challenge(mfa_token, code, db)
    access = await auth_service.issue_access_token(user, totp_verified=True)
    refresh, _ = await auth_service.issue_refresh_token(user, "0.0.0.0", db)
    return AuthResponse(
        access_token=access,
        refresh_token=refresh,
        user=MeResponse.user.model_validate(user),
    )


@router.get("/totp/setup", response_model=TOTPSetupResponse)
async def totp_setup(current_user: CurrentUser):
    data = auth_service.generate_totp_setup()
    import pyotp
    totp = pyotp.TOTP(data["secret"])
    data["otpauth_uri"] = totp.provisioning_uri(
        name=current_user.email,
        issuer_name="ResumePilot",
    )
    return TOTPSetupResponse(**data)


@router.post("/totp/setup/confirm", response_model=dict)
async def totp_setup_confirm(
    secret: str,
    code: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Confirm TOTP setup. Frontend sends the secret (from /totp/setup) and first code."""
    import pyotp
    totp = pyotp.TOTP(secret)
    if not totp.verify(code, valid_window=1):
        raise HTTPException(status_code=400, detail="Invalid verification code")

    encrypted_secret = auth_service.encrypt_data(secret, settings.TOKEN_ENCRYPTION_KEY)
    current_user.totp_secret = encrypted_secret
    current_user.totp_enabled = True
    current_user.backup_codes_hash = auth_service.hash_backup_codes([secrets.token_hex(4).upper() for _ in range(10)])  # placeholder
    await db.commit()
    return {"totp_enabled": True, "message": "TOTP enabled"}


@router.delete("/totp/disable", response_model=dict)
async def totp_disable(
    code: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    if not current_user.totp_secret:
        raise HTTPException(status_code=400, detail="TOTP not enabled")
    secret = auth_service.decrypt_data(current_user.totp_secret, settings.TOKEN_ENCRYPTION_KEY)
    if not auth_service.verify_totp_code(secret, code):
        raise HTTPException(status_code=400, detail="Invalid code")
    current_user.totp_enabled = False
    current_user.totp_secret = None
    current_user.backup_codes_hash = None
    await db.commit()
    return {"totp_enabled": False}


# ═══════════════════════════════════════════════════════════════════════════════
# Token Refresh & Revocation
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/token/refresh", response_model=AuthResponse)
async def refresh_token(
    body: RefreshTokenRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    try:
        new_access, new_refresh = await auth_service.rotate_refresh_token(
            body.refresh_token,
            request.client.host if request.client else "0.0.0.0",
            db,
        )
        payload = jwt.decode(new_access, settings.JWT_PUBLIC_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = payload["sub"]
        user = await db.get(User, uuid.UUID(str(user_id)))
        if not user:
            raise AuthenticationError("User not found")
        return AuthResponse(
            access_token=new_access,
            refresh_token=new_refresh,
            user=MeResponse.user.model_validate(user),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Refresh token error")
        raise HTTPException(status_code=401, detail="Invalid refresh token")


@router.post("/token/revoke", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_token(
    body: RefreshTokenRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    revoked = await auth_service.revoke_refresh_token(body.refresh_token, db)
    if not revoked:
        raise HTTPException(status_code=404, detail="Token not found")
    return None


@router.post("/token/revoke-all", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_all_tokens(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    count = await auth_service.revoke_all_refresh_tokens(current_user.id, db)
    logger.info("Revoked %d tokens for user %s", count, current_user.id)
    return None


# ═══════════════════════════════════════════════════════════════════════════════
# Current User & Onboarding
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/me", response_model=MeResponse)
async def get_me(current_user: CurrentUser):
    return MeResponse(user=MeResponse.user.model_validate(current_user))


@router.post("/onboarding", response_model=AuthResponse)
async def complete_onboarding(
    body: CompleteOnboardingRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    current_user.full_name = body.full_name.strip()
    current_user.initials = auth_service.derive_initials(body.full_name, current_user.email)
    current_user.onboarding_completed = True
    if body.target_roles and current_user.settings:
        current_user.settings.target_roles = body.target_roles
    await db.commit()
    await db.refresh(current_user)

    access = await auth_service.issue_access_token(current_user, totp_verified=current_user.totp_enabled)
    refresh, _ = await auth_service.issue_refresh_token(current_user, "0.0.0.0", db)
    return AuthResponse(
        access_token=access,
        refresh_token=refresh,
        user=MeResponse.user.model_validate(current_user),
    )
