from functools import lru_cache
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── Database ──────────────────────────────────────────────────────────────
    DATABASE_URL: str = "sqlite+aiosqlite:///./resumepilot.db"

    # ── JWT ───────────────────────────────────────────────────────────────────
    SECRET_KEY: str = "dev-secret-key-CHANGE-IN-PRODUCTION-must-be-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 11520  # 8 days

    # ── Google OAuth ──────────────────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # ── Cloudinary ────────────────────────────────────────────────────────────
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # ── AI ────────────────────────────────────────────────────────────────────
    GEMINI_API_KEY: str = ""
    AI_MOCK_MODE: bool = True  # True = mock stubs, False = real Gemini

    # ── Email (Resend → SendGrid migration path) ──────────────────────────────
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "ResumePilot <noreply@resumepilot.app>"

    # ── App ───────────────────────────────────────────────────────────────────
    APP_NAME: str = "ResumePilot"
    FRONTEND_URL: str = "http://localhost:3000"
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    DEBUG: bool = False

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def normalise_db_url(cls, v: str) -> str:
        """Accept both postgres:// and postgresql:// (Neon/Heroku/Render style)."""
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql+asyncpg://", 1)
        if v.startswith("postgresql://") and "+asyncpg" not in v:
            return v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
