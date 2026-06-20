"""
app/main.py

ResumePilot 2.0 — FastAPI application factory.
All routes, middleware, and lifecycle hooks wired here.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text

from app.config import settings
from app.limiter import limiter
from app.api.v1 import (
    applications,
    auth,
    dashboard,
    generation,
    interviews,
    reminders,
    resumes,
    users,
    paddle_webhooks,
)
API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup — async engine handles pool on first request
    yield
    # Shutdown — dispose engine pool
    from app.database import engine
    await engine.dispose()


app = FastAPI(
    title="ResumePilot API",
    description=(
        "AI-powered resume analysis and job application tracking. "
        "Analyse your resume, improve it with AI, track your applications, and land your dream job."
    ),
    version="2.0.0",
    docs_url=f"{API_PREFIX}/docs",
    redoc_url=f"{API_PREFIX}/redoc",
    openapi_url=f"{API_PREFIX}/openapi.json",
    lifespan=lifespan,
)

# ── Rate limiting ─────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router,         prefix=f"{API_PREFIX}/auth",         tags=["Auth"])
app.include_router(users.router,        prefix=f"{API_PREFIX}/users",        tags=["Users"])
app.include_router(dashboard.router,    prefix=f"{API_PREFIX}/dashboard",    tags=["Dashboard"])
app.include_router(resumes.router,      prefix=f"{API_PREFIX}/resumes",      tags=["Resumes"])
app.include_router(applications.router, prefix=f"{API_PREFIX}/applications", tags=["Applications"])
app.include_router(interviews.router,   prefix=f"{API_PREFIX}",              tags=["Interviews"])
app.include_router(reminders.router,    prefix=f"{API_PREFIX}/reminders",    tags=["Reminders"])
app.include_router(generation.router,   prefix=f"{API_PREFIX}",              tags=["Generation"])
app.include_router(paddle_webhooks.router, prefix=f"{API_PREFIX}",           tags=["Webhooks"])

# ── Health checks ─────────────────────────────────────────────────────────────

@app.get(f"{API_PREFIX}/health", tags=["Health"])
@app.head(f"{API_PREFIX}/health", tags=["Health"])
async def health():
    return {
        "status": "ok",
        "service": settings.APP_NAME,
        "version": "2.0.0",
        "environment": settings.ENVIRONMENT,
    }


@app.get(f"{API_PREFIX}/health/db", tags=["Health"])
async def health_db():
    try:
        from app.database import AsyncSessionLocal
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception as exc:
        return {"status": "error", "database": str(exc)}
