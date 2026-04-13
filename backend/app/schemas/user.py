"""
app/schemas/user.py

Profile and settings schemas.
"""
import uuid
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class UserSettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    theme_preference: str
    email_notifications_enabled: bool
    interview_reminders_enabled: bool
    marketing_emails_enabled: bool
    target_roles: Optional[List[str]] = None


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    initials: Optional[str] = None
    onboarding_completed: Optional[bool] = None


class UpdateSettingsRequest(BaseModel):
    theme_preference: Optional[str] = None
    email_notifications_enabled: Optional[bool] = None
    interview_reminders_enabled: Optional[bool] = None
    marketing_emails_enabled: Optional[bool] = None
    target_roles: Optional[List[str]] = None


class UserProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    initials: Optional[str] = None
    email_verified: bool
    plan: str
    onboarding_completed: bool
    settings: Optional[UserSettingsOut] = None
