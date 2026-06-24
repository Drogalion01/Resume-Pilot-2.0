import asyncio
import os
import sys
import csv
import ssl
import json
import logging
from typing import List, Dict, Any
import asyncpg

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("import_datasets")

# Default paths
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(os.path.dirname(BACKEND_DIR), "resume-ats-score-v1-en")

SCREENING_CSV_PATH = os.path.join(DATA_DIR, "AI_Resume_Screening.csv")
TRAIN_CSV_PATH = os.path.join(DATA_DIR, "train.csv")

# Connection DSN helper
def get_db_dsn() -> str:
    # Check environment variable first
    url = os.environ.get("DATABASE_URL")
    if not url:
        # Try loading from .env file
        env_path = os.path.join(BACKEND_DIR, ".env")
        if os.path.exists(env_path):
            with open(env_path, "r") as f:
                for line in f:
                    if line.startswith("DATABASE_URL="):
                        url = line.strip().split("=", 1)[1].strip('"').strip("'")
                        break
    if not url:
        logger.error("DATABASE_URL not found in environment or .env file.")
        sys.exit(1)
    
    # asyncpg requires postgresql:// or postgres:// scheme
    if url.startswith("postgresql+asyncpg://"):
        url = url.replace("postgresql+asyncpg://", "postgresql://", 1)
    return url

async def embed_texts_gemini(texts: List[str], api_key: str) -> List[List[float]]:
    """Generate vector embeddings for texts in batches using Google GenAI SDK."""
    from google import genai
    client = genai.Client(api_key=api_key)
    embeddings = []
    
    # Process in batches of 50 to avoid payload size/limit issues
    batch_size = 50
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        try:
            logger.info(f"Generating embeddings for batch {i//batch_size + 1}/{(len(texts)-1)//batch_size + 1}...")
            response = client.models.embed_content(
                model="text-embedding-004",
                contents=batch
            )
            for emb in response.embeddings:
                embeddings.append(emb.values)
        except Exception as exc:
            logger.error(f"Error generating embeddings for batch starting at index {i}: {exc}")
            # Fallback placeholder vectors for this batch
            for _ in batch:
                embeddings.append([0.0] * 768)
    return embeddings

async def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if len(sys.argv) > 1:
        api_key = sys.argv[1]
    
    if not api_key:
        env_path = os.path.join(BACKEND_DIR, ".env")
        if os.path.exists(env_path):
            with open(env_path, "r") as f:
                for line in f:
                    if line.startswith("GEMINI_API_KEY="):
                        api_key = line.strip().split("=", 1)[1].strip('"').strip("'")
                        break

    if not api_key:
        logger.warning(
            "GEMINI_API_KEY not provided. Resumes will be imported with placeholder embeddings (zero-vectors).\n"
            "To generate actual embeddings, pass the key as an argument:\n"
            "  python import_datasets.py YOUR_GEMINI_API_KEY\n"
        )

    # 1. Parse AI_Resume_Screening.csv
    logger.info(f"Reading {SCREENING_CSV_PATH}...")
    screening_records = []
    if os.path.exists(SCREENING_CSV_PATH):
        with open(SCREENING_CSV_PATH, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                raw_text = (
                    f"Job Role: {row.get('Job Role')}. "
                    f"Skills: {row.get('Skills')}. "
                    f"Experience: {row.get('Experience (Years)')} years. "
                    f"Education: {row.get('Education')}. "
                    f"Certifications: {row.get('Certifications')}. "
                    f"Recruiter Decision: {row.get('Recruiter Decision')}. "
                    f"AI Score: {row.get('AI Score (0-100)')}"
                )
                metadata = {
                    "resume_id": row.get("Resume_ID"),
                    "name": row.get("Name"),
                    "skills": row.get("Skills"),
                    "experience_years": int(row.get("Experience (Years)") or 0),
                    "education": row.get("Education"),
                    "certifications": row.get("Certifications"),
                    "job_role": row.get("Job Role"),
                    "recruiter_decision": row.get("Recruiter Decision"),
                    "salary_expectation": float(row.get("Salary Expectation ($)") or 0),
                    "projects_count": int(row.get("Projects Count") or 0),
                    "ai_score": float(row.get("AI Score (0-100)") or 0)
                }
                screening_records.append({
                    "source": "ai_resume_screening",
                    "raw_text": raw_text,
                    "metadata": metadata
                })
        logger.info(f"Loaded {len(screening_records)} records from AI_Resume_Screening.csv")
    else:
        logger.error(f"File not found: {SCREENING_CSV_PATH}")

    # 2. Parse train.csv
    logger.info(f"Reading {TRAIN_CSV_PATH}...")
    train_records = []
    if os.path.exists(TRAIN_CSV_PATH):
        with open(TRAIN_CSV_PATH, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                raw_text = row.get("text") or ""
                metadata = {
                    "ats_score": float(row.get("ats_score") or 0),
                    "original_label": row.get("original_label") or ""
                }
                train_records.append({
                    "source": "train",
                    "raw_text": raw_text,
                    "metadata": metadata
                })
        logger.info(f"Loaded {len(train_records)} records from train.csv")
    else:
        logger.error(f"File not found: {TRAIN_CSV_PATH}")

    all_records = screening_records + train_records
    if not all_records:
        logger.error("No records loaded. Exiting.")
        return

    # 3. Generate embeddings
    texts_to_embed = [rec["raw_text"] for rec in all_records]
    if api_key:
        logger.info(f"Generating embeddings using Gemini model text-embedding-004...")
        embeddings = await embed_texts_gemini(texts_to_embed, api_key)
    else:
        logger.info("Using placeholder zero-vector embeddings (768 dimensions)...")
        embeddings = [[0.0] * 768 for _ in range(len(all_records))]

    # Add embeddings back to records
    for idx, rec in enumerate(all_records):
        rec["embedding"] = embeddings[idx]

    # 4. Connect to database and insert
    dsn = get_db_dsn()
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    logger.info("Connecting to Neon database...")
    conn = await asyncpg.connect(dsn, ssl=ctx)
    try:
        # Create extension and table
        logger.info("Ensuring pgvector extension and table exist...")
        await conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS ats_resume_benchmarks (
                id SERIAL PRIMARY KEY,
                source VARCHAR(50) NOT NULL,
                raw_text TEXT NOT NULL,
                metadata JSONB NOT NULL,
                embedding vector(768)
            );
        """)
        
        # Clear existing records (so running it multiple times is clean)
        logger.info("Clearing existing benchmarks from table...")
        await conn.execute("TRUNCATE TABLE ats_resume_benchmarks;")

        # Prepare for insertion
        logger.info("Inserting benchmarks in batches...")
        insert_query = """
            INSERT INTO ats_resume_benchmarks (source, raw_text, metadata, embedding)
            VALUES ($1, $2, $3, $4)
        """
        
        # Batch insert to DB
        db_batch = []
        for rec in all_records:
            # Convert embedding to PostgreSQL vector string representation
            vector_str = f"[{','.join(map(str, rec['embedding']))}]"
            metadata_str = json.dumps(rec["metadata"])
            db_batch.append((rec["source"], rec["raw_text"], metadata_str, vector_str))
        
        # Insert using executemany
        await conn.executemany(insert_query, db_batch)
        logger.info(f"Successfully inserted {len(all_records)} reference resumes to ats_resume_benchmarks table!")
    except Exception as exc:
        logger.error(f"Database operation failed: {exc}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
