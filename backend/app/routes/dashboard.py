"""
app/routes/dashboard.py — Phase 2 implementation (stub for Phase 1)
"""
from fastapi import APIRouter, Depends
from app.dependencies import get_current_user
from app.models.user import User

router = APIRouter()


@router.get("")
async def get_dashboard(current_user: User = Depends(get_current_user)):
    # TODO Phase 2: Implement dashboard_service aggregation
    return {
        "user": {"id": str(current_user.id), "full_name": current_user.full_name},
        "summary": {"total_resumes": 0, "total_applications": 0, "total_interviews": 0},
        "recent_resumes": [],
        "recent_applications": [],
        "upcoming_interviews": [],
        "insight": {"message": "Upload your first resume to get started! 🚀"},
    }
