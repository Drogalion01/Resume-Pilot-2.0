import json
import logging
import re
from typing import Optional, Tuple
import asyncio
from google import genai
from google.genai import types

from app.config import settings

logger = logging.getLogger(__name__)

# Configure Gemini client — lazy init so import never crashes
_client = None

def _get_client():
    global _client
    if _client is None and settings.GEMINI_API_KEY:
        try:
            _client = genai.Client(api_key=settings.GEMINI_API_KEY)
        except Exception as e:
            logger.warning("Gemini client init failed: %s", e)
    return _client

MODEL_NAME = "gemini-1.5-flash"

class LLMServiceError(Exception):
    pass


def _clean_json_response(text: str) -> str:
    """Strip markdown code fences and whitespace from LLM response."""
    text = text.strip()
    # Remove ```json ... ``` or ``` ... ```
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


async def generate_tailored_resume(
    master_resume_json: dict,
    job_title: str,
    job_description: str,
    company_name: Optional[str] = None,
    relevant_resumes: Optional[list] = None,
) -> dict:
    client = _get_client()
    if not client:
        logger.warning("Gemini client unavailable — using mock resume")
        return _mock_tailored_resume(job_title, company_name)

    system_instruction = """You are a world-class ATS optimization expert and professional resume writer.

Your SINGLE GOAL is to rewrite the master resume to MAXIMIZE the ATS score for the specific job posting.

MANDATORY RULES:
1. Extract ALL important keywords, skills, tools, and phrases from the job description
2. Naturally weave those exact keywords into the experience bullets, summary, and skills sections
3. Rewrite every bullet point to start with a strong action verb and include at least one quantified metric
4. Mirror the job description language exactly where possible (e.g. if JD says "cross-functional collaboration", use that phrase)
5. Keep the candidate's real experience — do not fabricate companies or degrees
6. The skills section must list every skill mentioned in the JD that the candidate plausibly has
7. The summary must open with the exact job title from the posting

Output ONLY a valid JSON object matching this schema — no markdown, no explanation:
{
  "personal_info": {"name": "", "email": "", "phone": "", "location": "", "linkedin": "", "github": ""},
  "summary": "",
  "skills": {"primary": [], "secondary": []},
  "experience": [{"company":"","title":"","start_date":"","end_date":null,"is_current":false,"bullets":[]}],
  "education": [{"institution":"","degree":"","field":"","graduation_year":""}],
  "projects": [{"name":"","description":"","technologies":[]}],
  "certifications": [],
  "scoring": {
    "ats_score": 0, "recruiter_score": 0, "overall_score": 0,
    "matched_keywords": [], "missing_keywords": [], "score_reasoning": ""
  }
}"""

    rag_context = ""
    if relevant_resumes:
        rag_context = "\n\nRELEVANT PAST RESUME VERSIONS (reference for candidate style):\n"
        for i, rv in enumerate(relevant_resumes, 1):
            rag_context += f"--- Version {i} ({rv.get('job_title','')}) ---\n{json.dumps(rv.get('content', {}))}\n"

    user_prompt = f"""MASTER RESUME:
{json.dumps(master_resume_json)}
{rag_context}
TARGET JOB TITLE: {job_title}
TARGET COMPANY: {company_name or "the company"}
JOB DESCRIPTION:
{job_description}

Analyze the JD, extract all keywords, and produce the ATS-optimized JSON resume."""

    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.4,  # lower temp = more consistent JSON output
            ),
        )
        return json.loads(_clean_json_response(response.text))
    except json.JSONDecodeError as exc:
        logger.warning("Gemini returned non-JSON for resume, using mock. Raw: %.200s", response.text if 'response' in dir() else "N/A")
        return _mock_tailored_resume(job_title, company_name)
    except Exception as exc:
        logger.exception("Gemini resume generation failed — using mock fallback")
        return _mock_tailored_resume(job_title, company_name)


async def generate_cover_letter(
    resume_version_json: dict,
    job_title: str,
    company_name: str,
    job_description: Optional[str] = None,
    user_name: Optional[str] = None,
    relevant_cover_letters: Optional[list] = None,
) -> str:
    client = _get_client()
    if not client:
        return _mock_cover_letter(job_title, company_name, user_name)

    system_instruction = """You are an expert career writer specializing in ATS-friendly cover letters.

Write a compelling, 3-paragraph cover letter that:
1. Opens with the exact job title and company name — show genuine enthusiasm
2. Highlights 2-3 specific accomplishments with metrics that directly match the JD requirements
3. Closes with a confident call to action

Use the candidate's exact experience. Mirror key phrases from the job description naturally.
Respond with PLAIN TEXT only — no JSON, no markdown, no headers."""

    summary = resume_version_json.get("summary", "")
    experience = "; ".join([
        f"{e.get('title')} at {e.get('company')}" for e in resume_version_json.get("experience", [])[:3]
    ])

    rag_context = ""
    if relevant_cover_letters:
        rag_context = "\n\nPAST COVER LETTERS FOR TONE REFERENCE:\n"
        for i, cl in enumerate(relevant_cover_letters, 1):
            rag_context += f"--- CL {i} ---\n{cl.get('content', '')}\n"

    prompt = f"""CANDIDATE: {user_name or "Candidate"}
SUMMARY: {summary}
EXPERIENCE: {experience}
{rag_context}
TARGET JOB: {job_title} at {company_name}
JOB DESCRIPTION:
{job_description or "Not provided"}"""

    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.7,
            ),
        )
        return response.text.strip()
    except Exception as exc:
        logger.exception("Gemini cover letter generation failed — using mock fallback")
        return _mock_cover_letter(job_title, company_name, user_name)


async def generate_resume_and_cover_letter(
    master_resume_json: dict,
    job_title: str,
    job_description: str,
    company_name: Optional[str] = None,
    user_name: Optional[str] = None,
    generate_cl: bool = True,
    relevant_resumes: Optional[list] = None,
    relevant_cover_letters: Optional[list] = None,
) -> Tuple[dict, Optional[str]]:
    resume_task = generate_tailored_resume(
        master_resume_json, job_title, job_description, company_name,
        relevant_resumes=relevant_resumes
    )
    if generate_cl:
        cl_task = generate_cover_letter(
            master_resume_json, job_title, company_name or "", job_description,
            user_name, relevant_cover_letters=relevant_cover_letters
        )
        resume, cover_letter = await asyncio.gather(resume_task, cl_task)
        return resume, cover_letter
    else:
        resume = await resume_task
        return resume, None


async def generate_linkedin_post(
    job_title: str,
    company_name: str,
    user_name: Optional[str] = None,
) -> str:
    client = _get_client()
    if not client:
        return f"I'm incredibly excited to announce that I've joined {company_name} as a {job_title}! 🎉 I can't wait to start this new journey and work with such an amazing team."

    system_instruction = "You are a professional career coach. Write a single engaging LinkedIn post (max 150 words) announcing a new job. Use emojis appropriately but keep it professional. No hashtags. Respond with the post text only."
    prompt = f"Name: {user_name or 'I'}. Title: {job_title}. Company: {company_name}."

    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.8,
            ),
        )
        return response.text.strip()
    except Exception as exc:
        logger.exception("Gemini LinkedIn post generation failed — using fallback")
        return f"Excited to announce I'm joining {company_name} as {job_title}! 🚀 Looking forward to this new chapter."


# ── Fallback mocks (used when Gemini is unavailable or rate-limited) ──────────

def _mock_tailored_resume(job_title: str = "Software Engineer", company_name: Optional[str] = None) -> dict:
    return {
        "personal_info": {
            "name": "Your Name",
            "email": "your@email.com",
            "phone": "+1-555-0123",
            "location": "Your City, State",
        },
        "summary": f"Results-driven professional with proven experience in the domain, now targeting the {job_title} role at {company_name or 'the company'}.",
        "skills": {
            "primary": ["Python", "FastAPI", "PostgreSQL", "Docker", "REST APIs"],
            "secondary": ["React", "AWS", "Git", "CI/CD"],
        },
        "experience": [
            {
                "company": "Previous Company",
                "title": "Software Engineer",
                "start_date": "2022-01",
                "end_date": None,
                "is_current": True,
                "bullets": [
                    "Architected RESTful microservices handling 50K+ daily requests, reducing p99 latency by 35%",
                    "Built automated CI/CD pipelines cutting deployment time by 80%",
                    "Led cross-functional collaboration with product and design teams to deliver 3 major features on schedule",
                ],
            }
        ],
        "education": [
            {
                "institution": "Your University",
                "degree": "B.S.",
                "field": "Computer Science",
                "graduation_year": "2021",
            }
        ],
        "projects": [],
        "certifications": [],
        "scoring": {
            "ats_score": 72,
            "recruiter_score": 75,
            "overall_score": 73,
            "matched_keywords": ["Python", "REST APIs", "CI/CD"],
            "missing_keywords": ["Kubernetes", "Terraform"],
            "score_reasoning": "AI service temporarily unavailable — deterministic score applied. Update your resume text for a full AI analysis.",
        },
    }


def _mock_cover_letter(job_title: str, company_name: str, user_name: Optional[str]) -> str:
    name = user_name or "Candidate"
    return (
        f"Dear {company_name} Hiring Team,\n\n"
        f"I am writing to express my strong interest in the {job_title} position at {company_name}. "
        f"With a proven track record in building scalable software systems and a passion for delivering impactful products, "
        f"I am confident that my skills and experience align well with your team's needs.\n\n"
        f"In my previous roles, I have consistently delivered measurable outcomes — from architecting systems that handle "
        f"millions of requests to leading cross-functional teams toward ambitious product goals. I am particularly drawn to "
        f"{company_name}'s mission and believe my background in software engineering would allow me to contribute meaningfully from day one.\n\n"
        f"I would welcome the opportunity to discuss how my experience can contribute to {company_name}'s continued success. "
        f"Thank you for your consideration.\n\nBest regards,\n{name}"
    )


def _mock_tailored_resume() -> dict:
    return {
        "personal_info": {
            "name": "Jane Doe",
            "email": "jane@example.com",
            "phone": "+1-555-0123",
            "location": "San Francisco, CA",
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
    return f"Dear {company_name} Hiring Team,\n\nI am writing to express my strong interest in the {job_title} position at {company_name}. With a proven track record in software engineering and a passion for building impactful products, I am confident that my skills and experience align well with your team's needs.\n\nIn my previous roles, I have consistently delivered measurable outcomes — from architecting scalable systems that handle millions of requests to leading cross-functional teams toward ambitious product goals. I am particularly drawn to {company_name}'s mission and believe my background in backend development and system design would allow me to contribute meaningfully from day one.\n\nI would welcome the opportunity to discuss how my experience can contribute to {company_name}'s continued success. Thank you for considering my application.\n\nBest regards,\n{name}"
