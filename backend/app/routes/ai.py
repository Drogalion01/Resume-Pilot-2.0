"""
app/routes/ai.py

AI Resume Lab endpoints.
Currently in MOCK MODE (AI_MOCK_MODE=true).
Phase 4: flip AI_MOCK_MODE=false + set GEMINI_API_KEY to go live.

  POST /ai/rewrite-bullets     — rewrite weak resume bullets → strong, metric-driven
  POST /ai/generate-cover-letter — generate personalised cover letter
  POST /ai/suggest-keywords    — suggest ATS keywords missing from resume
"""
from typing import List, Optional

from fastapi import APIRouter, Depends

from app.dependencies import get_current_user, require_pro
from app.models.user import User
from app.services import ai_service
from pydantic import BaseModel

router = APIRouter()


# ── Request / Response models ─────────────────────────────────────────────────


class RewriteBulletsRequest(BaseModel):
    bullets: List[str]
    target_role: Optional[str] = None
    context: Optional[str] = None  # e.g. job description snippet


class RewriteBulletsResponse(BaseModel):
    rewrites: List[dict]  # [{original, improved}]
    mock_mode: bool


class CoverLetterRequest(BaseModel):
    resume_text: str
    company_name: str
    role: str
    jd_text: Optional[str] = None


class CoverLetterResponse(BaseModel):
    cover_letter: str
    mock_mode: bool


class SuggestKeywordsRequest(BaseModel):
    resume_text: str
    target_role: str
    jd_text: Optional[str] = None


class SuggestKeywordsResponse(BaseModel):
    keywords: List[str]
    mock_mode: bool


# ── Endpoints ─────────────────────────────────────────────────────────────────


@router.post("/rewrite-bullets", response_model=RewriteBulletsResponse)
async def rewrite_bullets(
    body: RewriteBulletsRequest,
    # Plan-gate: wired but open in MVP — uncomment require_pro() to enforce
    current_user: User = Depends(get_current_user),
    # current_user: User = Depends(require_pro()),
):
    """Rewrite weak resume bullet points into strong, quantified statements."""
    from app.config import settings
    rewrites = await ai_service.rewrite_bullets(
        body.bullets, body.target_role, body.context
    )
    return RewriteBulletsResponse(rewrites=rewrites, mock_mode=settings.AI_MOCK_MODE)


@router.post("/generate-cover-letter", response_model=CoverLetterResponse)
async def generate_cover_letter(
    body: CoverLetterRequest,
    current_user: User = Depends(get_current_user),
):
    """Generate a personalised cover letter for a job application."""
    from app.config import settings
    cover_letter = await ai_service.generate_cover_letter(
        resume_text=body.resume_text,
        company_name=body.company_name,
        role=body.role,
        user_name=current_user.full_name,
        jd_text=body.jd_text,
    )
    return CoverLetterResponse(cover_letter=cover_letter, mock_mode=settings.AI_MOCK_MODE)


@router.post("/suggest-keywords", response_model=SuggestKeywordsResponse)
async def suggest_keywords(
    body: SuggestKeywordsRequest,
    current_user: User = Depends(get_current_user),
):
    """Suggest ATS-relevant keywords missing from the resume."""
    from app.config import settings
    keywords = await ai_service.suggest_keywords(
        resume_text=body.resume_text,
        target_role=body.target_role,
        jd_text=body.jd_text,
    )
    return SuggestKeywordsResponse(keywords=keywords, mock_mode=settings.AI_MOCK_MODE)
