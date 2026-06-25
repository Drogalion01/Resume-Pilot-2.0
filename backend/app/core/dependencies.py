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
from sqlalchemy import select
from sqlalchemy.orm import selectinload


from fastapi.security import OAuth2PasswordBearer
import uuid

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"/api/v1/auth/oauth/google/callback", auto_error=False)

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Dependency that decodes JWT,
    fetches the User from DB, and returns the ORM object.
    """
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = verify_token(token, public_key=settings.JWT_PUBLIC_KEY, algorithm=settings.JWT_ALGORITHM)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user ID in token")
        
    result = await db.execute(
        select(User).options(selectinload(User.settings)).where(User.id == user_uuid)
    )
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    return user


# Type alias for convenient FastAPI annotation
CurrentUser = Annotated[User, Depends(get_current_user)]
