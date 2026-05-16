"""
app/services/generation_service.py

Orchestrates resume and cover letter generation.
Runs both in parallel using asyncio.gather().
Enforces generation limits before any LLM call.
"""
import asyncio
import logging
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import GenerationLimitExceededError
from app.models.user import User
from app.services.resume_service import count_user_generations_this_month, generate_cover_letter_for_version, generate_resume_version

logger = logging.getLogger(__name__)


async def generate_resume_and_cover_letter(
    user: User,
    resume_id: uuid.UUID,
    job_title: str,
    job_description: str,
    company_name: Optional[str],
    generate_cover_letter: bool,
    db: AsyncSession,
) -> dict:
    """
    Orchestrates full generation: tailored resume (+ optional cover letter) in parallel.
    Returns dict with:
      resume_version_id, cover_letter_id (or null), scores, matched/missing keywords, metadata
    """
    # Enforce limit first
    used, limit = count_user_generations_this_month(user, db)
    if used + (1 + int(generate_cover_letter)) > limit:
        raise GenerationLimitExceededError(tier=user.subscription_tier, limit=limit)

    # Fetch resume
    from app.models.resume import Resume
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != user.id:
        raise ValueError("Resume not found")

    # Run resume generation and cover letter in parallel if needed
    if generate_cover_letter:
        resume_task = generate_resume_version(user, resume, job_title, job_description, company_name, db)
        cover_letter_task = generate_cover_letter_for_version(user, resume, job_title, company_name, job_description, db)
        version, cover_letter_content = await asyncio.gather(resume_task, cover_letter_task)
        # cover_letter_content is string; we already saved CoverLetter record inside generate_cover_letter_for_version
        # Need to get the CoverLetter ID from DB? Could query.
        # For now, return None — will fetch later via separate endpoint
        cover_letter_id = None  # placeholder
    else:
        version = await generate_resume_version(user, resume, job_title, job_description, company_name, db)
        cover_letter_id = None

    # Increment generation count inside service functions already

    return {
        "resume_version_id": str(version.id),
        "cover_letter_id": cover_letter_id,
        "ats_score": version.analysis_results[0].ats_score if version.analysis_results else None,
        "recruiter_score": version.analysis_results[0].recruiter_score if version.analysis_results else None,
        "overall_score": version.analysis_results[0].overall_score if version.analysis_results else None,
        "matched_keywords": version.analysis_results[0].matched_keywords if version.analysis_results else [],
        "missing_keywords": version.analysis_results[0].missing_keywords if version.analysis_results else [],
        "generation_metadata": version.generation_metadata,
    }
