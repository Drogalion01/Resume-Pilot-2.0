from typing import List, Optional, Dict, Any
from pydantic import BaseModel
import uuid
from datetime import datetime

class TailoredResumeSchema(BaseModel):
    personal_info: Dict[str, Any]
    summary: str
    skills: Dict[str, List[str]]
    experience: List[Dict[str, Any]]
    education: List[Dict[str, Any]]
    projects: List[Dict[str, Any]]
    certifications: List[str]
    scoring: Dict[str, Any]

class GenerationResultResponse(BaseModel):
    resume_version_id: uuid.UUID
    tailored_resume: TailoredResumeSchema
    ats_score: int
    recruiter_score: int
    overall_score: int
    score_improvement: Optional[int] = None
    matched_keywords: List[str]
    missing_keywords: List[str]
    cover_letter: Optional[str] = None
    cover_letter_id: Optional[uuid.UUID] = None
    generation_metadata: Dict[str, Any]

class CoverLetterResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    resume_version_id: Optional[uuid.UUID] = None
    job_title: str
    company_name: Optional[str] = None
    content: str
    generation_metadata: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

class GenerateRequest(BaseModel):
    job_title: str
    job_description: str
    company_name: Optional[str] = None
    generate_cover_letter: bool = True

class CoverLetterCreateRequest(BaseModel):
    resume_version_id: Optional[uuid.UUID] = None
    job_title: str
    company_name: Optional[str] = None
    job_description: str

class CoverLetterUpdateRequest(BaseModel):
    content: str
