"""
app/dependencies.py

Re-exported from app.core.dependencies for backward compatibility.
Old imports (from app.dependencies) now point to new RS256-based dependency.
"""
from app.core.dependencies import get_current_user, CurrentUser

# Keep require_pro for gating — unchanged
from fastapi import Depends, HTTPException, status
from app.models.user import User

def require_pro():
    """Dependency factory for plan-gated routes. MVP: open to all."""
    async def _check_plan(user: User = Depends(get_current_user)) -> User:
        # Uncomment to enforce plan gating
        # if user.subscription_tier not in ("pro", "premium"):
        #     raise HTTPException(
        #         status_code=status.HTTP_403_FORBIDDEN,
        #         detail={"code": "UPGRADE_REQUIRED", "message": "Pro plan required."}
        #     )
        return user
    return _check_plan
