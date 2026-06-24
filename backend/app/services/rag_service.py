"""
app/services/rag_service.py

Retrieval-Augmented Generation (RAG) Service for Resume Pilot 2.0.
Retrieves and ranks the user's historical cover letters and resumes to guide the generation of new, tailored documents.
"""
import logging
import re
from typing import List, Dict, Any, Optional
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.generation import CoverLetter
from app.models.resume import ResumeVersion

logger = logging.getLogger(__name__)


def _extract_keywords(text: str) -> set:
    """Helper to extract clean lowercase alphanumeric words from text."""
    if not text:
        return set()
    words = re.findall(r'\b[a-zA-Z]{3,}\b', text.lower())
    # Stopwords filter
    stopwords = {
        'and', 'the', 'for', 'with', 'you', 'that', 'this', 'from', 'our', 'your',
        'are', 'was', 'were', 'been', 'has', 'have', 'had', 'does', 'did', 'but',
        'not', 'not', 'can', 'will', 'would', 'should', 'could', 'about', 'their'
    }
    return set(w for w in words if w not in stopwords)


class RAGService:
    @staticmethod
    async def retrieve_relevant_cover_letters(
        user_id: Any,
        job_title: str,
        job_description: str,
        db: AsyncSession,
        limit: int = 3,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve previously generated cover letters for the user,
        ranking them by relevance to the target job title and description.
        """
        try:
            # Query all cover letters for user
            result = await db.execute(
                select(CoverLetter)
                .where(CoverLetter.user_id == user_id)
                .order_by(CoverLetter.created_at.desc())
            )
            letters = result.scalars().all()
            if not letters:
                return []

            target_keywords = _extract_keywords(f"{job_title} {job_description}")
            ranked_letters = []

            for letter in letters:
                # Score based on keyword overlap
                letter_text = f"{letter.job_title} {letter.company_name or ''} {letter.content}"
                letter_keywords = _extract_keywords(letter_text)
                
                # Jaccard similarity / overlap size
                intersection = target_keywords.intersection(letter_keywords)
                score = len(intersection)

                ranked_letters.append({
                    "id": str(letter.id),
                    "job_title": letter.job_title,
                    "company_name": letter.company_name,
                    "content": letter.content,
                    "score": score
                })

            # Sort by score desc, keeping top limit
            ranked_letters.sort(key=lambda x: x["score"], reverse=True)
            return ranked_letters[:limit]
        except Exception as exc:
            logger.error("RAG cover letter retrieval failed: %s", exc)
            return []

    @staticmethod
    async def retrieve_relevant_resumes(
        user_id: Any,
        job_title: str,
        job_description: str,
        db: AsyncSession,
        limit: int = 2,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve previous resume versions for the user,
        ranking them by relevance to the target job title and description.
        """
        try:
            result = await db.execute(
                select(ResumeVersion)
                .where(ResumeVersion.user_id == user_id)
                .order_by(ResumeVersion.created_at.desc())
            )
            versions = result.scalars().all()
            if not versions:
                return []

            target_keywords = _extract_keywords(f"{job_title} {job_description}")
            ranked_versions = []

            for version in versions:
                content = version.content_json or {}
                # Extract text fields
                summary = content.get("summary", "")
                skills_list = []
                skills = content.get("skills", {})
                if isinstance(skills, dict):
                    skills_list.extend(skills.get("primary", []))
                    skills_list.extend(skills.get("secondary", []))
                
                resume_text = f"{version.job_title or ''} {version.company_name or ''} {summary} {' '.join(skills_list)}"
                resume_keywords = _extract_keywords(resume_text)
                
                intersection = target_keywords.intersection(resume_keywords)
                score = len(intersection)

                ranked_versions.append({
                    "id": str(version.id),
                    "job_title": version.job_title,
                    "company_name": version.company_name,
                    "content": content,
                    "score": score
                })

            ranked_versions.sort(key=lambda x: x["score"], reverse=True)
            return ranked_versions[:limit]
        except Exception as exc:
            logger.error("RAG resume retrieval failed: %s", exc)
            return []

    @staticmethod
    async def retrieve_similar_benchmarks(
        resume_text: str,
        db: AsyncSession,
        limit: int = 5,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve similar reference benchmarks from the database.
        Uses vector semantic search (pgvector) if a Gemini client is available,
        otherwise falls back to a text keyword search.
        """
        import json
        try:
            from app.services.llm_service import client as gemini_client
            embedding = None
            if gemini_client:
                try:
                    sample_text = resume_text[:1000]
                    response = await gemini_client.aio.models.embed_content(
                        model="gemini-embedding-2",
                        contents=sample_text
                    )
                    if response.embeddings:
                        embedding = response.embeddings[0].values
                except Exception as exc:
                    logger.warning("Failed to generate embedding, using keyword fallback: %s", exc)

            if embedding:
                vector_str = f"[{','.join(map(str, embedding))}]"
                query = f"""
                    SELECT id, source, raw_text, metadata, (embedding <=> '{vector_str}') as distance
                    FROM ats_resume_benchmarks
                    ORDER BY distance ASC
                    LIMIT {limit}
                """
                result = await db.execute(text(query))
                rows = result.fetchall()
                benchmarks = []
                for row in rows:
                    benchmarks.append({
                        "id": row[0],
                        "source": row[1],
                        "raw_text": row[2],
                        "metadata": json.loads(row[3]) if isinstance(row[3], str) else row[3],
                        "distance": float(row[4]) if row[4] is not None else None
                    })
                return benchmarks
            else:
                keywords = list(_extract_keywords(resume_text))[:10]
                if not keywords:
                    query = f"SELECT id, source, raw_text, metadata FROM ats_resume_benchmarks LIMIT {limit}"
                    result = await db.execute(text(query))
                    rows = result.fetchall()
                else:
                    conditions = " OR ".join([f"raw_text ILIKE :kw_{i}" for i in range(len(keywords))])
                    params = {f"kw_{i}": f"%{kw}%" for i, kw in enumerate(keywords)}
                    query = f"""
                        SELECT id, source, raw_text, metadata
                        FROM ats_resume_benchmarks
                        WHERE {conditions}
                        LIMIT {limit}
                    """
                    result = await db.execute(text(query), params)
                    rows = result.fetchall()

                benchmarks = []
                for row in rows:
                    benchmarks.append({
                        "id": row[0],
                        "source": row[1],
                        "raw_text": row[2],
                        "metadata": json.loads(row[3]) if isinstance(row[3], str) else row[3],
                        "distance": None
                    })
                return benchmarks
        except Exception as exc:
            logger.error("RAG similar benchmarks retrieval failed: %s", exc)
            return []


rag_service = RAGService()

