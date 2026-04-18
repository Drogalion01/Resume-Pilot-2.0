"""
app/core/dependencies.py

FastAPI dependencies for database sessions and current user resolution.
"""
from datetime import UTC, datetime
from typing import Annotated

from fastapi import Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import verify_token
from app.database import get_db
from app.models.user import User


async def get_current_user(
    token: str,
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Dependency that decodes JWT, validates scope (rejects mfa_pending),
    fetches the User from DB, and returns the ORM object.
    """
    try:
        payload = verify_token(token, public_key=settings.JWT_PUBLIC_KEY, algorithm=settings.JWT_ALGORITHM)
    except HTTPException:
        raise

    # MFA pending tokens have scope=mfa_pending and must not access resources
    if payload.get("scope") == "mfa_pending":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="MFA verification required",
            headers={"X-MFA-Required": "true"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    return user


# Type alias for convenient FastAPI annotation
CurrentUser = Annotated[User, Depends(get_current_user)]
