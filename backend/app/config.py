from functools import lru_cache
from typing import List, Optional

from pydantic import Field, AliasChoices, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── Database ──────────────────────────────────────────────────────────────
    DATABASE_URL: str = "sqlite+aiosqlite:///./resumepilot.db"

    # ── JWT (RS256 asymmetric) ─────────────────────────────────────────────────
    JWT_PRIVATE_KEY: str = ""  # PEM format, include -----BEGIN RSA PRIVATE KEY-----
    JWT_PUBLIC_KEY: str = ""   # PEM format, include -----BEGIN PUBLIC KEY-----
    JWT_ALGORITHM: str = "RS256"
    JWT_ACCESS_EXPIRE_MINUTES: int = 60          # 1 hour
    JWT_REFRESH_EXPIRE_DAYS: int = 30
    JWT_MFA_PENDING_EXPIRE_MINUTES: int = 5

    # ── OAuth providers ─────────────────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GITHUB_CLIENT_ID: str = ""
    GITHUB_CLIENT_SECRET: str = ""
    LINKEDIN_CLIENT_ID: str = ""
    LINKEDIN_CLIENT_SECRET: str = ""

    # ── Email (Resend) ──────────────────────────────────────────────────────────
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = Field("ResumePilot <noreply@resumepilot.app>", validation_alias=AliasChoices("EMAIL_FROM", "FROM_EMAIL"))
    APP_DEEP_LINK_BASE: str = "resumepilot://app"
    APP_WEB_BASE_URL: str = Field("http://localhost:3000", validation_alias=AliasChoices("APP_WEB_BASE_URL", "APP_URL", "FRONTEND_URL"))

    # ── Encryption (Fernet — AES-256-GCM) ───────────────────────────────────────
    TOKEN_ENCRYPTION_KEY: str = ""  # base64url-encoded 32-byte key

    # ── AI (Gemini) ─────────────────────────────────────────────────────────────
    GEMINI_API_KEY: str = ""
    ENVIRONMENT: str = "development"

    # ── Paddle (Monetization) ───────────────────────────────────────────────────
    PADDLE_API_KEY: str = ""
    PADDLE_WEBHOOK_SECRET: str = ""

    # ── Generation limits ───────────────────────────────────────────────────────
    FREE_TIER_GENERATION_LIMIT: int = 3
    PRO_TIER_MONTHLY_LIMIT: int = 30

    # ── App ─────────────────────────────────────────────────────────────────────
    APP_NAME: str = "ResumePilot"
    FRONTEND_URL: str = Field("http://localhost:3000", validation_alias=AliasChoices("FRONTEND_URL", "APP_URL"))
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    DEBUG: bool = False

    # ── File uploads ────────────────────────────────────────────────────────────
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_UPLOAD_EXTENSIONS: List[str] = ["pdf", "docx", "doc", "txt"]
    UPLOAD_DIR: str = "uploads" # Keeping as fallback if S3 is disabled

    # ── AWS S3 (Storage) ────────────────────────────────────────────────────────
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    S3_BUCKET_NAME: str = ""
    AWS_ENDPOINT_URL_S3: Optional[str] = None

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def normalise_db_url(cls, v: str) -> str:
        """Accept both postgres:// and postgresql:// (Neon/Heroku/Render style)."""
        if v.startswith("postgres://"):
            v = v.replace("postgres://", "postgresql+asyncpg://", 1)
        if v.startswith("postgresql://") and "+asyncpg" not in v:
            v = v.replace("postgresql://", "postgresql+asyncpg://", 1)
        
        # asyncpg does not accept sslmode=require, it uses ssl=require
        if "sslmode=" in v:
            v = v.replace("sslmode=", "ssl=")
            
        # asyncpg does not accept channel_binding
        if "&channel_binding=require" in v:
            v = v.replace("&channel_binding=require", "")
        elif "?channel_binding=require" in v:
            v = v.replace("?channel_binding=require", "")
            
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
