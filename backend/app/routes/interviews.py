"""
app/routes/interviews.py — Interview scheduling
"""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import CurrentUser, get_db
from app.models.tracker import Application, Interview
from app.schemas.application import InterviewOut
from app.schemas.interview import InterviewCreate, InterviewUpdate

router = APIRouter(prefix="/interviews", tags=["Interviews"])
logger = logging.getLogger(__name__)


@router.get("/applications/{app_id}/interviews", response_model=list[InterviewOut])
async def list_interviews(
    app_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """List all interviews for a given application."""
    result = await db.execute(
        select(Application).where(Application.id == app_id, Application.user_id == current_user.id)
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    result = await db.execute(
        select(Interview)
        .where(Interview.application_id == app_id)
        .order_by(Interview.scheduled_at.desc())
    )
    interviews = result.scalars().all()
    return [InterviewOut.model_validate(i) for i in interviews]


@router.post("/applications/{app_id}/interviews", response_model=InterviewOut, status_code=status.HTTP_201_CREATED)
async def create_interview(
    app_id: uuid.UUID,
    body: InterviewCreate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Schedule a new interview for an application."""
    result = await db.execute(
        select(Application).where(Application.id == app_id, Application.user_id == current_user.id)
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    interview = Interview(
        id=uuid.uuid4(),
        application_id=app_id,
        user_id=current_user.id,
        interview_type=body.interview_type,
        scheduled_at=body.scheduled_at,
        duration_minutes=body.duration_minutes,
        location_or_link=body.location_or_link,
        notes=body.notes,
        reminder_enabled=body.reminder_enabled,
    )
    db.add(interview)
    await db.commit()
    await db.refresh(interview)
    return InterviewOut.model_validate(interview)


@router.patch("/{interview_id}", response_model=InterviewOut)
async def update_interview(
    interview_id: uuid.UUID,
    body: InterviewUpdate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Update an existing interview."""
    result = await db.execute(
        select(Interview).where(
            Interview.id == interview_id,
            Interview.user_id == current_user.id,
        )
    )
    interview = result.scalar_one_or_none()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(interview, key, value)

    await db.commit()
    await db.refresh(interview)
    return InterviewOut.model_validate(interview)


@router.delete("/{interview_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_interview(
    interview_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Delete an interview."""
    result = await db.execute(
        select(Interview).where(
            Interview.id == interview_id,
            Interview.user_id == current_user.id,
        )
    )
    interview = result.scalar_one_or_none()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    await db.delete(interview)
    await db.commit()
    return None
