"""
app/utils/resume_parser.py

Resume text parsing utilities:
  - extract_contact_info()
  - extract_sections()
  - to_structured_json()
"""
import re
from typing import Dict, List, Optional


def extract_contact_info(text: str) -> Dict[str, Optional[str]]:
    """
    Very basic regex-based contact extraction.
    Returns: {email, phone, location}
    """
    email_match = re.search(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", text)
    phone_match = re.search(r"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}", text)
    # location: first line with city/state or just city — crude
    location = None
    for line in text.split("\n")[:10]:
        if re.search(r"\b([A-Z][a-z]+,\s*[A-Z]{2})\b", line):
            location = line.strip()
            break
    return {
        "email": email_match.group(0) if email_match else None,
        "phone": phone_match.group(0) if phone_match else None,
        "location": location,
    }


def extract_sections(text: str) -> Dict[str, str]:
    """
    Split resume into major sections by common headings.
    Returns {section_name: section_text}.
    """
    section_headings = [
        "summary", "profile", "objective",
        "experience", "work experience", "employment",
        "education",
        "skills", "technical skills",
        "projects",
        "certifications", "certificates",
        "awards", "honors",
        "publications",
    ]
    # Use regex to split
    pattern = re.compile(r"(?i)^(?:[•\-\*]?\s*(?:" + "|".join(section_headings) + r")\b\s*)", re.MULTILINE)
    matches = list(pattern.finditer(text))
    sections = {}
    if not matches:
        return {"full": text}
    for i, match in enumerate(matches):
        sec_name = match.group().strip().lower()
        start = match.end()
        end = matches[i+1].start() if i+1 < len(matches) else len(text)
        sections[sec_name] = text[start:end].strip()
    return sections


def parse_resume_text(raw_text: str) -> dict:
    """
    Convert raw resume text into a structured JSON representation
    suitable for LLM consumption.
    """
    sections = extract_sections(raw_text)
    contact = extract_contact_info(raw_text)

    # Extract experience items (very simple bullet grouping)
    experience = []
    exp_section = sections.get("experience") or sections.get("work experience") or ""
    for line in exp_section.split("\n"):
        line = line.strip()
        if not line:
            continue
        # Heuristic: lines starting with • or - are bullets; company/date may be in same line or next
        # This is a rough MVP — LLM will do heavy lifting later.
        experience.append({"raw": line})

    return {
        "contact": contact,
        "sections": sections,
        "experience_bullets": experience,
    }
