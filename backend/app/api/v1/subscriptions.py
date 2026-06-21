import logging
from fastapi import APIRouter

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/plans")
async def get_plans():
    return {
        "plans": [
            {
                "id": "pri_monthly_mock",
                "name": "Monthly Pro",
                "price": 9.99,
                "interval": "month",
                "features": ["Unlimited Resumes", "Unlimited Cover Letters", "Premium Themes"]
            },
            {
                "id": "pri_yearly_mock",
                "name": "Yearly Pro",
                "price": 89.99,
                "interval": "year",
                "features": ["Unlimited Resumes", "Unlimited Cover Letters", "Premium Themes", "Priority Support"]
            },
            {
                "id": "pri_lifetime_mock",
                "name": "Lifetime Pro",
                "price": 199.99,
                "interval": "lifetime",
                "features": ["Unlimited Resumes", "Unlimited Cover Letters", "Premium Themes", "Priority Support", "One-time Payment"]
            }
        ]
    }
