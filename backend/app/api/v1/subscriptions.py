import logging
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.dependencies import CurrentUser, get_db

router = APIRouter()
logger = logging.getLogger(__name__)

# ── Paddle price IDs — set these in your .env / Vercel env vars ───────────────
# PADDLE_MONTHLY_PRICE_ID, PADDLE_YEARLY_PRICE_ID, PADDLE_LIFETIME_PRICE_ID

PLANS = [
    {
        "id": "monthly",
        "price_id": settings.PADDLE_MONTHLY_PRICE_ID,
        "name": "Monthly Pro",
        "price": 9.99,
        "interval": "month",
        "features": ["Unlimited Resumes", "Unlimited Cover Letters", "Premium Themes"],
    },
    {
        "id": "yearly",
        "price_id": settings.PADDLE_YEARLY_PRICE_ID,
        "name": "Yearly Pro",
        "price": 89.99,
        "interval": "year",
        "features": [
            "Unlimited Resumes",
            "Unlimited Cover Letters",
            "Premium Themes",
            "Priority Support",
        ],
    },
    {
        "id": "lifetime",
        "price_id": settings.PADDLE_LIFETIME_PRICE_ID,
        "name": "Lifetime Pro",
        "price": 199.99,
        "interval": "lifetime",
        "features": [
            "Unlimited Resumes",
            "Unlimited Cover Letters",
            "Premium Themes",
            "Priority Support",
            "One-time Payment",
        ],
    },
]


@router.get("/plans")
async def get_plans():
    """Return available subscription plans with their Paddle price IDs."""
    return {"plans": PLANS}


@router.get("/config")
async def get_paddle_config():
    """
    Return the public Paddle client-side token and environment.
    Safe to call without auth — PADDLE_CLIENT_TOKEN is NOT a secret key.
    """
    return {
        "client_token": settings.PADDLE_CLIENT_TOKEN,
        "environment": "sandbox" if settings.ENVIRONMENT != "production" else "production",
    }


class CheckoutRequest(BaseModel):
    price_id: str
    success_url: Optional[str] = None
    cancel_url: Optional[str] = None


@router.post("/checkout")
async def create_checkout(
    body: CheckoutRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """
    Generate a Paddle Billing checkout URL for the given price_id.
    Embeds user_id in custom_data so the webhook can attribute the subscription.

    Paddle Sandbox docs: https://developer.paddle.com/build/transactions/create-transaction-checkout
    """
    if not settings.PADDLE_API_KEY:
        # Dev fallback — return a mock URL for testing the UI flow
        mock_url = (
            f"https://sandbox-buy.paddle.com/checkout/custom/mock"
            f"?price_id={body.price_id}&user_id={current_user.id}"
        )
        return {"checkout_url": mock_url, "mode": "mock"}

    import httpx

    paddle_base = (
        "https://sandbox-api.paddle.com"
        if settings.ENVIRONMENT != "production"
        else "https://api.paddle.com"
    )

    frontend_origin = settings.APP_WEB_BASE_URL or settings.FRONTEND_URL

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{paddle_base}/transactions",
                headers={
                    "Authorization": f"Bearer {settings.PADDLE_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "items": [{"price_id": body.price_id, "quantity": 1}],
                    "customer": {
                        "email": current_user.email,
                    },
                    "custom_data": {"user_id": str(current_user.id)},
                    "checkout": {
                        "url": body.success_url or f"{frontend_origin}/settings?checkout=success",
                    },
                },
            )
        if resp.status_code not in (200, 201):
            logger.error("Paddle checkout failed: %s %s", resp.status_code, resp.text)
            raise HTTPException(status_code=502, detail="Failed to create Paddle checkout session")

        data = resp.json()
        paddle_data = data.get("data", {})
        checkout_url = paddle_data.get("checkout", {}).get("url")
        transaction_id = paddle_data.get("id")
        if not checkout_url:
            raise HTTPException(status_code=502, detail="Paddle did not return a checkout URL")

        return {
            "checkout_url": checkout_url,
            "transaction_id": transaction_id,
            "mode": "paddle",
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Paddle checkout error")
        raise HTTPException(status_code=500, detail="Checkout unavailable")

