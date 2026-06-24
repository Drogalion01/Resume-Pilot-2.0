import json
import logging
from typing import Optional, Dict, Any, Tuple
import asyncio
from google import genai
from google.genai import types

from app.config import settings

logger = logging.getLogger(__name__)

# Configure Gemini
if not settings.ENVIRONMENT == "development" or settings.GEMINI_API_KEY:
    client = genai.Client(api_key=settings.GEMINI_API_KEY) if settings.GEMINI_API_KEY else None
else:
    client = None

MODEL_NAME = "gemini-1.5-flash"

class LLMServiceError(Exception):
    pass

async def generate_tailored_resume(
    master_resume_json: dict,
    job_title: str,
    job_description: str,
    company_name: Optional[str] = None,
    relevant_resumes: Optional[list] = None,
) -> dict:
    if not client:
        return _mock_tailored_resume()

    system_instruction = "You are an expert resume writer and ATS specialist. Respond ONLY with valid JSON matching the provided schema. No markdown, no explanations. Your task is to produce a TAILORED version of this master resume optimized specifically for the given role and score it."

    rag_context = ""
    if relevant_resumes:
        rag_context += "\nRELEVANT PAST RESUMES FOR CANDIDATE (as reference for style and wording):\n"
        for i, rv in enumerate(relevant_resumes, 1):
            rag_context += f"--- Resume {i} (for {rv['job_title']} at {rv['company_name'] or 'Company'}) ---\n"
            rag_context += f"{json.dumps(rv['content'])}\n"

    user_prompt = f"""
MASTER RESUME (JSON):
{json.dumps(master_resume_json)}
{rag_context}
JOB TITLE: {job_title}
COMPANY: {company_name or "Company"}
JOB DESCRIPTION:
{job_description}
"""
    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.7,
            ),
        )
        text = response.text
        # Clean markdown codeblocks
        if text.startswith("```"):
            text = text.split("\n", 1)[1]
            if text.endswith("```"):
                text = text.rsplit("\n", 1)[0]
        return json.loads(text)
    except Exception as exc:
        logger.exception("Gemini resume generation failed")
        raise LLMServiceError("Failed to generate resume")

async def generate_cover_letter(
    resume_version_json: dict,
    job_title: str,
    company_name: str,
    job_description: Optional[str] = None,
    user_name: Optional[str] = None,
    relevant_cover_letters: Optional[list] = None,
) -> str:
    if not client:
        return _mock_cover_letter(job_title, company_name, user_name)

    system_instruction = "You are an expert career writer. Write a compelling, concise cover letter for this candidate applying to the specified role. Exactly 3 paragraphs. Respond with plain text only. No JSON. No markdown."
    
    summary = resume_version_json.get("summary", "")
    experience = "; ".join([
        f"{e.get('title')} at {e.get('company')}" for e in resume_version_json.get("experience", [])[:3]
    ])

    rag_context = ""
    if relevant_cover_letters:
        rag_context += "\nRELEVANT PAST GENERATED COVER LETTERS (reference for candidate's writing style/tone):\n"
        for i, cl in enumerate(relevant_cover_letters, 1):
            rag_context += f"--- Cover Letter {i} (for {cl['job_title']} at {cl['company_name'] or 'Company'}) ---\n"
            rag_context += f"{cl['content']}\n"

    prompt = f"""
CANDIDATE SUMMARY: {summary}
RELEVANT EXPERIENCE: {experience}
{rag_context}
JOB TITLE: {job_title}
COMPANY: {company_name}
JOB DESCRIPTION:
{job_description or "Not provided"}
"""
    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.8,
            ),
        )
        return response.text
    except Exception as exc:
        logger.exception("Gemini cover letter generation failed")
        raise LLMServiceError("Failed to generate cover letter")

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
    resume_task = generate_tailored_resume(master_resume_json, job_title, job_description, company_name, relevant_resumes=relevant_resumes)
    if generate_cl:
        cl_task = generate_cover_letter(master_resume_json, job_title, company_name or "", job_description, user_name, relevant_cover_letters=relevant_cover_letters)
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
    if not client:
        return f"I'm incredibly excited to announce that I've joined {company_name} as a {job_title}! 🎉 I can't wait to start this new journey and work with such an amazing team."

    system_instruction = "You are a professional yet enthusiastic career coach. Write a single engaging LinkedIn post (max 150 words) announcing a new job. Use emojis appropriately but keep it professional. Do NOT include hashtags. Respond with the text of the post only."
    prompt = f"Candidate name: {user_name or 'I'}. Job title: {job_title}. Company: {company_name}."

    try:
        response = await client.aio.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.8,
            ),
        )
        return response.text
    except Exception as exc:
        logger.exception("Gemini linkedin post generation failed")
        raise LLMServiceError("Failed to generate LinkedIn post")

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
