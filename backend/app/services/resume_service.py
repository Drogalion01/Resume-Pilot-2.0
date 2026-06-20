"""
app/services/resume_service.py

Resume file parsing, deterministic scoring, and AI generation orchestration.
Uses pdfplumber and python-docx for text extraction.
"""
import io
import logging
import os
import re
import uuid
from datetime import datetime
from typing import Optional, Tuple

import pdfplumber
from docx import Document
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.s3_service import s3_service

from app.config import settings
from app.core.exceptions import FileUploadError, GenerationLimitExceededError, ValidationError
from app.models.resume import AnalysisResult, Resume, ResumeVersion
from app.models.user import User
from app.services.llm_service import generate_cover_letter, generate_tailored_resume, LLMServiceError
from app.utils.resume_parser import parse_resume_text

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────────────────────
# File parsing
# ────────────────────────────────────────────────────────────────────────────────

def extract_text_from_pdf(file_bytes: bytes) -> str:
    try:
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            texts = [page.extract_text() or "" for page in pdf.pages]
            return "\n".join(texts).strip()
    except Exception as exc:
        logger.error("PDF extraction failed: %s", exc)
        raise FileUploadError("Failed to parse PDF file")


def extract_text_from_docx(file_bytes: bytes) -> str:
    try:
        doc = Document(io.BytesIO(file_bytes))
        texts = [para.text for para in doc.paragraphs]
        return "\n".join(texts).strip()
    except Exception as exc:
        logger.error("DOCX extraction failed: %s", exc)
        raise FileUploadError("Failed to parse DOCX file")


def extract_text_from_file(filename: str, file_bytes: bytes) -> str:
    ext = filename.rsplit(".", 1)[-1].lower()
    if ext == "pdf":
        return extract_text_from_pdf(file_bytes)
    elif ext in ("docx", "doc"):
        return extract_text_from_docx(file_bytes)
    elif ext == "txt":
        return file_bytes.decode("utf-8", errors="ignore").strip()
    else:
        raise FileUploadError(f"Unsupported file type: {ext}")


# ────────────────────────────────────────────────────────────────────────────────
# Resume analysis — deterministic scoring
# ────────────────────────────────────────────────────────────────────────────────

def analyze_resume(raw_text: str) -> dict:
    """
    Returns analysis dict with:
      ats_score, recruiter_score, overall_score,
      breakdown, issues, missing_keywords, suggestions
    Scoring rubric:
      - Contact completeness (email, phone, location) — 20 pts
      - Section presence (summary, experience, education, skills) — 25 pts
      - Formatting safety (no tables/graphics, safe fonts) — 15 pts
      - Measurable achievements (quantified metrics) — 20 pts
      - Action verbs usage — 10 pts
      - Keywords density / relevance — 10 pts
    """
    scores = {
        "ats_score": 0,
        "recruiter_score": 0,
        "overall_score": 0,
        "breakdown": {},
        "issues": [],
        "missing_keywords": [],
        "suggestions": [],
    }

    text_lower = raw_text.lower()
    words = re.findall(r"\b\w+\b", raw_text)
    bullet_lines = [line for line in raw_text.split("\n") if line.strip().startswith(("•", "-", "*"))]

    # --- Contact completeness (ATS)
    has_email = bool(re.search(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", raw_text))
    has_phone = bool(re.search(r"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}", raw_text))
    has_location = bool(re.search(r"\b([A-Z][a-z]+,\s*[A-Z]{2}|[A-Z][a-z]+)\b", raw_text))  # crude
    contact_score = (int(has_email) + int(has_phone) + int(has_location)) * (20/3)
    scores["breakdown"]["contact"] = round(contact_score)

    # --- Section presence
    required_sections = ["summary", "experience", "education", "skills"]
    found = [s for s in required_sections if s in text_lower]
    section_score = (len(found) / len(required_sections)) * 25
    scores["breakdown"]["sections"] = round(section_score)
    missing = [s for s in required_sections if s not in found]
    if missing:
        scores["issues"].append(f"Missing sections: {', '.join(missing)}")

    # --- Formatting (detect potential ATS unfriendly patterns)
    formatting_issues = []
    if "table" in text_lower or "|" in raw_text:  # crude
        formatting_issues.append("Possible table usage — may break ATS parsing")
    if len(raw_text) > 100000:
        formatting_issues.append("Resume is very long (>100K chars) — consider condensing")
    format_score = 15 - (len(formatting_issues) * 5)
    scores["breakdown"]["formatting"] = max(0, format_score)
    scores["issues"].extend(formatting_issues)

    # --- Measurable achievements
    metric_pattern = r"\b(\d+%|[0-9]+(?:,\d+)*\s*(?:users?|clients?|revenue?|budget|team|projects?|k|M|B))\b"
    metric_count = len(re.findall(metric_pattern, raw_text, re.IGNORECASE))
    achievement_score = min(20, metric_count * 2)
    scores["breakdown"]["achievements"] = achievement_score

    if metric_count < 3:
        scores["suggestions"].append("Add quantified metrics to your achievements (e.g. 'increased revenue 30%')")

    # --- Action verbs
    action_verbs = ["led", "built", "architected", "delivered", "reduced", "increased", "designed", "implemented", "created", "optimized"]
    verb_count = sum(1 for w in words if w.lower() in action_verbs)
    verb_score = min(10, verb_count)
    scores["breakdown"]["action_verbs"] = verb_score
    if verb_count < 5:
        scores["suggestions"].append("Start bullet points with strong action verbs (Led, Built, Delivered, etc.)")

    # --- Keywords density (simple — match common skills from job)
    # For MVP, suggests generic in-demand skills based on role presence
    common_skills = ["python", "sql", "api", "cloud", "agile", "ci/cd", "docker", "git"]
    matched_skills = [s for s in common_skills if s in text_lower]
    keyword_score = (len(matched_skills) / len(common_skills)) * 10
    scores["breakdown"]["keywords"] = round(keyword_score)
    missing_common = [s for s in common_skills if s not in text_lower]
    scores["missing_keywords"] = missing_common[:5]

    # Total ATS = sum breakdown
    ats = sum(scores["breakdown"].values())
    ats = min(100, max(0, ats))
    scores["ats_score"] = round(ats)

    # Recruiter score adjusts based on clarity + issues
    recruiter = ats
    if formatting_issues:
        recruiter -= len(formatting_issues) * 3
    if len(raw_text) < 200:
        recruiter -= 10  # too short
    scores["recruiter_score"] = max(0, min(100, round(recruiter)))
    scores["overall_score"] = round((scores["ats_score"] + scores["recruiter_score"]) / 2)
    scores["matched_keywords"] = matched_skills

    return scores


# ────────────────────────────────────────────────────────────────────────────────
# Resume upload + analysis workflow
# ────────────────────────────────────────────────────────────────────────────────

async def create_resume_from_upload(
    user_id: uuid.UUID,
    title: str,
    file_bytes: bytes,
    filename: str,
    db: AsyncSession,
) -> Tuple[Resume, str]:
    """
    Parse uploaded resume file, create Resume record + initial AnalysisResult.
    Returns (resume, parsed_text).
    """
    # Parse file to raw text
    raw_text = extract_text_from_file(filename, file_bytes)
    if not raw_text or len(raw_text) < 50:
        raise ValidationError("Uploaded file appears empty or unreadable")

    # Upload file to S3
    s3_key = f"resumes/{user_id}/{uuid.uuid4()}-{filename}"
    content_type = "application/pdf" if filename.lower().endswith('.pdf') else "application/octet-stream"
    s3_url = await s3_service.upload_file(file_bytes, s3_key, content_type=content_type)

    # Create Resume record
    resume = Resume(
        id=uuid.uuid4(),
        user_id=user_id,
        title=title,
        original_filename=filename,
        file_path=s3_url,
        file_type=filename.rsplit(".",1)[-1].lower(),
        raw_text=raw_text,
        parsed_json=None,
        is_master=False,
    )
    db.add(resume)
    await db.flush()

    # Create initial AnalysisResult with status=processing
    analysis = AnalysisResult(
        id=uuid.uuid4(),
        resume_id=resume.id,
        user_id=user_id,
        status="processing",
    )
    db.add(analysis)
    await db.commit()

    # Trigger background analysis (or do inline for small files)
    # For now, run inline (FastAPI BackgroundTasks recommended)
    analysis_result = analyze_resume(raw_text)
    analysis.status = "completed"
    analysis.ats_score = analysis_result["ats_score"]
    analysis.recruiter_score = analysis_result["recruiter_score"]
    analysis.overall_score = analysis_result["overall_score"]
    analysis.score_breakdown = analysis_result["breakdown"]
    analysis.issues = analysis_result["issues"]
    analysis.missing_keywords = analysis_result["missing_keywords"]
    analysis.suggestions = analysis_result["suggestions"]
    analysis.matched_keywords = analysis_result.get("matched_keywords", [])
    await db.commit()

    return resume, raw_text


# ────────────────────────────────────────────────────────────────────────────────
# AI Generation orchestration
# ────────────────────────────────────────────────────────────────────────────────

async def generate_resume_version(
    user: User,
    resume: Resume,
    job_title: str,
    job_description: str,
    company_name: Optional[str],
    db: AsyncSession,
) -> ResumeVersion:
    """
    Generate tailored resume via Gemini.
    - Parses resume raw_text → structured JSON using parse_resume_text() helper
    - Calls LLM to tailor
    - Creates ResumeVersion record + AnalysisResult for compared scores
    - Increments user generation count (with limit check)
    """
    # Enforce generation limits
    from app.services.resume_service import count_user_generations_this_month
    used, limit = count_user_generations_this_month(user, db)
    if used >= limit:
        raise GenerationLimitExceededError(tier=user.subscription_tier, limit=limit)

    # Parse master resume to JSON structure
    master_json = parse_resume_text(resume.raw_text)
    # Call LLM
    try:
        tailored = await generate_tailored_resume(
            master_resume_json=master_json,
            job_title=job_title,
            job_description=job_description,
            company_name=company_name,
        )
    except LLMServiceError as exc:
        logger.error("Generation failed: %s", exc)
        raise

    # Create version
    version = ResumeVersion(
        id=uuid.uuid4(),
        resume_id=resume.id,
        user_id=user.id,
        title=f"Tailored for {job_title}",
        content_json=tailored,
        job_title=job_title,
        job_description=job_description,
        company_name=company_name,
        generation_mode="tailored",
        generated_from_resume_id=resume.id,
    )
    db.add(version)
    await db.flush()

    # Create AnalysisResult for this generated version (LLM already scored)
    ar = AnalysisResult(
        id=uuid.uuid4(),
        resume_id=None,
        resume_version_id=version.id,
        user_id=user.id,
        ats_score=tailored.get("scoring", {}).get("ats_score"),
        recruiter_score=tailored.get("scoring", {}).get("recruiter_score"),
        overall_score=tailored.get("scoring", {}).get("overall_score"),
        job_title=job_title,
        model_used="gemini-1.5-flash",
    )
    db.add(ar)

    # Bump counter
    user.generation_count_this_month += 1
    if not user.generation_reset_date or user.generation_reset_date.month != datetime.now().month:
        user.generation_reset_date = datetime.now()
        user.generation_count_this_month = 1

    await db.commit()
    return version


async def generate_cover_letter_for_version(
    user: User,
    version: ResumeVersion,
    job_title: str,
    company_name: str,
    job_description: Optional[str],
    db: AsyncSession,
) -> uuid.UUID:
    """
    Generate cover letter for an existing resume version.
    Returns the CoverLetter ID.
    """
    used, limit = count_user_generations_this_month(user, db)
    if used >= limit:
        raise GenerationLimitExceededError(tier=user.subscription_tier, limit=limit)

    content = await generate_cover_letter(
        resume_version_json=version.content_json,
        job_title=job_title,
        company_name=company_name,
        job_description=job_description,
        user_name=user.full_name,
    )

    from app.models.generation import CoverLetter
    cover = CoverLetter(
        id=uuid.uuid4(),
        user_id=user.id,
        resume_version_id=version.id,
        job_title=job_title,
        company_name=company_name,
        content=content,
    )
    db.add(cover)
    await db.flush()
    user.generation_count_this_month += 1
    await db.commit()
    return cover.id


def count_user_generations_this_month(user: User, db: AsyncSession) -> Tuple[int, int]:
    """Returns (used, limit) for user's current month."""
    from datetime import date
    today = date.today()
    if user.generation_reset_date and user.generation_reset_date.month != today.month:
        user.generation_count_this_month = 0
        user.generation_reset_date = today
        # commit outside
    limit = settings.FREE_TIER_GENERATION_LIMIT if user.subscription_tier == "free" else settings.PRO_TIER_MONTHLY_LIMIT
    return user.generation_count_this_month, limit
