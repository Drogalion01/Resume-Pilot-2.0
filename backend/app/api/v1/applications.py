"""
app/routes/applications.py — Application tracking with automatic timeline events
"""
import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import CurrentUser, get_db
from app.models.application import Application, ApplicationStatus, Interview, Note, Reminder, TimelineEvent
from app.schemas.application import (
    ApplicationCreate,
    ApplicationDetail,
    ApplicationListItem,
    ApplicationUpdate,
    NoteCreate,
    NoteOut,
)
from app.services.resume_service import parse_resume_text  # optional: auto-parsing JD from text?

router = APIRouter()
logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _log_timeline(
    db: AsyncSession,
    application: Application,
    event_type: str,
    title: str,
    description: str | None = None,
    metadata: dict | None = None,
) -> TimelineEvent:
    """Create a timeline event for an application."""
    event = TimelineEvent(
        user_id=application.user_id,
        application_id=application.id,
        event_type=event_type,
        title=title,
        description=description,
        metadata_json=metadata or {},
    )
    db.add(event)
    return event


# ═══════════════════════════════════════════════════════════════════════════════
# List & Create
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/", response_model=list[ApplicationListItem])
async def list_applications(
    current_user: CurrentUser,
    status: ApplicationStatus | None = Query(None, description="Filter by application status"),
    search: str | None = Query(None, description="Search company or role"),
    db: AsyncSession = Depends(get_db),
):
    """List all job applications for the current user with optional filters."""
    query = select(Application).where(Application.user_id == current_user.id)
    if status:
        query = query.where(Application.status == status)
    if search:
        query = query.where(
            (Application.company_name.ilike(f"%{search}%")) |
            (Application.role.ilike(f"%{search}%"))
        )
    query = query.order_by(Application.created_at.desc())
    result = await db.execute(query)
    apps = result.scalars().all()
    return [ApplicationListItem.model_validate(a) for a in apps]


@router.post("/", response_model=ApplicationDetail, status_code=status.HTTP_201_CREATED)
async def create_application(
    body: ApplicationCreate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Create a new job application. Logs timeline event 'application_created'."""
    app = Application(
        id=uuid.uuid4(),
        user_id=current_user.id,
        company_name=body.company_name,
        role=body.role,
        status=body.status or ApplicationStatus.SAVED,
        location=body.location,
        source_url=body.source_url,
        recruiter_name=body.recruiter_name,
        resume_version_id=body.resume_version_id,
        cover_letter_id=body.cover_letter_id,
    )
    db.add(app)
    await db.flush()

    _log_timeline(
        db, app,
        event_type="application_created",
        title=f"Application for {body.role} at {body.company_name}",
        description="Initial tracking entry created",
    )
    await db.commit()
    await db.refresh(app)
    return ApplicationDetail.model_validate(app)


# ═══════════════════════════════════════════════════════════════════════════════
# Detail & Updates
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/{app_id}", response_model=ApplicationDetail)
async def get_application(
    app_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Get a single application with all related data (interviews, reminders, notes, timeline)."""
    result = await db.execute(
        select(Application)
        .where(Application.id == app_id, Application.user_id == current_user.id)
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    return ApplicationDetail.model_validate(app)


@router.patch("/{app_id}", response_model=ApplicationDetail)
async def update_application(
    app_id: uuid.UUID,
    body: ApplicationUpdate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Update application details. If status changes, logs timeline event."""
    result = await db.execute(
        select(Application).where(
            Application.id == app_id,
            Application.user_id == current_user.id,
        )
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    old_status = app.status
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(app, key, value)

    if "status" in updates and updates["status"] != old_status:
        _log_timeline(
            db, app,
            event_type="status_changed",
            title=f"Status changed to {app.status.value}",
            description=f"Previous: {old_status.value}",
            metadata={"old": old_status.value, "new": app.status.value},
        )

    await db.commit()
    await db.refresh(app)
    return ApplicationDetail.model_validate(app)


@router.delete("/{app_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_application(
    app_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Delete an application and all cascaded children (interviews, reminders, notes, timeline)."""
    result = await db.execute(
        select(Application).where(
            Application.id == app_id,
            Application.user_id == current_user.id,
        )
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    await db.delete(app)
    await db.commit()
    return None


@router.patch("/{app_id}/status", response_model=ApplicationDetail)
async def update_status(
    app_id: uuid.UUID,
    status: ApplicationStatus,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Quick status update endpoint. Logs timeline."""
    result = await db.execute(
        select(Application).where(
            Application.id == app_id,
            Application.user_id == current_user.id,
        )
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    old = app.status
    app.status = status
    _log_timeline(
        db, app,
        event_type="status_changed",
        title=f"Status → {status.value}",
        description=f"Changed from {old.value}",
    )
    await db.commit()
    await db.refresh(app)
    return ApplicationDetail.model_validate(app)
