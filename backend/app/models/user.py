"""
app/models/user.py

User, UserSettings, OAuthAccount, MagicLinkToken, RefreshToken ORM models.

Auth: Passwordless — magic link + OAuth + optional TOTP 2FA.
Subscription: tier field ("free" | "pro" | "premium") with generation limits.
"""
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import Boolean, DateTime, String, Text, JSON, ForeignKey, UniqueConstraint, UUID as PGUUID
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.resume import Resume
    from app.models.tracker import Application


# ────────────────────────────────────────────────────────────────────────────────
# User
# ────────────────────────────────────────────────────────────────────────────────

class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # ── Identity ─────────────────────────────────────────────────────────────────
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    full_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    initials: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # ── Email verification ───────────────────────────────────────────────────────
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Account state ────────────────────────────────────────────────────────────
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    # ── Subscription & usage ─────────────────────────────────────────────────────
    subscription_tier: Mapped[str] = mapped_column(
        String(20), default="free", nullable=False
    )
    subscription_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    paddle_customer_id: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True, index=True
    )
    generation_count_this_month: Mapped[int] = mapped_column(
        default=0, nullable=False
    )
    generation_reset_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Login tracking ────────────────────────────────────────────────────────────
    last_login_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_login_ip: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)

    # ── TOTP 2FA ─────────────────────────────────────────────────────────────────
    totp_secret: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # ENCRYPTED
    totp_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    backup_codes_hash: Mapped[Optional[List[str]]] = mapped_column(JSONB, nullable=True)

    # ── Relationships ────────────────────────────────────────────────────────────
    settings: Mapped["UserSettings"] = relationship(
        "UserSettings",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    oauth_accounts: Mapped[List["OAuthAccount"]] = relationship(
        "OAuthAccount",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    magic_link_tokens: Mapped[List["MagicLinkToken"]] = relationship(
        "MagicLinkToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    refresh_tokens: Mapped[List["RefreshToken"]] = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    resumes: Mapped[List["Resume"]] = relationship(
        "Resume", back_populates="user", cascade="all, delete-orphan"
    )
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="user", cascade="all, delete-orphan"
    )


# ────────────────────────────────────────────────────────────────────────────────
# UserSettings
# ────────────────────────────────────────────────────────────────────────────────

class UserSettings(Base, TimestampMixin):
    __tablename__ = "user_settings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )

    theme_preference: Mapped[str] = mapped_column(String(20), default="dark", nullable=False)
    email_notifications_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    interview_reminders_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    marketing_emails_enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    target_roles: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="settings")


# ────────────────────────────────────────────────────────────────────────────────
# OAuthAccount — linked external identities
# ────────────────────────────────────────────────────────────────────────────────

class OAuthAccount(Base, TimestampMixin):
    __tablename__ = "oauth_accounts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(String(30), nullable=False)  # google/github/linkedin
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)
    access_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # ENCRYPTED
    refresh_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # ENCRYPTED
    token_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    scope: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="oauth_accounts")

    __table_args__ = (
        UniqueConstraint('provider', 'provider_user_id', name='uq_oauth_provider_user_id'),
    )


# ────────────────────────────────────────────────────────────────────────────────
# MagicLinkToken — passwordless email token
# ────────────────────────────────────────────────────────────────────────────────

class MagicLinkToken(Base, TimestampMixin):
    __tablename__ = "magic_link_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False)  # the email that requested
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    purpose: Mapped[str] = mapped_column(String(30), nullable=False)  # "login" | "email_verify"
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="magic_link_tokens")


# ────────────────────────────────────────────────────────────────────────────────
# RefreshToken — rotating refresh tokens with family tracking
# ────────────────────────────────────────────────────────────────────────────────

class RefreshToken(Base, TimestampMixin):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    family_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    revoked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="refresh_tokens")
