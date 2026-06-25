# Resume Pilot 2.0 — App Project Status Report

This report provides a clear, comprehensive overview of the architecture, stack, integrations, services, core product features, and operational status of **Resume Pilot 2.0**.

---

## 1. Technology Stack

### Frontend (Client-side)
*   **Framework**: Flutter (Dart) — Multi-platform target support (Web, Android, iOS).
*   **State Management**: `Provider` with custom notifier pattern (e.g., `AuthNotifier`).
*   **HTTP Client**: `Dio` with custom interception for tokens, retries, and error handling (`ApiClient`).
*   **OAuth Handling**: Custom popup window managers and web view integration with BroadcastChannel listeners in `index.html` to handle logins without tab redirection locks.
*   **Deployment**: Vercel (hosted at `resume-pilot-2-0-frontend.vercel.app`).

### Backend (Server-side)
*   **Framework**: FastAPI (Python 3.10+) — High-performance asynchronous REST API.
*   **Database ORM**: SQLAlchemy 2.0 (Asynchronous) with `asyncpg` driver.
*   **Migrations**: Alembic.
*   **Deployment**: Vercel / Render (hosted at `resume-pilot-2-0.vercel.app`).

---

## 2. Integrated Software & Services

| Service | Category | Implementation Details |
| :--- | :--- | :--- |
| **Neon PostgreSQL** | Database | Serverless PostgreSQL instance with `pgvector` extension enabled for RAG semantic search. |
| **Google Gemini AI** | LLM / Embeddings | Integrated via `google-genai` SDK. Models: `gemini-1.5-flash` (tailoring, cover letters) and `text-embedding-004` (RAG vector embeddings). |
| **Cloudflare R2** | Object Storage | S3-compatible asset bucket for user PDF/DOCX resume file uploads, integrated using `aioboto3`. |
| **Resend** | Email Delivery | Transactional email provider for passwordless Magic Link logins and registration. |

---

## 3. Core Product Features & Workflows

### A. Resume Upload & Analysis
*   **Multi-format Parsing**: Extracts raw text from PDF, DOCX, and TXT uploads using `pdfplumber` and `python-docx`.
*   **Deterministic ATS Score**: Scores resumes out of 100 based on contact completeness, required sections, formatting safety, metric-quantified achievements, action verbs, and keyword density.
*   **RAG Benchmark Comparisons**: Composes a comparison profile matching the user's resume against **6,099** real candidate entries from `AI_Resume_Screening.csv` and `train.csv` (using Neon `pgvector` or keyword matching fallback).

### B. AI Resume Tailoring
*   **Job Description Alignment**: Tailors a master resume to match specific job descriptions.
*   **Gemini Rewrite**: Uses Gemini models to structure experiences, rewrite summaries, and map skills to target roles.
*   **Version Control**: Saves tailored versions separately, maintaining history without mutating the master copy.

### C. Supporting Documents & Socials
*   **Cover Letter Generator**: Generates customized cover letters using both the tailored resume context and historical cover letters.
*   **LinkedIn Announcement Generator**: Generates professional, ready-to-post announcements for newly secured roles.

### D. Monetization & Access Control
*   **Paddle Subscriptions**: Restricts usage to 3 generations for the free tier, with a billing portal to upgrade to the Pro plan for unlimited generations.
*   **Passwordless Security**: Strictly passwordless login using Magic Links and Google/GitHub/LinkedIn OAuth.

---

## 4. Current Operational Status

### What is Working
1.  **Database Connection & Models**: Synchronous test connections and schema configurations are fully verified and operational.
2.  **Dataset Ingestion**: `import_datasets.py` successfully completed the ingestion of 6,099 rows into the PostgreSQL table.
3.  **RAG Retriever API**: Tested query engine matching user input to dataset rows, fully functional.
4.  **Deterministic Scoring Logic**: Scans resumes for layout safety, achievements, contact details, and keywords.
5.  **Broadcast OAuth Receiver**: Javascript listeners injected in the frontend capture popped OAuth events and log users in automatically when tabs are closed.

### What is Pending / Needs Configuration
1.  **Resend Email Delivery**:
    *   *Issue*: Onboarding Resend accounts restrict sending emails to external domains (like Gmail) until a custom domain is verified.
    *   *Resolution*: Use the new API key (`re_8sCRsxcN_FsNG8Vt69JDotNoonuVYCsnF`) provided in `Clouodflare.txt` and update it on your Vercel backend environment variables.
2.  **Cloudflare R2 Storage Variables**:
    *   *Issue*: Needs the keys from `Clouodflare.txt` to be deployed to the Vercel backend config:
        *   `AWS_ACCESS_KEY_ID`: `1de5692e2ce66990addd1f25a969e185`
        *   `AWS_SECRET_ACCESS_KEY`: `3d8dd94c237b573fac24b9c1b5f08fa3be7fcc7bb229dafc891a8764d7000c5f`
        *   `AWS_ENDPOINT_URL_S3`: `https://9de9a52569e26e8c2d634c8b46cc189d.r2.cloudflarestorage.com`
3.  **Vercel Deployment Sync**:
    *   Add the new environment variables to the Vercel dashboard and trigger a backend redeployment to apply changes.
