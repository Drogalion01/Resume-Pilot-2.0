"""
app/dependencies.py

FastAPI dependency injection: JWT auth, plan-gate hook.
"""
import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.services.auth_service import decode_token

_security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extract and validate JWT Bearer token; return the authenticated User."""
    token = credentials.credentials
    payload = decode_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Invalid or expired token."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str: str | None = payload.get("sub")
    try:
        user_id = uuid.UUID(user_id_str)  # type: ignore[arg-type]
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Malformed token payload."},
        )

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "USER_NOT_FOUND", "message": "User not found."},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DISABLED", "message": "Your account has been disabled."},
        )

    return user


# ── Plan-gate hook ─────────────────────────────────────────────────────────────
# WIRED but OPEN in MVP — all plans have full access.
# To enable gating: uncomment the two lines in _check_plan below.


def require_pro():
    """
    Dependency factory for plan-gated routes.

    Usage:
        @router.post("/premium-feature")
        async def endpoint(user: User = Depends(require_pro())):
            ...

    MVP: Access is open to everyone regardless of plan.
    Future: Set AI_MOCK_MODE=false and uncomment the gate to restrict to "pro".
    """

    async def _check_plan(user: User = Depends(get_current_user)) -> User:
        # ── Gate hook (uncomment to enforce) ──────────────────────────────────
        # if user.plan not in ("pro", "enterprise"):
        #     raise HTTPException(
        #         status_code=status.HTTP_403_FORBIDDEN,
        #         detail={
        #             "code": "UPGRADE_REQUIRED",
        #             "message": "This feature requires a Pro plan.",
        #             "upgrade_url": f"{settings.FRONTEND_URL}/upgrade",
        #         },
        #     )
        return user

    return _check_plan
