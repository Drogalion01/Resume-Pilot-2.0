"""
app/schemas/application.py

Pydantic schemas for applications, interviews, reminders, notes, timeline.
"""
import enum
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

# ── Enums ────────────────────────────────────────────────────────────────────────

class ApplicationStatus(str, enum.Enum):
    SAVED = "saved"
    APPLIED = "applied"
    ASSESSMENT = "assessment"
    HR_SCREEN = "hr_screen"
    TECHNICAL = "technical"
    FINAL_ROUND = "final_round"
    OFFER = "offer"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"


# ── Requests ────────────────────────────────────────────────────────────────────

class ApplicationCreate(BaseModel):
    company_name: str
    role: str
    status: Optional[ApplicationStatus] = None
    location: Optional[str] = None
    source_url: Optional[str] = None
    recruiter_name: Optional[str] = None
    resume_version_id: Optional[uuid.UUID] = None
    cover_letter_id: Optional[uuid.UUID] = None


class ApplicationUpdate(BaseModel):
    company_name: Optional[str] = None
    role: Optional[str] = None
    status: Optional[ApplicationStatus] = None
    location: Optional[str] = None
    source_url: Optional[str] = None
    recruiter_name: Optional[str] = None
    resume_version_id: Optional[uuid.UUID] = None
    cover_letter_id: Optional[uuid.UUID] = None


class NoteCreate(BaseModel):
    content: str


# ── Responses ───────────────────────────────────────────────────────────────────

class ApplicationListItem(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    company_name: str
    role: str
    status: ApplicationStatus
    created_at: datetime
    latest_activity_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class InterviewOut(BaseModel):
    id: uuid.UUID
    application_id: uuid.UUID
    user_id: uuid.UUID
    interview_type: str
    scheduled_at: datetime
    duration_minutes: Optional[int] = None
    location_or_link: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ReminderOut(BaseModel):
    id: uuid.UUID
    message: Optional[str] = None
    remind_at: datetime
    is_sent: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class NoteOut(BaseModel):
    id: uuid.UUID
    content: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TimelineEventOut(BaseModel):
    id: uuid.UUID
    application_id: uuid.UUID
    user_id: uuid.UUID
    event_type: str
    title: str
    description: str = ""  # Dart model requires non-null; default to empty string
    metadata_json: Optional[dict] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ApplicationDetail(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    company_name: str
    role: str
    status: ApplicationStatus
    location: Optional[str] = None
    source_url: Optional[str] = None
    recruiter_name: Optional[str] = None
    applied_date: Optional[datetime] = None
    notes_text: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    interviews: list[InterviewOut] = []
    reminders: list[ReminderOut] = []
    notes: list[NoteOut] = []
    timeline_events: list[TimelineEventOut] = []

    model_config = ConfigDict(from_attributes=True)
