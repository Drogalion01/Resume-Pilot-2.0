"""
app/models/resume.py

Resume, ResumeVersion, AnalysisResult ORM models.
"""
import uuid
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import JSON, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.tracker import Application
    from app.models.user import User


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
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    original_file_path: Mapped[Optional[str]] = mapped_column(
        String(1000), nullable=True
    )
    file_type: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True
    )  # pdf | docx | txt
    raw_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    parsed_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="resumes")
    versions: Mapped[List["ResumeVersion"]] = relationship(
        "ResumeVersion", back_populates="resume", cascade="all, delete-orphan"
    )
    analysis_results: Mapped[List["AnalysisResult"]] = relationship(
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
    version_name: Mapped[str] = mapped_column(
        String(255), nullable=False, default="Original Upload"
    )
    target_role: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    company_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    tag: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True, default="general"
    )  # general | tailored | targeted
    edited_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────────────
    resume: Mapped["Resume"] = relationship("Resume", back_populates="versions")
    analysis_results: Mapped[List["AnalysisResult"]] = relationship(
        "AnalysisResult",
        back_populates="resume_version",
        foreign_keys="[AnalysisResult.resume_version_id]",
        cascade="all, delete-orphan",
    )
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="resume_version"
    )


class AnalysisResult(Base, TimestampMixin):
    __tablename__ = "analysis_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    resume_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resumes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    resume_version_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("resume_versions.id", ondelete="SET NULL"),
        nullable=True,
    )

    # ── Status ────────────────────────────────────────────────────────────────
    status: Mapped[str] = mapped_column(
        String(50), default="processing", nullable=False
    )  # processing | completed | failed

    # ── Scores ────────────────────────────────────────────────────────────────
    overall_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    ats_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    recruiter_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    overall_label: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )  # Poor | Fair | Good | Excellent

    # ── Analysis payload (JSON fields) ────────────────────────────────────────
    breakdown_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    issues_json: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    missing_keywords_json: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    rewrites_json: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    action_plan_json: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────────────
    resume: Mapped["Resume"] = relationship(
        "Resume",
        back_populates="analysis_results",
        foreign_keys="[AnalysisResult.resume_id]",
    )
    resume_version: Mapped[Optional["ResumeVersion"]] = relationship(
        "ResumeVersion",
        back_populates="analysis_results",
        foreign_keys="[AnalysisResult.resume_version_id]",
    )
