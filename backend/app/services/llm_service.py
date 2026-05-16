"""
app/services/llm_service.py

LLM integration layer — Google Gemini 1.5 Flash.
Handles:
  - Resume tailoring (JSON output)
  - Cover letter generation (plain text)
  - Keyword suggestion / scoring helpers

Chat mode: uses `generate_content_async()` with structured output via response_mime.
"""
import json
import logging
from typing import Optional

import google.generativeai as genai
from google.generativeai.types import GenerationConfig

from app.config import settings

logger = logging.getLogger(__name__)

# Configure Gemini
if not settings.AI_MOCK_MODE:
    genai.configure(api_key=settings.GEMINI_API_KEY)

# Model configuration
MODEL_NAME = "gemini-1.5-flash"
DEFAULT_MAX_TOKENS = 3000
COVER_LETTER_MAX_TOKENS = 600


# ────────────────────────────────────────────────────────────────────────────────
# System prompts
# ────────────────────────────────────────────────────────────────────────────────

RESUME_GENERATION_SYSTEM = """You are an expert resume writer and ATS specialist.
You receive a master resume (candidate's full career history as structured JSON) and a job description.
Your task is to produce a TAILORED version of this resume optimized specifically for the given role.

Rules:
1. SELECT only the most relevant experiences, skills, and achievements for this role. Remove everything else.
2. REORDER sections so the most relevant content appears first.
3. REWRITE bullet points:
   - Use strong action verbs (Delivered, Built, Architected, Led, Reduced, Increased)
   - Add quantified metrics wherever the original implies measurable impact
   - Mirror specific terminology and keywords from the job description
   - Pattern: [Action verb] [what you did] [measurable result]
4. HIGHLIGHT transferable skills the candidate may not have emphasized.
5. SCORE the result:
   - ATS score (0-100): keyword match, required sections, formatting signals
   - Recruiter score (0-100): clarity, achievement orientation, relevance
   - List matched keywords and missing keywords.
6. Respond ONLY with valid JSON matching the provided schema. No markdown, no explanations.
"""

COVER_LETTER_SYSTEM = """You are an expert career writer.
Write a compelling, concise cover letter for this candidate applying to the specified role.

Requirements:
- Exactly 3 paragraphs
- Paragraph 1: Strong opening hook; be specific to this company/role
- Paragraph 2: Prove value with 2-3 specific achievements; be concrete
- Paragraph 3: Forward-looking close with clear call to action
- Match the tone of the job description (formal vs casual)
- Total length: 200-280 words
Respond with plain text only. No JSON. No markdown."""


# ────────────────────────────────────────────────────────────────────────────────
# Public API
# ────────────────────────────────────────────────────────────────────────────────

async def generate_tailored_resume(
    master_resume_json: dict,
    job_title: str,
    job_description: str,
    company_name: Optional[str] = None,
) -> dict:
    """
    Generate a tailored resume JSON from a master resume.
    Returns dict matching ResumeGenerationResponse schema:
      {
        personal_info, summary, skills, experience, education, projects, certifications,
        scoring: {ats_score, recruiter_score, overall_score, matched_keywords, missing_keywords, score_reasoning}
      }
    """
    if settings.AI_MOCK_MODE:
        return _mock_tailored_resume()

    model = genai.GenerativeModel(
        model_name=MODEL_NAME,
        system_instruction=RESUME_GENERATION_SYSTEM,
    )

    user_prompt = f"""
MASTER RESUME (JSON):
{json.dumps(master_resume_json, indent=2)}

JOB TITLE: {job_title}
COMPANY: {company_name or "Company"}
JOB DESCRIPTION:
{job_description}

Please produce the tailored resume JSON according to the schema.
"""

    try:
        response = await model.generate_content_async(
            contents=user_prompt,
            generation_config=GenerationConfig(
                temperature=0.7,
                top_p=0.95,
                top_k=40,
                max_output_tokens=3000,
                response_mime={"type": "application/json"},
            ),
        )
        text = response.text
        return json.loads(text)
    except Exception as exc:
        logger.exception("Gemini resume generation failed")
        # Retry once with repair prompt
        try:
            repair_prompt = "Your previous response was not valid JSON. Please return ONLY valid JSON matching the schema."
            response2 = await model.generate_content_async([repair_prompt, user_prompt])
            return json.loads(response2.text)
        except Exception:
            raise LLMServiceError("Failed to generate resume — malformed response")


async def generate_cover_letter(
    resume_version_json: dict,
    job_title: str,
    company_name: str,
    job_description: Optional[str] = None,
    user_name: Optional[str] = None,
) -> str:
    """
    Generate a plain-text cover letter (200-280 words, 3 paragraphs).
    """
    if settings.AI_MOCK_MODE:
        return _mock_cover_letter(job_title, company_name, user_name)

    model = genai.GenerativeModel(
        model_name=MODEL_NAME,
        system_instruction=COVER_LETTER_SYSTEM,
    )

    # Build a short resume summary for context
    summary = resume_version_json.get("summary", "")
    experience = "; ".join([
        f"{e.get('title')} at {e.get('company')}" for e in resume_version_json.get("experience", [])[:3]
    ])

    prompt = f"""
CANDIDATE SUMMARY: {summary}
RELEVANT EXPERIENCE: {experience}

JOB TITLE: {job_title}
COMPANY: {company_name}
JOB DESCRIPTION:
{job_description or "Not provided"}

Write a 3-paragraph cover letter tailored to this role.
"""
    try:
        response = await model.generate_content_async(
            contents=prompt,
            generation_config=GenerationConfig(
                temperature=0.8,
                top_p=0.95,
                max_output_tokens=600,
            ),
        )
        return response.text
    except Exception as exc:
        logger.exception("Gemini cover letter generation failed")
        raise LLMServiceError("Failed to generate cover letter")


# ═══════════════════════════════════════════════════════════════════════════════
# Mock implementations (development)
# ═══════════════════════════════════════════════════════════════════════════════

def _mock_tailored_resume() -> dict:
    return {
        "personal_info": {
            "name": "Jane Doe",
            "email": "jane@example.com",
            "phone": "+1-555-0123",
            "location": "San Francisco, CA",
            "linkedin": None,
            "github": None,
            "portfolio": None,
        },
        "summary": "Results-driven software engineer with 5+ years building scalable systems.",
        "skills": {
            "primary": ["Python", "FastAPI", "PostgreSQL", "Docker", "Kubernetes"],
            "secondary": ["React", "AWS", "Terraform"],
        },
        "experience": [
            {
                "company": "TechCorp",
                "title": "Senior Backend Engineer",
                "start_date": "2022-01",
                "end_date": None,
                "is_current": True,
                "bullets": [
                    "Architected RESTful microservices handling 50K+ daily requests, reducing p99 latency by 35%",
                    "Built CI/CD pipelines with GitHub Actions, cutting deployment time by 80%",
                ],
            }
        ],
        "education": [
            {
                "institution": "University of Example",
                "degree": "B.S.",
                "field": "Computer Science",
                "graduation_year": "2018",
            }
        ],
        "projects": [],
        "certifications": [],
        "scoring": {
            "ats_score": 85,
            "recruiter_score": 90,
            "overall_score": 88,
            "matched_keywords": ["Python", "FastAPI", "PostgreSQL", "microservices"],
            "missing_keywords": ["Docker", "Kubernetes"],
            "score_reasoning": "Strong technical match. ATS score reduced by missing Docker keyword.",
        },
    }


def _mock_cover_letter(job_title: str, company_name: str, user_name: Optional[str]) -> str:
    name = user_name or "Candidate"
    return f"""Dear {company_name} Hiring Team,

I am writing to express my strong interest in the {job_title} position at {company_name}. With a proven track record in software engineering and a passion for building impactful products, I am confident that my skills and experience align well with your team's needs.

In my previous roles, I have consistently delivered measurable outcomes — from architecting scalable systems that handle millions of requests to leading cross-functional teams toward ambitious product goals. I am particularly drawn to {company_name}'s mission and believe my background in backend development and system design would allow me to contribute meaningfully from day one.

I would welcome the opportunity to discuss how my experience can contribute to {company_name}'s continued success. Thank you for considering my application.

Best regards,
{name}"""


class LLMServiceError(Exception):
    pass
