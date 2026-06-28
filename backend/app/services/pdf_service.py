"""
app/services/pdf_service.py

Generates ATS-friendly PDF files from structured resume JSON and cover letter text.
Uses PyMuPDF (fitz) which is already in requirements.txt as PyMuPDF.

Design principles:
  - Single-column layout (no tables) — maximises ATS parse accuracy
  - Clean typography: Inter/Helvetica, clear section headers
  - Returns bytes — caller decides whether to stream or store
"""
import logging
from typing import Optional

import fitz  # PyMuPDF

logger = logging.getLogger(__name__)

# ── Layout constants ──────────────────────────────────────────────────────────
PAGE_W, PAGE_H = 595, 842          # A4 points
MARGIN_L, MARGIN_R = 56, 56
MARGIN_T, MARGIN_B = 56, 56
CONTENT_W = PAGE_W - MARGIN_L - MARGIN_R

# Colours (RGB 0-1)
C_BLACK  = (0.08, 0.08, 0.08)
C_DARK   = (0.18, 0.18, 0.25)
C_PURPLE = (0.49, 0.23, 0.93)     # #7c3aed
C_GREY   = (0.58, 0.63, 0.72)
C_RULE   = (0.73, 0.75, 0.85)

# Fonts (base-14 guaranteed by PyMuPDF)
F_BOLD   = "helv"   # Helvetica-Bold alias
F_REG    = "helv"   # Helvetica


def _add_page(doc: fitz.Document) -> tuple[fitz.Page, float]:
    """Add a new page and return (page, current_y)."""
    page = doc.new_page(width=PAGE_W, height=PAGE_H)
    return page, float(MARGIN_T)


def _draw_rule(page: fitz.Page, y: float) -> None:
    page.draw_line(
        fitz.Point(MARGIN_L, y),
        fitz.Point(PAGE_W - MARGIN_R, y),
        color=C_RULE,
        width=0.5,
    )


def _insert_text(
    page: fitz.Page,
    y: float,
    text: str,
    fontsize: float = 10,
    bold: bool = False,
    color=C_BLACK,
    x_offset: float = 0,
    max_width: Optional[float] = None,
) -> float:
    """Insert text, return new y position. Wraps automatically."""
    if not text:
        return y
    x = MARGIN_L + x_offset
    width = (max_width or CONTENT_W) - x_offset
    fontname = "helv"
    flags = fitz.TEXT_ALIGN_LEFT

    # Use insert_textbox for word-wrap
    rect = fitz.Rect(x, y, x + width, y + 1000)
    used = page.insert_textbox(
        rect,
        text,
        fontsize=fontsize,
        fontname=fontname,
        color=color,
        align=flags,
    )
    # used is negative if text overflowed — estimate line height anyway
    line_height = fontsize * 1.35
    lines = max(1, abs(int(used / line_height)) if used < 0 else 1)
    # Simpler: measure actual height from textbox result
    # PyMuPDF returns float of remaining space (positive = space left, negative = overflow)
    if used < 0:
        # text did not fit — approximate: count chars / ~80 per line
        approx_lines = max(1, len(text) // 80 + text.count("\n") + 1)
        return y + approx_lines * line_height
    else:
        # used = remaining height in rect → actual used = 1000 - used
        actual_height = 1000 - used
        return y + max(actual_height, line_height)


def _section_header(page: fitz.Page, y: float, title: str) -> float:
    y += 10
    _draw_rule(page, y)
    y += 4
    page.insert_text(
        fitz.Point(MARGIN_L, y + 10),
        title.upper(),
        fontsize=8.5,
        fontname="helv",
        color=C_PURPLE,
    )
    return y + 18


# ── Public API ─────────────────────────────────────────────────────────────────

def generate_resume_pdf(resume_json: dict, job_title: str = "", company: str = "") -> bytes:
    """
    Build an ATS-friendly PDF from the tailored resume JSON.
    Returns PDF bytes.
    """
    doc = fitz.open()
    page, y = _add_page(doc)

    pi = resume_json.get("personal_info", {})
    name = pi.get("name") or "Your Name"
    email = pi.get("email") or ""
    phone = pi.get("phone") or ""
    location = pi.get("location") or ""
    linkedin = pi.get("linkedin") or ""
    github = pi.get("github") or ""

    # ── Header: name ──────────────────────────────────────────────────────────
    page.insert_text(
        fitz.Point(MARGIN_L, y + 18),
        name,
        fontsize=22,
        fontname="helv",
        color=C_DARK,
    )
    y += 28

    # Contact line
    contact_parts = [p for p in [email, phone, location, linkedin, github] if p]
    contact_str = "  ·  ".join(contact_parts)
    y = _insert_text(page, y, contact_str, fontsize=9, color=C_GREY)
    y += 4
    _draw_rule(page, y)
    y += 8

    # Target role (if provided)
    if job_title:
        y = _insert_text(page, y, f"Applying for: {job_title}" + (f" @ {company}" if company else ""),
                         fontsize=9, color=C_PURPLE)
        y += 8

    # ── Summary ───────────────────────────────────────────────────────────────
    summary = resume_json.get("summary", "")
    if summary:
        y = _section_header(page, y, "Professional Summary")
        y = _insert_text(page, y, summary, fontsize=10)
        y += 6

    # ── Skills ────────────────────────────────────────────────────────────────
    skills = resume_json.get("skills", {})
    primary = skills.get("primary", [])
    secondary = skills.get("secondary", [])
    all_skills = primary + secondary
    if all_skills:
        y = _section_header(page, y, "Skills")
        y = _insert_text(page, y, "  ·  ".join(all_skills), fontsize=10)
        y += 6

    # ── Experience ────────────────────────────────────────────────────────────
    experience = resume_json.get("experience", [])
    if experience:
        y = _section_header(page, y, "Experience")
        for exp in experience:
            if y > PAGE_H - MARGIN_B - 60:
                page, y = _add_page(doc)

            company_name = exp.get("company", "")
            title = exp.get("title", "")
            start = exp.get("start_date", "")
            end = "Present" if exp.get("is_current") else (exp.get("end_date") or "")
            date_str = f"{start} – {end}" if start else ""

            # Title line
            header_text = f"{title}  |  {company_name}"
            page.insert_text(
                fitz.Point(MARGIN_L, y + 11),
                header_text,
                fontsize=10.5,
                fontname="helv",
                color=C_DARK,
            )
            if date_str:
                page.insert_text(
                    fitz.Point(PAGE_W - MARGIN_R - 80, y + 11),
                    date_str,
                    fontsize=9,
                    fontname="helv",
                    color=C_GREY,
                )
            y += 16

            for bullet in exp.get("bullets", []):
                if y > PAGE_H - MARGIN_B - 20:
                    page, y = _add_page(doc)
                y = _insert_text(page, y, f"• {bullet}", fontsize=9.5,
                                 color=C_BLACK, x_offset=12)
                y += 2
            y += 6

    # ── Education ─────────────────────────────────────────────────────────────
    education = resume_json.get("education", [])
    if education:
        y = _section_header(page, y, "Education")
        for edu in education:
            if y > PAGE_H - MARGIN_B - 30:
                page, y = _add_page(doc)
            inst = edu.get("institution", "")
            degree = edu.get("degree", "")
            field = edu.get("field", "")
            grad = edu.get("graduation_year", "")
            line = f"{degree} {field}  –  {inst}  ({grad})" if grad else f"{degree} {field}  –  {inst}"
            y = _insert_text(page, y, line, fontsize=10)
            y += 6

    # ── Projects ──────────────────────────────────────────────────────────────
    projects = resume_json.get("projects", [])
    if projects:
        y = _section_header(page, y, "Projects")
        for proj in projects:
            if y > PAGE_H - MARGIN_B - 30:
                page, y = _add_page(doc)
            proj_name = proj.get("name", "")
            desc = proj.get("description", "")
            techs = proj.get("technologies", [])
            if proj_name:
                page.insert_text(
                    fitz.Point(MARGIN_L, y + 11),
                    proj_name,
                    fontsize=10,
                    fontname="helv",
                    color=C_DARK,
                )
                y += 14
            if desc:
                y = _insert_text(page, y, desc, fontsize=9.5)
                y += 2
            if techs:
                y = _insert_text(page, y, "Technologies: " + ", ".join(techs),
                                 fontsize=9, color=C_GREY)
            y += 6

    # ── Certifications ────────────────────────────────────────────────────────
    certs = resume_json.get("certifications", [])
    if certs:
        y = _section_header(page, y, "Certifications")
        for cert in (certs if isinstance(certs[0], str) else [str(c) for c in certs]):
            y = _insert_text(page, y, f"• {cert}", fontsize=10)
            y += 4

    doc.set_metadata({
        "title": f"Resume – {name}",
        "author": name,
        "subject": f"Tailored resume for {job_title}",
        "creator": "ResumePilot",
    })

    pdf_bytes = doc.write()
    doc.close()
    return pdf_bytes


def generate_cover_letter_pdf(
    cover_letter_text: str,
    candidate_name: str = "",
    job_title: str = "",
    company_name: str = "",
) -> bytes:
    """
    Build a clean cover letter PDF from plain text.
    Returns PDF bytes.
    """
    doc = fitz.open()
    page, y = _add_page(doc)

    # Header
    if candidate_name:
        page.insert_text(
            fitz.Point(MARGIN_L, y + 18),
            candidate_name,
            fontsize=18,
            fontname="helv",
            color=C_DARK,
        )
        y += 26

    if job_title or company_name:
        subtitle = f"Cover Letter — {job_title}" + (f" at {company_name}" if company_name else "")
        page.insert_text(
            fitz.Point(MARGIN_L, y + 12),
            subtitle,
            fontsize=10,
            fontname="helv",
            color=C_PURPLE,
        )
        y += 18

    _draw_rule(page, y)
    y += 16

    # Body
    for paragraph in cover_letter_text.split("\n\n"):
        if not paragraph.strip():
            continue
        if y > PAGE_H - MARGIN_B - 40:
            page, y = _add_page(doc)
        y = _insert_text(page, y, paragraph.strip(), fontsize=10.5)
        y += 14

    doc.set_metadata({
        "title": f"Cover Letter – {candidate_name}",
        "author": candidate_name,
        "subject": f"Cover letter for {job_title}",
        "creator": "ResumePilot",
    })

    pdf_bytes = doc.write()
    doc.close()
    return pdf_bytes
