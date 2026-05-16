"""
app/schemas/auth.py

Request and response schemas for passwordless authentication endpoints.
"""
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ────────────────────────────────────────────────────────────────────────────────
# Requests
# ────────────────────────────────────────────────────────────────────────────────

class MagicLinkSendRequest(BaseModel):
    email: EmailStr


class MagicLinkVerifyRequest(BaseModel):
    token: str = Field(..., min_length=1, description="The raw magic link token from email")


class OAuthAuthorizeRequest(BaseModel):
    provider: str = Field(..., pattern="^(google|github|linkedin)$")
    redirect_uri: str = Field(..., description="App deep link URI, e.g. resumepilot://app/auth/callback/google")


class OAuthCallbackRequest(BaseModel):
    code: str
    state: str
    redirect_uri: str


class TOTPVerifyRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=8, description="6-digit TOTP or 8-char backup code")


class TOTPConfirmRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6, description="6-digit TOTP to confirm setup")


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1)


# ────────────────────────────────────────────────────────────────────────────────
# Responses
# ────────────────────────────────────────────────────────────────────────────────

class UserOut(BaseModel):
    """Public user representation — minimal, safe fields only."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    initials: Optional[str] = None
    email_verified: bool
    subscription_tier: str = Field(..., alias="tier")  # "free" | "pro" | "premium"
    onboarding_completed: bool


class AuthResponse(BaseModel):
    """Successful authentication response."""
    access_token: str
    token_type: str = "bearer"
    refresh_token: str
    user: UserOut


class MFARequiredResponse(BaseModel):
    """Returned when MFA is required to complete login."""
    mfa_token: str
    mfa_required: bool = True


class TOTPSetupResponse(BaseModel):
    secret: str
    otpauth_uri: str
    backup_codes: list[str]


class SubscriptionStatus(BaseModel):
    tier: str
    generation_used: int
    generation_limit: int
    resets_at: Optional[datetime] = None


class SessionInfo(BaseModel):
    """Refresh token family / device session info."""
    id: uuid.UUID
    family_id: uuid.UUID
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime
    expires_at: datetime
    is_revoked: bool

    model_config = ConfigDict(from_attributes=True)
