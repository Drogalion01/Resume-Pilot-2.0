import logging
import json
from datetime import datetime
from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.config import settings

# Paddle verification logic (Signature validation requires paddle SDK or manual HMAC)
# Since we are building Phase 2 Paddle integration, we will handle standard paddle signature validation.
# Paddle sends signature in header: Paddle-Signature: ts=...,h1=...
import hashlib
import hmac

router = APIRouter()
logger = logging.getLogger(__name__)

def verify_paddle_signature(request_body: str, signature_header: str, secret: str) -> bool:
    """Verify Paddle webhook signature. Header format: 'ts=TIMESTAMP;h1=HASH'"""
    try:
        parts = {}
        for part in signature_header.split(';'):
            if '=' in part:
                k, v = part.split('=', 1)
                parts[k.strip()] = v.strip()
        ts = parts.get('ts')
        h1 = parts.get('h1')
        if not ts or not h1:
            return False
        
        payload = f"{ts}:{request_body}"
        mac = hmac.new(
            secret.encode('utf-8'),
            payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(mac, h1)
    except Exception as e:
        logger.error(f"Paddle signature verification failed: {e}")
        return False

async def process_paddle_webhook(event: Dict[Any, Any], db: AsyncSession):
    event_type = event.get('event_type')
    data = event.get('data', {})
    
    # E.g. subscription.created, subscription.updated, subscription.canceled
    if event_type in ['subscription.created', 'subscription.updated']:
        customer_id = data.get('customer_id')
        status = data.get('status')
        custom_data = data.get('custom_data', {})
        user_id = custom_data.get('user_id')
        
        if not user_id:
            logger.error("No user_id found in Paddle custom_data")
            return
            
        user = await db.get(User, user_id)
        if not user:
            logger.error(f"User {user_id} not found for Paddle webhook")
            return
            
        if status in ['active', 'trialing']:
            user.subscription_tier = 'pro'
            user.paddle_customer_id = customer_id
            
            # Next billing cycle
            current_period_end = data.get('current_billing_period', {}).get('ends_at')
            if current_period_end:
                # E.g. "2023-11-20T14:30:00Z"
                try:
                    ends_at = datetime.fromisoformat(current_period_end.replace('Z', '+00:00'))
                    user.subscription_expires_at = ends_at
                    user.generation_reset_date = ends_at
                except ValueError:
                    pass
        elif status in ['canceled', 'past_due', 'paused']:
            user.subscription_tier = 'free'
            
        await db.commit()
        
    elif event_type == 'subscription.canceled':
        custom_data = data.get('custom_data', {})
        user_id = custom_data.get('user_id')
        if user_id:
            user = await db.get(User, user_id)
            if user:
                user.subscription_tier = 'free'
                await db.commit()

@router.post("/webhooks/paddle")
async def paddle_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    body_bytes = await request.body()
    body_str = body_bytes.decode('utf-8')
    signature_header = request.headers.get("Paddle-Signature", "")
    
    if not settings.PADDLE_WEBHOOK_SECRET:
        # In dev without secret, just process it
        pass
    else:
        if not signature_header or not verify_paddle_signature(body_str, signature_header, settings.PADDLE_WEBHOOK_SECRET):
            raise HTTPException(status_code=400, detail="Invalid Paddle signature")

    try:
        event = json.loads(body_str)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
        
    # Process asynchronously to avoid blocking webhook response
    background_tasks.add_task(process_paddle_webhook, event, db)
    
    return {"status": "ok"}
