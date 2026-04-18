"""
app/core/exceptions.py

Custom exception hierarchy mapped to HTTP status codes.
All inherit from HTTPException so FastAPI handles them consistently.
"""
from fastapi import HTTPException, status


class AppError(HTTPException):
    """Base class — subclass to set default status_code & detail."""
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    detail = "Internal server error"

    def __init__(self, detail: str | None = None, headers: dict | None = None):
        super().__init__(
            status_code=self.status_code,
            detail=detail or self.detail,
            headers=headers,
        )


# ── 4xx Client Errors ──────────────────────────────────────────────────────────

class ValidationError(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    detail = "Validation error"


class AuthenticationError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "Invalid credentials or token"


class AuthorizationError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    detail = "Insufficient permissions"


class MFATokenRequiredError(HTTPException):
    """Raised when a valid MFA token is required but missing/invalid."""
    def __init__(self):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="MFA verification required",
            headers={"X-MFA-Required": "true"},
        )


class TokenExpiredError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "Token has expired"


class InvalidTokenError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "Invalid token"


class ResourceNotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    detail = "Resource not found"


class GenerationLimitExceededError(HTTPException):
    """402 Payment Required — free tier limit hit."""
    def __init__(self, tier: str, limit: int, resets_at: str | None = None):
        detail = {
            "error": "generation_limit_exceeded",
            "tier": tier,
            "limit": limit,
            "message": f"You have used all {limit} free generations. Upgrade to Pro for unlimited.",
        }
        if resets_at:
            detail["resets_at"] = resets_at
        super().__init__(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=detail)


# ── 5xx Server Errors ──────────────────────────────────────────────────────────

class LLMServiceError(AppError):
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    detail = "LLM service unavailable or returned malformed response"


class FileUploadError(AppError):
    status_code = status.HTTP_400_BAD_REQUEST
    detail = "Invalid file upload"


class EmailDeliveryError(AppError):
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    detail = "Failed to send email"
