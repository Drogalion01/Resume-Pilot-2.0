"""
app/models/user.py

User and UserSettings ORM models.
Auth: email/password + Google OAuth (no phone/BDApps).
Subscription: plan field ("free" | "pro") with gate hook wired but open in MVP.
"""
import uuid
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import JSON, Boolean, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.resume import Resume
    from app.models.tracker import Application


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    full_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )

    # ── Auth ──────────────────────────────────────────────────────────────────
    password_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    google_id: Mapped[Optional[str]] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )

    # ── Profile ───────────────────────────────────────────────────────────────
    avatar_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    initials: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    # ── Email verification ────────────────────────────────────────────────────
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    email_verify_token: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )
    reset_password_token: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )

    # ── Subscription plan (gate hook — open access in MVP) ────────────────────
    # Values: "free" | "pro"  — gate enforcement is in dependencies.require_pro()
    plan: Mapped[str] = mapped_column(String(50), default="free", nullable=False)

    # ── State ─────────────────────────────────────────────────────────────────
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    # ── Relationships ─────────────────────────────────────────────────────────
    settings: Mapped["UserSettings"] = relationship(
        "UserSettings",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    resumes: Mapped[List["Resume"]] = relationship(
        "Resume", back_populates="user", cascade="all, delete-orphan"
    )
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="user", cascade="all, delete-orphan"
    )


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

    # ── Preferences ───────────────────────────────────────────────────────────
    theme_preference: Mapped[str] = mapped_column(
        String(20), default="system", nullable=False
    )
    email_notifications_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    interview_reminders_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    marketing_emails_enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    # e.g. ["Software Engineer", "Backend Developer"]
    target_roles: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # ── Relationship ──────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="settings")
