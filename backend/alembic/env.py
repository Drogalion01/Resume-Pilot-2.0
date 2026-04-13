"""
alembic/env.py

Async Alembic migration environment.
Imports all models so they register with Base.metadata before migrations run.
"""
import asyncio
import os
import sys
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context

# ── Add project root to sys.path ──────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings
from app.database import Base

# ── Import ALL models so they register with Base.metadata ─────────────────────
from app.models.user import User, UserSettings          # noqa: F401
from app.models.resume import Resume, ResumeVersion, AnalysisResult  # noqa: F401
from app.models.tracker import (                         # noqa: F401
    Application, Interview, Reminder, Note, TimelineEvent,
    ApplicationStatus, InterviewType, InterviewStatus,
)

# ── Alembic config ────────────────────────────────────────────────────────────
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _get_url() -> str:
    """Return async-compatible DB URL from settings."""
    url = settings.DATABASE_URL
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)
    return url


# ── Offline mode (no live DB connection) ─────────────────────────────────────


def run_migrations_offline() -> None:
    context.configure(
        url=_get_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online mode (async connection) ────────────────────────────────────────────


def _do_run_migrations(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        render_as_batch=True,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = create_async_engine(_get_url(), poolclass=pool.NullPool)
    async with connectable.connect() as connection:
        await connection.run_sync(_do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
