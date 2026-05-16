"""
app/schemas/resume.py

Pydantic schemas for resumes, versions, and analysis.
"""
import enum
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ── Enums ───────────────────────────────────────────────────────────────────────

class ResumeVersionMode(str, enum.Enum):
    MANUAL = "manual"
    TAILORED = "tailored"


# ── Requests ────────────────────────────────────────────────────────────────────

class ResumeUploadRequest(BaseModel):
    """Multipart body — handled by UploadFile, title separate."""
    title: str = Field(..., min_length=1, max_length=255)


class ResumeVersionCreateRequest(BaseModel):
    title: str
    content_json: dict
    job_title: Optional[str] = None
    job_description: Optional[str] = None
    company_name: Optional[str] = None
    generation_mode: ResumeVersionMode = ResumeVersionMode.MANUAL


# ── Responses ───────────────────────────────────────────────────────────────────

class ResumeListItem(BaseModel):
    id: uuid.UUID
    title: str
    file_type: Optional[str]
    created_at: datetime
    latest_score: Optional[int] = None  # overall_score from latest analysis

    model_config = ConfigDict(from_attributes=True)


class ResumeDetail(BaseModel):
    id: uuid.UUID
    title: str
    original_filename: Optional[str]
    file_type: Optional[str]
    raw_text: Optional[str] = None
    is_master: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ResumeVersionOut(BaseModel):
    id: uuid.UUID
    title: str
    content_json: dict
    job_title: Optional[str]
    job_description: Optional[str]
    company_name: Optional[str]
    generation_mode: ResumeVersionMode
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AnalysisResultOut(BaseModel):
    id: uuid.UUID
    status: str  # processing | completed | failed
    ats_score: Optional[int] = None
    recruiter_score: Optional[int] = None
    overall_score: Optional[int] = None
    score_breakdown: Optional[dict] = None
    issues: Optional[list] = None
    missing_keywords: Optional[list] = None
    matched_keywords: Optional[list] = None
    suggestions: Optional[list] = None
    job_title: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ResumeWithVersions(BaseModel):
    resume: ResumeDetail
    versions: list[ResumeVersionOut]
    latest_analysis: Optional[AnalysisResultOut] = None
