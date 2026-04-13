"""
app/models/tracker.py

Application, Interview, Reminder, Note, TimelineEvent ORM models.
Complete job tracking pipeline with automatic timeline audit trail.
"""
import enum
import uuid
from datetime import date
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import JSON, Boolean, Date, Enum as SAEnum, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.resume import ResumeVersion
    from app.models.user import User


# ── Enums ─────────────────────────────────────────────────────────────────────


class ApplicationStatus(str, enum.Enum):
    SAVED = "saved"
    APPLIED = "applied"
    ASSESSMENT = "assessment"
    HR = "hr"
    TECHNICAL = "technical"
    FINAL = "final"
    OFFER = "offer"
    REJECTED = "rejected"


class InterviewType(str, enum.Enum):
    PHONE = "phone"
    VIDEO = "video"
    ONSITE = "onsite"


class InterviewStatus(str, enum.Enum):
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    RESCHEDULED = "rescheduled"
    CANCELLED = "cancelled"


# ── Models ────────────────────────────────────────────────────────────────────


class Application(Base, TimestampMixin):
    __tablename__ = "applications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    resume_version_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resume_versions.id", ondelete="SET NULL"),
        nullable=True,
    )

    # ── Core fields ───────────────────────────────────────────────────────────
    company_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[ApplicationStatus] = mapped_column(
        SAEnum(ApplicationStatus), default=ApplicationStatus.SAVED, nullable=False
    )
    application_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    # ── Details ───────────────────────────────────────────────────────────────
    source: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    job_url: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    salary_range: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    recruiter_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    recruiter_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    notes_summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="applications")
    resume_version: Mapped[Optional["ResumeVersion"]] = relationship(
        "ResumeVersion", back_populates="applications"
    )
    interviews: Mapped[List["Interview"]] = relationship(
        "Interview", back_populates="application", cascade="all, delete-orphan"
    )
    reminders: Mapped[List["Reminder"]] = relationship(
        "Reminder", back_populates="application", cascade="all, delete-orphan"
    )
    notes: Mapped[List["Note"]] = relationship(
        "Note", back_populates="application", cascade="all, delete-orphan"
    )
    timeline_events: Mapped[List["TimelineEvent"]] = relationship(
        "TimelineEvent",
        back_populates="application",
        cascade="all, delete-orphan",
        order_by="TimelineEvent.created_at.desc()",
    )


class Interview(Base, TimestampMixin):
    __tablename__ = "interviews"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    application_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("applications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    round_name: Mapped[str] = mapped_column(String(255), nullable=False)
    interview_type: Mapped[InterviewType] = mapped_column(
        SAEnum(InterviewType), default=InterviewType.VIDEO, nullable=False
    )
    status: Mapped[InterviewStatus] = mapped_column(
        SAEnum(InterviewStatus), default=InterviewStatus.SCHEDULED, nullable=False
    )
    interview_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    interview_time: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    timezone: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True, default="UTC"
    )
    interviewer_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    meeting_link: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reminder_enabled: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )

    application: Mapped["Application"] = relationship(
        "Application", back_populates="interviews"
    )


class Reminder(Base, TimestampMixin):
    __tablename__ = "reminders"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    application_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("applications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    remind_at: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )  # ISO 8601 datetime string
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    application: Mapped["Application"] = relationship(
        "Application", back_populates="reminders"
    )


class Note(Base, TimestampMixin):
    __tablename__ = "notes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    application_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("applications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)

    application: Mapped["Application"] = relationship(
        "Application", back_populates="notes"
    )


class TimelineEvent(Base, TimestampMixin):
    __tablename__ = "timeline_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    application_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("applications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # e.g. "application_created" | "status_changed" | "interview_scheduled" | "reminder_completed"
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    application: Mapped["Application"] = relationship(
        "Application", back_populates="timeline_events"
    )
