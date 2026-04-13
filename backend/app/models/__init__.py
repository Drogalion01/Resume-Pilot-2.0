"""
app/models/__init__.py

Defines TimestampMixin shared across all ORM models.
Models are imported explicitly in alembic/env.py to register them with Base.metadata.
"""
from datetime import datetime, timezone

from sqlalchemy import DateTime
from sqlalchemy.orm import Mapped, mapped_column


class TimestampMixin:
    """Adds created_at / updated_at columns with automatic UTC timestamps."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
