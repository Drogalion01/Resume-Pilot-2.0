"""
app/services/email_service.py

Email delivery via Resend SDK.
Abstraction layer: swap Resend → SendGrid by changing this file only.
"""
import logging

import resend

from app.config import settings

logger = logging.getLogger(__name__)

# Configure SDK with API key
resend.api_key = settings.RESEND_API_KEY


def _send(params: dict) -> bool:
    """Internal send helper — runs synchronously (called from BackgroundTasks)."""
    try:
        resend.Emails.send(params)
        return True
    except Exception as exc:
        logger.error("Email send failed: %s | to=%s", exc, params.get("to"))
        return False


# ── Transactional emails ──────────────────────────────────────────────────────


def send_verification_email(
    to_email: str, token: str, full_name: str | None = None
) -> bool:
    verify_url = f"{settings.FRONTEND_URL}/verify-email?token={token}"
    name = full_name or to_email.split("@")[0]

    html = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: Inter, sans-serif; background: #0f0f14; color: #e2e8f0; padding: 40px;">
      <div style="max-width: 520px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; padding: 40px; border: 1px solid #7c3aed22;">
        <h1 style="color: #a78bfa; margin-bottom: 8px;">Welcome to ResumePilot 🚀</h1>
        <p style="color: #94a3b8;">Hi {name}, you're almost ready to land your dream job.</p>
        <p style="color: #cbd5e1;">Click the button below to verify your email address.</p>
        <a href="{verify_url}"
           style="display:inline-block; margin-top:24px; padding:14px 32px;
                  background:linear-gradient(135deg,#7c3aed,#4f46e5);
                  color:#fff; border-radius:10px; text-decoration:none;
                  font-weight:600; font-size:16px;">
          Verify Email
        </a>
        <p style="margin-top:32px; color:#64748b; font-size:13px;">
          This link expires in 24 hours. If you didn't create an account, ignore this email.
        </p>
      </div>
    </body>
    </html>
    """

    return _send({
        "from": settings.EMAIL_FROM,
        "to": to_email,
        "subject": "Verify your ResumePilot account",
        "html": html,
    })


def send_magic_link(to_email: str, raw_token: str) -> bool:
    """
    Send passwordless magic link sign-in email.
    Link directs user to the frontend verify endpoint with the token.
    """
    verify_url = f"{settings.APP_WEB_BASE_URL}/auth/verify?token={raw_token}"
    name = to_email.split("@")[0]

    html = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: Inter, sans-serif; background: #0f0f14; color: #e2e8f0; padding: 40px;">
      <div style="max-width: 520px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; padding: 40px; border: 1px solid #7c3aed22;">
        <h1 style="color: #a78bfa; margin-bottom: 8px;">Sign in to ResumePilot 🔐</h1>
        <p style="color: #94a3b8;">Hi {name}, click the button below to sign in to your account.</p>
        <a href="{verify_url}"
           style="display:inline-block; margin-top:24px; padding:14px 32px;
                  background:linear-gradient(135deg,#7c3aed,#4f46e5);
                  color:#fff; border-radius:10px; text-decoration:none;
                  font-weight:600; font-size:16px;">
          Sign In
        </a>
        <p style="margin-top:32px; color:#64748b; font-size:13px;">
          This link expires in 15 minutes and can be used only once. If you didn't request this, ignore this email.
        </p>
      </div>
    </body>
    </html>
    """

    return _send({
        "from": settings.EMAIL_FROM,
        "to": to_email,
        "subject": "Your ResumePilot sign-in link",
        "html": html,
    })


def send_password_reset_email(to_email: str, token: str) -> bool:
    reset_url = f"{settings.FRONTEND_URL}/reset-password?token={token}"

    html = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: Inter, sans-serif; background: #0f0f14; color: #e2e8f0; padding: 40px;">
      <div style="max-width: 520px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; padding: 40px; border: 1px solid #7c3aed22;">
        <h1 style="color: #a78bfa;">Password Reset</h1>
        <p style="color: #94a3b8;">We received a request to reset your ResumePilot password.</p>
        <a href="{reset_url}"
           style="display:inline-block; margin-top:24px; padding:14px 32px;
                  background:linear-gradient(135deg,#7c3aed,#4f46e5);
                  color:#fff; border-radius:10px; text-decoration:none;
                  font-weight:600; font-size:16px;">
          Reset Password
        </a>
        <p style="margin-top:32px; color:#64748b; font-size:13px;">
          This link expires in 1 hour. If you didn't request this, ignore this email.
        </p>
      </div>
    </body>
    </html>
    """

    return _send({
        "from": settings.EMAIL_FROM,
        "to": to_email,
        "subject": "Reset your ResumePilot password",
        "html": html,
    })
