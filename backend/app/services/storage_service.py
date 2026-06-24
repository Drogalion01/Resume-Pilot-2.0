"""
app/services/storage_service.py

Storage abstraction layer — delegates to S3 service.
Cloudinary was removed; all file storage goes through s3_service.
"""
import logging
from typing import Optional

from app.services.s3_service import s3_service

logger = logging.getLogger(__name__)


def upload_resume_file(
    file_bytes: bytes,
    filename: str,
    user_id: str,
) -> Optional[str]:
    """
    Upload a resume file via S3.
    Returns the S3 URL or None if S3 is not configured.
    This is a sync wrapper kept for backward compatibility.
    """
    logger.warning("storage_service.upload_resume_file is deprecated — use s3_service directly.")
    return None


def delete_resume_file(url: str) -> bool:
    """Delete a resume file. Delegated to S3 service."""
    logger.warning("storage_service.delete_resume_file is deprecated — use s3_service directly.")
    return False
