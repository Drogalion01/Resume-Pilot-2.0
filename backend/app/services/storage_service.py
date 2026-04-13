"""
app/services/storage_service.py

Cloudinary file storage wrapper for resume PDFs/DOCXs.
"""
import logging
from typing import Optional

import cloudinary
import cloudinary.uploader

from app.config import settings

logger = logging.getLogger(__name__)

# Configure Cloudinary SDK
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True,
)

_CLOUDINARY_CONFIGURED = bool(
    settings.CLOUDINARY_CLOUD_NAME
    and settings.CLOUDINARY_API_KEY
    and settings.CLOUDINARY_API_SECRET
)


def upload_resume_file(
    file_bytes: bytes,
    filename: str,
    user_id: str,
) -> Optional[str]:
    """
    Upload a resume file to Cloudinary.
    Returns the secure URL or None if Cloudinary is not configured.
    """
    if not _CLOUDINARY_CONFIGURED:
        logger.warning("Cloudinary not configured — skipping file upload.")
        return None

    try:
        public_id = f"resumepilot/resumes/{user_id}/{filename}"
        result = cloudinary.uploader.upload(
            file_bytes,
            public_id=public_id,
            resource_type="raw",
            overwrite=True,
        )
        return result.get("secure_url")
    except Exception as exc:
        logger.error("Cloudinary upload failed: %s", exc)
        return None


def delete_resume_file(cloudinary_url: str) -> bool:
    """Delete a resume file from Cloudinary by its URL."""
    if not _CLOUDINARY_CONFIGURED or not cloudinary_url:
        return False
    try:
        # Extract public_id from URL
        # e.g. https://res.cloudinary.com/cloud/raw/upload/v.../resumepilot/resumes/...
        parts = cloudinary_url.split("/upload/")
        if len(parts) < 2:
            return False
        raw_path = parts[1]
        # Strip version prefix if present (v1234567890/)
        if raw_path.startswith("v") and "/" in raw_path:
            raw_path = raw_path.split("/", 1)[1]
        # Strip extension
        public_id = raw_path.rsplit(".", 1)[0]
        cloudinary.uploader.destroy(public_id, resource_type="raw")
        return True
    except Exception as exc:
        logger.error("Cloudinary delete failed: %s", exc)
        return False
