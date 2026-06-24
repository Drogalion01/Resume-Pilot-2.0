from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy.orm import selectinload
from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.models.application import Application, Interview

router = APIRouter()

@router.get("")
async def get_dashboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Phase 1 Aggregation
    resumes_count = await db.scalar(select(func.count(Resume.id)).where(Resume.user_id == current_user.id))
    applications_count = await db.scalar(select(func.count(Application.id)).where(Application.user_id == current_user.id))
    interviews_count = await db.scalar(select(func.count(Interview.id)).where(Interview.user_id == current_user.id))

    # Fetch upcoming interviews
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    upcoming_interviews_query = await db.execute(
        select(Interview)
        .options(selectinload(Interview.application))
        .where(Interview.user_id == current_user.id)
        .where(Interview.scheduled_at >= now)
        .order_by(Interview.scheduled_at.asc())
        .limit(5)
    )
    upcoming_interviews = upcoming_interviews_query.scalars().all()

    return {
        "user": {"id": str(current_user.id), "full_name": current_user.full_name},
        "summary": {
            "total_resumes": resumes_count or 0,
            "total_applications": applications_count or 0,
            "total_interviews": interviews_count or 0
        },
        "recent_resumes": [],
        "recent_applications": [],
        "upcoming_interviews": [
            {
                "id": str(i.id),
                "application_id": str(i.application_id),
                "interview_type": i.interview_type,
                "scheduled_at": i.scheduled_at.isoformat(),
                "duration_minutes": i.duration_minutes,
                "company_name": i.application.company_name if i.application else "Unknown" # Need eager load for application
            } for i in upcoming_interviews
        ],
        "insight": {"message": "Upload your first resume to get started! 🚀" if resumes_count == 0 else "Keep tracking your applications!"},
    }
