import logging
import uuid
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.dependencies import CurrentUser, get_db
from app.models.user import User
from app.models.resume import Resume, ResumeVersion
from app.models.generation import CoverLetter
from app.schemas.generation import (
    GenerateRequest,
    GenerationResultResponse,
    CoverLetterResponse,
    CoverLetterCreateRequest,
    CoverLetterUpdateRequest,
)
from app.services import llm_service
from app.schemas.common import MessageResponse

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/resumes/{resume_id}/generate", response_model=GenerationResultResponse)
async def generate_tailored_resume_endpoint(
    resume_id: uuid.UUID,
    body: GenerateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    # Check if resume belongs to user
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")

    # Check generation limits based on subscription tier
    from app.config import settings
    from datetime import datetime, timezone
    
    now = datetime.now(timezone.utc)
    # Reset limit if billing cycle reset
    if current_user.generation_reset_date and now > current_user.generation_reset_date:
        current_user.generation_count_this_month = 0
        # Reset to next month approx
        import dateutil.relativedelta
        current_user.generation_reset_date = now + dateutil.relativedelta.relativedelta(months=1)
        await db.commit()

    # We use 3 for free tier as requested
    free_limit = 3
    pro_limit = settings.PRO_TIER_MONTHLY_LIMIT

    if current_user.subscription_tier == "free":
        if current_user.generation_count_this_month >= free_limit:
            raise HTTPException(
                status_code=402, 
                detail=f"Free tier limit of {free_limit} resume tailors reached. Please upgrade to Pro for unlimited generations."
            )
    elif current_user.subscription_tier == "pro":
        if current_user.generation_count_this_month >= pro_limit:
            raise HTTPException(
                status_code=402, 
                detail="Pro tier monthly limit reached."
            )

    try:
        tailored_resume, cover_letter_text = await llm_service.generate_resume_and_cover_letter(
            master_resume_json=resume.parsed_data or {},
            job_title=body.job_title,
            job_description=body.job_description,
            company_name=body.company_name,
            user_name=current_user.full_name,
            generate_cl=body.generate_cover_letter,
        )
    except llm_service.LLMServiceError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    scoring = tailored_resume.get("scoring", {})
    
    # Save the new tailored resume as a ResumeVersion
    new_version = ResumeVersion(
        resume_id=resume.id,
        user_id=current_user.id,
        title=f"{body.job_title} at {body.company_name or 'Company'}",
        content_json=tailored_resume,
        job_title=body.job_title,
        job_description=body.job_description,
        company_name=body.company_name,
        generation_mode="tailored",
        generated_from_resume_id=resume.id,
    )
    db.add(new_version)
    await db.flush()

    cover_letter_id = None
    if cover_letter_text:
        cl = CoverLetter(
            user_id=current_user.id,
            resume_version_id=new_version.id,
            job_title=body.job_title,
            company_name=body.company_name,
            content=cover_letter_text,
            generation_metadata={"source": "auto-generated with resume"},
        )
        db.add(cl)
        await db.flush()
        cover_letter_id = cl.id

    # Increment generation count
    current_user.generation_count_this_month += 1
    db.add(current_user)

    await db.commit()
    await db.refresh(new_version)

    return GenerationResultResponse(
        resume_version_id=new_version.id,
        tailored_resume=tailored_resume,
        ats_score=scoring.get("ats_score", 0),
        recruiter_score=scoring.get("recruiter_score", 0),
        overall_score=scoring.get("overall_score", 0),
        matched_keywords=scoring.get("matched_keywords", []),
        missing_keywords=scoring.get("missing_keywords", []),
        cover_letter=cover_letter_text,
        cover_letter_id=cover_letter_id,
        generation_metadata={"status": "success"},
    )

@router.post("/cover-letters", response_model=CoverLetterResponse)
async def create_cover_letter(
    body: CoverLetterCreateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume_data = {}
    if body.resume_version_id:
        version = await db.get(ResumeVersion, body.resume_version_id)
        if not version:
            raise HTTPException(status_code=404, detail="Resume version not found")
        resume_data = version.content_json or {}

    # Check cover letter limits
    from datetime import datetime, timezone
    import dateutil.relativedelta

    now = datetime.now(timezone.utc)
    if current_user.generation_reset_date and now > current_user.generation_reset_date:
        current_user.cover_letter_count_this_month = 0
        current_user.generation_count_this_month = 0
        current_user.generation_reset_date = now + dateutil.relativedelta.relativedelta(months=1)
        await db.commit()

    free_cl_limit = 3
    if current_user.subscription_tier == "free":
        if current_user.cover_letter_count_this_month >= free_cl_limit:
            raise HTTPException(status_code=402, detail="Free tier limit of 3 cover letters reached. Please upgrade to Pro.")
    elif current_user.subscription_tier == "pro":
        from app.config import settings
        if current_user.cover_letter_count_this_month >= settings.PRO_TIER_MONTHLY_LIMIT:
            raise HTTPException(status_code=402, detail="Pro tier monthly cover letter limit reached.")

    try:
        cover_letter_text = await llm_service.generate_cover_letter(
            resume_version_json=resume_data,
            job_title=body.job_title,
            company_name=body.company_name or "",
            job_description=body.job_description,
            user_name=current_user.full_name,
        )
    except llm_service.LLMServiceError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    cl = CoverLetter(
        user_id=current_user.id,
        resume_version_id=body.resume_version_id,
        job_title=body.job_title,
        company_name=body.company_name,
        content=cover_letter_text,
        generation_metadata={"source": "manual request"},
    )
    db.add(cl)
    
    current_user.cover_letter_count_this_month += 1
    db.add(current_user)

    await db.commit()
    await db.refresh(cl)
    return cl

@router.get("/cover-letters/{id}", response_model=CoverLetterResponse)
async def get_cover_letter(
    id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    cl = await db.get(CoverLetter, id)
    if not cl or cl.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Cover letter not found")
    return cl

@router.patch("/cover-letters/{id}", response_model=CoverLetterResponse)
async def update_cover_letter(
    id: uuid.UUID,
    body: CoverLetterUpdateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    cl = await db.get(CoverLetter, id)
    if not cl or cl.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Cover letter not found")
    
    cl.content = body.content
    await db.commit()
    await db.refresh(cl)
    return cl

@router.delete("/cover-letters/{id}", response_model=MessageResponse)
async def delete_cover_letter(
    id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    cl = await db.get(CoverLetter, id)
    if not cl or cl.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Cover letter not found")
    
    await db.delete(cl)
    await db.commit()
    return MessageResponse(message="Cover letter deleted")

@router.post("/applications/{app_id}/generate-post", response_model=MessageResponse)
async def generate_social_post(
    app_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    from app.models.application import Application
    app = await db.get(Application, app_id)
    if not app or app.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Application not found")
    
    try:
        post_text = await llm_service.generate_linkedin_post(
            job_title=app.role,
            company_name=app.company_name,
            user_name=current_user.full_name,
        )
    except llm_service.LLMServiceError as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    
    return MessageResponse(message=post_text)
