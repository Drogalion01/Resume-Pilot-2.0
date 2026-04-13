"""
app/schemas/common.py

Shared response wrappers and utility schemas.
"""
from typing import Any, Generic, List, Optional, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class MessageResponse(BaseModel):
    """Generic success message response."""
    message: str


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated list response."""
    items: List[T]
    total: int
    page: int
    per_page: int
    pages: int


class ErrorDetail(BaseModel):
    """Structured error detail payload."""
    code: str
    message: str
    details: Optional[Any] = None
