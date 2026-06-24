"""
app/routes/resumes.py — Full resume management
"""
import logging
import os
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.dependencies import CurrentUser, get_db
from app.models.resume import AnalysisResult, Resume, ResumeVersion
from app.models.user import User
from app.services.s3_service import s3_service
from app.schemas.resume import (
    AnalysisResultOut,
    ResumeDetail,
    ResumeUploadRequest,
    ResumeWithVersions,
    ResumeVersionCreateRequest,
    ResumeVersionOut,
    ResumeListItem,
)
from app.services.resume_service import (
    analyze_resume,
    create_resume_from_upload,
    extract_text_from_file,
)

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/", response_model=list[ResumeListItem])
async def list_resumes(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Resume)
        .where(Resume.user_id == current_user.id)
        .order_by(Resume.created_at.desc())
    )
    resumes = result.scalars().all()

    # Attach latest analysis score
    items = []
    for r in resumes:
        analysis = await db.execute(
            select(AnalysisResult)
            .where(AnalysisResult.resume_id == r.id)
            .order_by(AnalysisResult.created_at.desc())
            .limit(1)
        )
        latest = analysis.scalar_one_or_none()
        items.append({
            "id": r.id,
            "title": r.title,
            "file_type": r.file_type,
            "created_at": r.created_at,
            "latest_score": latest.overall_score if latest else None,
        })
    return items


@router.post("/", response_model=ResumeDetail, status_code=status.HTTP_201_CREATED)
async def upload_resume(
    current_user: CurrentUser,
    title: str = Form(...),
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None,
    db: AsyncSession = Depends(get_db),
):
    """
    Upload a resume file (PDF, DOCX, TXT).
    Parses to raw_text, creates Resume + initial AnalysisResult.
    """
    allowed_extensions = {"pdf", "docx", "doc", "txt"}
    ext = file.filename.rsplit(".", 1)[-1].lower()
    if ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {ext}")

    file_bytes = await file.read()
    if len(file_bytes) > settings.MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {settings.MAX_FILE_SIZE_MB} MB)")

    # Create resume + analysis (inline for now)
    try:
        resume, raw_text = await create_resume_from_upload(
            user_id=current_user.id,
            title=title,
            file_bytes=file_bytes,
            filename=file.filename,
            db=db,
        )
    except Exception as exc:
        logger.exception("Resume upload failed")
        raise HTTPException(status_code=500, detail=str(exc))

    return ResumeDetail.model_validate(resume)


@router.get("/{resume_id}", response_model=ResumeWithVersions)
async def get_resume(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")

    # Versions
    versions = await db.execute(
        select(ResumeVersion)
        .where(ResumeVersion.resume_id == resume_id)
        .order_by(ResumeVersion.created_at.desc())
    )
    versions_list = versions.scalars().all()

    # Latest analysis (attached to resume directly)
    analysis = await db.execute(
        select(AnalysisResult)
        .where(AnalysisResult.resume_id == resume_id)
        .order_by(AnalysisResult.created_at.desc())
        .limit(1)
    )
    latest_analysis = analysis.scalar_one_or_none()

    return ResumeWithVersions(
        resume=ResumeDetail.model_validate(resume),
        versions=[ResumeVersionOut.model_validate(v) for v in versions_list],
        latest_analysis=AnalysisResultOut.model_validate(latest_analysis) if latest_analysis else None,
    )


@router.delete("/{resume_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_resume(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")
        
    if resume.file_path and resume.file_path.startswith("s3://"):
        s3_key = resume.file_path.split(f"s3://{settings.S3_BUCKET_NAME}/")[-1]
        await s3_service.delete_file(s3_key)
        
    await db.delete(resume)
    await db.commit()
    return None

@router.get("/{resume_id}/download")
async def download_resume(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Get a presigned S3 URL to download the original resume PDF/DOCX"""
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")
        
    if not resume.file_path:
        raise HTTPException(status_code=404, detail="Original file not found")
        
    if resume.file_path.startswith("s3://"):
        s3_key = resume.file_path.split(f"s3://{settings.S3_BUCKET_NAME}/")[-1]
        url = await s3_service.generate_presigned_url(s3_key)
        if not url:
            raise HTTPException(status_code=500, detail="Failed to generate download link")
        return {"download_url": url}
    
    # Fallback to local
    return {"download_url": resume.file_path}


@router.get("/{resume_id}/analysis", response_model=AnalysisResultOut)
async def get_resume_analysis(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")
    result = await db.execute(
        select(AnalysisResult)
        .where(AnalysisResult.resume_id == resume_id)
        .order_by(AnalysisResult.created_at.desc())
        .limit(1)
    )
    analysis = result.scalar_one_or_none()
    if not analysis:
        raise HTTPException(status_code=404, detail="No analysis found")
    return AnalysisResultOut.model_validate(analysis)


@router.post("/{resume_id}/analyze", response_model=AnalysisResultOut)
async def analyze_resume_endpoint(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Trigger (re)analysis of a resume."""
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")
    if not resume.raw_text:
        raise HTTPException(status_code=400, detail="Resume has no text content")

    analysis_dict = analyze_resume(resume.raw_text)

    # Retrieve similar benchmarks using RAG
    from app.services.rag_service import rag_service
    benchmarks = await rag_service.retrieve_similar_benchmarks(
        resume_text=resume.raw_text,
        db=db,
        limit=5
    )

    analysis = AnalysisResult(
        id=uuid.uuid4(),
        resume_id=resume_id,
        user_id=current_user.id,
        ats_score=analysis_dict["ats_score"],
        recruiter_score=analysis_dict["recruiter_score"],
        overall_score=analysis_dict["overall_score"],
        score_breakdown=analysis_dict["breakdown"],
        issues=analysis_dict["issues"],
        missing_keywords=analysis_dict["missing_keywords"],
        suggestions=analysis_dict["suggestions"],
        matched_keywords=analysis_dict.get("matched_keywords"),
        reference_comparisons=benchmarks,
    )
    db.add(analysis)
    await db.commit()
    await db.refresh(analysis)
    return AnalysisResultOut.model_validate(analysis)


@router.get("/{resume_id}/versions", response_model=list[ResumeVersionOut])
async def list_versions(
    resume_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")
    result = await db.execute(
        select(ResumeVersion)
        .where(ResumeVersion.resume_id == resume_id)
        .order_by(ResumeVersion.created_at.desc())
    )
    versions = result.scalars().all()
    return [ResumeVersionOut.model_validate(v) for v in versions]


@router.post("/{resume_id}/versions", response_model=ResumeVersionOut, status_code=status.HTTP_201_CREATED)
async def create_version(
    resume_id: uuid.UUID,
    body: ResumeVersionCreateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    resume = await db.get(Resume, resume_id)
    if not resume or resume.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Resume not found")

    version = ResumeVersion(
        id=uuid.uuid4(),
        resume_id=resume_id,
        user_id=current_user.id,
        title=body.title,
        content_json=body.content_json,
        job_title=body.job_title,
        job_description=body.job_description,
        company_name=body.company_name,
        generation_mode=body.generation_mode,
    )
    db.add(version)
    await db.commit()
    await db.refresh(version)
    return ResumeVersionOut.model_validate(version)


@router.patch("/resume-versions/{version_id}", response_model=ResumeVersionOut)
async def update_version(
    version_id: uuid.UUID,
    body: ResumeVersionCreateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    version = await db.get(ResumeVersion, version_id)
    if not version or version.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Version not found")
    version.title = body.title
    version.content_json = body.content_json
    version.job_title = body.job_title
    version.job_description = body.job_description
    version.company_name = body.company_name
    version.generation_mode = body.generation_mode
    await db.commit()
    await db.refresh(version)
    return ResumeVersionOut.model_validate(version)
