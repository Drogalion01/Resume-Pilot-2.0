"""
app/schemas/auth.py

Request and response schemas for the /auth endpoints.
"""
import uuid
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


# ── Requests ──────────────────────────────────────────────────────────────────


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: Optional[str] = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long.")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    """Google Sign-In: client passes the idToken from google_sign_in package."""
    id_token: str


class VerifyEmailRequest(BaseModel):
    token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long.")
        return v


class CompleteOnboardingRequest(BaseModel):
    full_name: str
    target_roles: Optional[list[str]] = None


# ── Responses ─────────────────────────────────────────────────────────────────


class UserOut(BaseModel):
    """Public user representation — never exposes password_hash, tokens."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    initials: Optional[str] = None
    email_verified: bool
    plan: str          # "free" | "pro"
    is_active: bool
    onboarding_completed: bool


class TokenResponse(BaseModel):
    """JWT token + embedded user object."""
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class MeResponse(BaseModel):
    """Response for GET /auth/me — just the user, no new token."""
    user: UserOut
