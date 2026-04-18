"""
app/models/resume.py

Resume, ResumeVersion, AnalysisResult ORM models.
Matches the database schema from the analysis report exactly.
"""
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.tracker import Application


class Resume(Base, TimestampMixin):
    __tablename__ = "resumes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── File metadata ────────────────────────────────────────────────────────────
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    original_filename: Mapped[Optional[str]] = mapped_column(
        String(255), nullable=True
    )
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_type: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # pdf|docx|txt

    # ── Content ──────────────────────────────────────────────────────────────────
    raw_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    parsed_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    is_master: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Relationships ────────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="resumes")
    versions: Mapped[list["ResumeVersion"]] = relationship(
        "ResumeVersion", back_populates="resume", cascade="all, delete-orphan"
    )
    analysis_results: Mapped[list["AnalysisResult"]] = relationship(
        "AnalysisResult",
        back_populates="resume",
        foreign_keys="[AnalysisResult.resume_id]",
        cascade="all, delete-orphan",
    )


class ResumeVersion(Base, TimestampMixin):
    __tablename__ = "resume_versions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    resume_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resumes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Metadata ─────────────────────────────────────────────────────────────────
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content_json: Mapped[dict] = mapped_column(JSONB, nullable=False)  # Tailored resume JSON
    job_title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    job_description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    company_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    generation_mode: Mapped[str] = mapped_column(
        String(20), default="manual", nullable=False
    )  # manual | tailored
    generated_from_resume_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resumes.id", ondelete="SET NULL"),
        nullable=True,
    )
    generation_metadata: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # ── Relationships ────────────────────────────────────────────────────────────
    resume: Mapped["Resume"] = relationship("Resume", back_populates="versions")
    analysis_results: Mapped[list["AnalysisResult"]] = relationship(
        "AnalysisResult",
        back_populates="resume_version",
        foreign_keys="[AnalysisResult.resume_version_id]",
        cascade="all, delete-orphan",
    )
    applications: Mapped[list["Application"]] = relationship(
        "Application", back_populates="resume_version"
    )


class AnalysisResult(Base, TimestampMixin):
    __tablename__ = "analysis_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    resume_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resumes.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    resume_version_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resume_versions.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Scores ───────────────────────────────────────────────────────────────────
    ats_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    recruiter_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    overall_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # ── Breakdown & Insights ─────────────────────────────────────────────────────
    score_breakdown: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    issues: Mapped[Optional[list]] = mapped_column(JSONB, nullable=True)
    suggestions: Mapped[Optional[list]] = mapped_column(JSONB, nullable=True)
    matched_keywords: Mapped[Optional[list]] = mapped_column(JSONB, nullable=True)
    missing_keywords: Mapped[Optional[list]] = mapped_column(JSONB, nullable=True)

    # ── Job context (if this analysis was for a specific job) ────────────────────
    job_title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    model_used: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # ── Relationships ────────────────────────────────────────────────────────────
    resume: Mapped["Resume"] = relationship(
        "Resume",
        back_populates="analysis_results",
        foreign_keys=[resume_id],
    )
    resume_version: Mapped[Optional["ResumeVersion"]] = relationship(
        "ResumeVersion",
        back_populates="analysis_results",
        foreign_keys=[resume_version_id],
    )
