"""
app/schemas/interview.py — Interview request/response schemas
"""
import enum
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

class InterviewType(str, enum.Enum):
    PHONE = "phone"
    VIDEO = "video"
    ONSITE = "onsite"


class InterviewCreate(BaseModel):
    interview_type: InterviewType
    scheduled_at: datetime
    duration_minutes: Optional[int] = None
    location_or_link: Optional[str] = None
    notes: Optional[str] = None
    reminder_enabled: bool = True


class InterviewUpdate(BaseModel):
    interview_type: Optional[InterviewType] = None
    scheduled_at: Optional[datetime] = None
    duration_minutes: Optional[int] = None
    location_or_link: Optional[str] = None
    notes: Optional[str] = None
    reminder_enabled: Optional[bool] = None


class InterviewOut(BaseModel):
    id: uuid.UUID
    application_id: uuid.UUID
    user_id: uuid.UUID
    interview_type: InterviewType
    scheduled_at: datetime
    duration_minutes: Optional[int] = None
    location_or_link: Optional[str] = None
    notes: Optional[str] = None
    reminder_enabled: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
