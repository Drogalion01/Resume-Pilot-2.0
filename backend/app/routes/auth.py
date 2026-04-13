"""
app/routes/auth.py

Authentication endpoints:
  POST /auth/register       — email/password registration
  POST /auth/login          — email/password login
  POST /auth/google         — Google OAuth (idToken from mobile client)
  POST /auth/verify-email   — email verification link handler
  POST /auth/forgot-password
  POST /auth/reset-password
  POST /auth/refresh        — issue new JWT using current valid token
  GET  /auth/me             — get current user
  POST /auth/logout         — client-side token discard (stateless JWT)
  POST /auth/onboarding     — complete onboarding (set name, target roles)
"""
import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.limiter import limiter
from app.models.user import User, UserSettings
from app.schemas.auth import (
    CompleteOnboardingRequest,
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    MeResponse,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserOut,
    VerifyEmailRequest,
)
from app.schemas.common import MessageResponse
from app.services import auth_service, email_service

router = APIRouter()


# ─────────────────────────────────────────────────────────────────────────────
# Register
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(
    request: Request,
    body: RegisterRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    email = body.email.lower().strip()

    result = await db.execute(select(User).where(User.email == email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "EMAIL_EXISTS", "message": "An account with this email already exists."},
        )

    verify_token = auth_service.create_verification_token(email)
    user = User(
        id=uuid.uuid4(),
        email=email,
        password_hash=auth_service.hash_password(body.password),
        full_name=body.full_name,
        initials=auth_service.derive_initials(body.full_name, email),
        email_verify_token=verify_token,
        plan="free",
    )
    db.add(user)
    db.add(UserSettings(id=uuid.uuid4(), user_id=user.id))
    await db.commit()
    await db.refresh(user)

    background_tasks.add_task(
        email_service.send_verification_email,
        user.email,
        verify_token,
        user.full_name,
    )

    token = auth_service.create_access_token(str(user.id), user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


# ─────────────────────────────────────────────────────────────────────────────
# Login
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    email = body.email.lower().strip()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_CREDENTIALS", "message": "Invalid email or password."},
        )
    if not auth_service.verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_CREDENTIALS", "message": "Invalid email or password."},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DISABLED", "message": "Your account has been disabled."},
        )

    token = auth_service.create_access_token(str(user.id), user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


# ─────────────────────────────────────────────────────────────────────────────
# Google OAuth
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/google", response_model=TokenResponse)
@limiter.limit("10/minute")
async def google_auth(
    request: Request,
    body: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    google_info = await auth_service.verify_google_token(body.id_token)
    if not google_info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_GOOGLE_TOKEN", "message": "Could not verify Google credentials."},
        )

    # 1. Try find by google_id
    result = await db.execute(select(User).where(User.google_id == google_info["google_id"]))
    user = result.scalar_one_or_none()

    if not user:
        # 2. Try find by email (link Google to existing account)
        result = await db.execute(select(User).where(User.email == google_info["email"]))
        user = result.scalar_one_or_none()

        if user:
            user.google_id = google_info["google_id"]
            if not user.avatar_url and google_info.get("avatar_url"):
                user.avatar_url = google_info["avatar_url"]
        else:
            # 3. Create new user
            user = User(
                id=uuid.uuid4(),
                email=google_info["email"],
                google_id=google_info["google_id"],
                full_name=google_info.get("full_name"),
                avatar_url=google_info.get("avatar_url"),
                initials=auth_service.derive_initials(
                    google_info.get("full_name"), google_info["email"]
                ),
                email_verified=google_info.get("email_verified", True),
                plan="free",
            )
            db.add(user)
            db.add(UserSettings(id=uuid.uuid4(), user_id=user.id))

    await db.commit()
    await db.refresh(user)

    token = auth_service.create_access_token(str(user.id), user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


# ─────────────────────────────────────────────────────────────────────────────
# Email verification
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(body: VerifyEmailRequest, db: AsyncSession = Depends(get_db)):
    payload = auth_service.decode_token(body.token)
    if not payload or payload.get("type") != "email_verify":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "INVALID_TOKEN", "message": "Invalid or expired verification link."},
        )

    email = payload.get("sub")
    result = await db.execute(
        select(User).where(User.email == email, User.email_verify_token == body.token)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "INVALID_TOKEN", "message": "Invalid or expired verification link."},
        )

    user.email_verified = True
    user.email_verify_token = None
    await db.commit()

    return MessageResponse(message="Email verified successfully. Welcome to ResumePilot!")


# ─────────────────────────────────────────────────────────────────────────────
# Password reset
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("3/minute")
async def forgot_password(
    request: Request,
    body: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    email = body.email.lower().strip()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    # Always return success — never leak whether email exists
    if user and user.password_hash:
        reset_token = auth_service.create_reset_token(email)
        user.reset_password_token = reset_token
        await db.commit()
        background_tasks.add_task(
            email_service.send_password_reset_email, email, reset_token
        )

    return MessageResponse(
        message="If an account with that email exists, a password reset link has been sent."
    )


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(body: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    payload = auth_service.decode_token(body.token)
    if not payload or payload.get("type") != "reset":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "INVALID_TOKEN", "message": "Invalid or expired reset link."},
        )

    email = payload.get("sub")
    result = await db.execute(
        select(User).where(User.email == email, User.reset_password_token == body.token)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "INVALID_TOKEN", "message": "Invalid or expired reset link."},
        )

    user.password_hash = auth_service.hash_password(body.new_password)
    user.reset_password_token = None
    await db.commit()

    return MessageResponse(message="Password reset successfully. You can now log in.")


# ─────────────────────────────────────────────────────────────────────────────
# Token refresh / Me / Logout / Onboarding
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(current_user: User = Depends(get_current_user)):
    """Issue a fresh JWT for a still-valid token (sliding window refresh)."""
    token = auth_service.create_access_token(str(current_user.id), current_user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(current_user))


@router.get("/me", response_model=MeResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return MeResponse(user=UserOut.model_validate(current_user))


@router.post("/logout", response_model=MessageResponse)
async def logout(current_user: User = Depends(get_current_user)):
    # JWT is stateless — client discards the token.
    # Future: add token to a Redis blacklist for immediate revocation.
    return MessageResponse(message="Logged out successfully.")


@router.post("/onboarding", response_model=TokenResponse)
async def complete_onboarding(
    body: CompleteOnboardingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Complete onboarding: set display name + target roles."""
    current_user.full_name = body.full_name.strip()
    current_user.initials = auth_service.derive_initials(body.full_name, current_user.email)
    current_user.onboarding_completed = True

    if body.target_roles and current_user.settings:
        current_user.settings.target_roles = body.target_roles

    await db.commit()
    await db.refresh(current_user)

    token = auth_service.create_access_token(str(current_user.id), current_user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(current_user))
