"""
app/models/generation.py

CoverLetter ORM model.
Stores AI-generated cover letters tied to a user, optionally linked to a resume version.
"""
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models import TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.resume import ResumeVersion


class CoverLetter(Base, TimestampMixin):
    __tablename__ = "cover_letters"

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

    # ── Job context ───────────────────────────────────────────────────────────────
    job_title: Mapped[str] = mapped_column(String(255), nullable=False)
    company_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # ── Generated content ─────────────────────────────────────────────────────────
    content: Mapped[str] = mapped_column(Text, nullable=False)
    generation_metadata: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User")
    resume_version: Mapped[Optional["ResumeVersion"]] = relationship(
        "ResumeVersion"
    )
