"""
app/services/ai_service.py

AI service with MOCK MODE (MVP default) and real Gemini 1.5 Flash (Phase 4).
Interface is identical in both modes — zero Flutter changes needed when switching.

Set AI_MOCK_MODE=false in .env and provide GEMINI_API_KEY to go live.
"""
import logging
import random
from typing import Optional

from app.config import settings

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# MOCK DATA — realistic fake responses for development
# ─────────────────────────────────────────────────────────────────────────────

_MOCK_REWRITES = [
    {
        "original": "Responsible for writing code for the backend",
        "improved": "Architected and delivered RESTful microservices handling 50K+ daily requests, reducing p99 latency by 35%",
    },
    {
        "original": "Helped with the website redesign",
        "improved": "Led end-to-end redesign of company website, increasing conversion rate by 28% and reducing bounce rate by 17%",
    },
    {
        "original": "Worked on machine learning models",
        "improved": "Built and deployed 3 production ML models (XGBoost, BERT) achieving 94% classification accuracy on 1M+ records",
    },
]

_MOCK_KEYWORDS = {
    "software engineer": ["REST API", "CI/CD", "Docker", "Kubernetes", "System Design", "Agile", "TypeScript"],
    "data scientist": ["Python", "SQL", "TensorFlow", "PyTorch", "A/B Testing", "Feature Engineering", "MLOps"],
    "product manager": ["Roadmap", "OKRs", "User Research", "Stakeholder Management", "Agile", "PRD", "KPIs"],
    "default": ["Leadership", "Cross-functional", "Data-driven", "Stakeholder", "Scalable", "Agile"],
}

_MOCK_COVER_LETTER = """Dear Hiring Team,

I am excited to apply for the {role} position at {company}. With a strong background in {background}, I bring a proven track record of delivering impactful results in fast-paced environments.

In my previous roles, I have consistently driven measurable outcomes — from architecting scalable systems to leading cross-functional teams toward ambitious goals. I am particularly drawn to {company}'s mission and believe my skills in {skills} align perfectly with your needs.

I would welcome the opportunity to discuss how my experience can contribute to your team's success.

Best regards,
{name}"""


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────


async def rewrite_bullets(
    bullets: list[str],
    target_role: Optional[str] = None,
    context: Optional[str] = None,
) -> list[dict]:
    """
    Rewrite weak resume bullet points into strong, metric-driven ones.
    Returns list of {original, improved} dicts.
    """
    if settings.AI_MOCK_MODE:
        logger.info("[AI MOCK] rewrite_bullets called for %d bullets", len(bullets))
        return [
            random.choice(_MOCK_REWRITES) | {"original": b}
            for b in bullets
        ]

    # ── Real Gemini call (Phase 4) ─────────────────────────────────────────
    return await _gemini_rewrite_bullets(bullets, target_role, context)


async def generate_cover_letter(
    resume_text: str,
    company_name: str,
    role: str,
    user_name: Optional[str] = None,
    jd_text: Optional[str] = None,
) -> str:
    """Generate a personalised cover letter for a job application."""
    if settings.AI_MOCK_MODE:
        logger.info("[AI MOCK] generate_cover_letter for %s @ %s", role, company_name)
        return _MOCK_COVER_LETTER.format(
            role=role,
            company=company_name,
            background="software engineering and product development",
            skills="Python, system design, and team leadership",
            name=user_name or "Your Name",
        )

    return await _gemini_generate_cover_letter(
        resume_text, company_name, role, user_name, jd_text
    )


async def suggest_keywords(
    resume_text: str,
    target_role: str,
    jd_text: Optional[str] = None,
) -> list[str]:
    """Suggest ATS keywords missing from the resume for a target role."""
    if settings.AI_MOCK_MODE:
        logger.info("[AI MOCK] suggest_keywords for role=%s", target_role)
        role_key = target_role.lower()
        keywords = _MOCK_KEYWORDS.get(role_key, _MOCK_KEYWORDS["default"])
        return keywords

    return await _gemini_suggest_keywords(resume_text, target_role, jd_text)


# ─────────────────────────────────────────────────────────────────────────────
# Real Gemini implementations (Phase 4 — stubs for now)
# ─────────────────────────────────────────────────────────────────────────────


async def _gemini_rewrite_bullets(
    bullets: list[str],
    target_role: Optional[str],
    context: Optional[str],
) -> list[dict]:
    """TODO Phase 4: Replace with real google-generativeai call."""
    raise NotImplementedError("Gemini integration — Phase 4")


async def _gemini_generate_cover_letter(
    resume_text: str,
    company_name: str,
    role: str,
    user_name: Optional[str],
    jd_text: Optional[str],
) -> str:
    """TODO Phase 4: Replace with real google-generativeai call."""
    raise NotImplementedError("Gemini integration — Phase 4")


async def _gemini_suggest_keywords(
    resume_text: str,
    target_role: str,
    jd_text: Optional[str],
) -> list[str]:
    """TODO Phase 4: Replace with real google-generativeai call."""
    raise NotImplementedError("Gemini integration — Phase 4")
