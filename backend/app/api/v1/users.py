"""
app/routes/user.py

User profile and settings endpoints:
  GET  /user/profile   — get full profile (with settings)
  PATCH /user/profile  — update profile fields
  GET  /user/settings  — get notification/theme settings
  PATCH /user/settings — update settings
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User, UserSettings, RefreshToken
from app.schemas.user import UpdateProfileRequest, UpdateSettingsRequest, UserProfileOut, UserSettingsOut

router = APIRouter()


@router.get("/profile", response_model=UserProfileOut)
async def get_profile(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Eagerly load settings
    result = await db.execute(
        select(User).where(User.id == current_user.id)
    )
    user = result.unique().scalar_one()
    return UserProfileOut.model_validate(user)


@router.patch("/profile", response_model=UserProfileOut)
async def update_profile(
    body: UpdateProfileRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)

    await db.commit()
    await db.refresh(current_user)
    return UserProfileOut.model_validate(current_user)


@router.get("/settings", response_model=UserSettingsOut)
async def get_settings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = result.scalar_one_or_none()
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    return UserSettingsOut.model_validate(settings)


@router.patch("/settings", response_model=UserSettingsOut)
async def update_settings(
    body: UpdateSettingsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = result.scalar_one_or_none()
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(settings, field, value)

    await db.commit()
    await db.refresh(settings)
    return UserSettingsOut.model_validate(settings)


@router.get("/sessions")
async def get_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from datetime import datetime
    result = await db.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == current_user.id)
        .where(RefreshToken.revoked_at.is_(None))
        .where(RefreshToken.expires_at > datetime.utcnow())
        .order_by(RefreshToken.created_at.desc())
    )
    tokens = result.scalars().all()
    # Group by family_id to show unique sessions
    sessions = {}
    for t in tokens:
        if str(t.family_id) not in sessions:
            sessions[str(t.family_id)] = {
                "family_id": str(t.family_id),
                "ip_address": t.ip_address,
                "user_agent": t.user_agent,
                "last_active": t.created_at.isoformat(),
            }
    return list(sessions.values())


@router.delete("/sessions/{family_id}")
async def revoke_session(
    family_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from datetime import datetime
    import uuid
    try:
        fid = uuid.UUID(family_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid session ID")

    result = await db.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == current_user.id)
        .where(RefreshToken.family_id == fid)
        .where(RefreshToken.revoked_at.is_(None))
    )
    tokens = result.scalars().all()
    if not tokens:
        raise HTTPException(status_code=404, detail="Session not found")
        
    for t in tokens:
        t.revoked_at = datetime.utcnow()
        
    await db.commit()
    return {"status": "revoked"}
