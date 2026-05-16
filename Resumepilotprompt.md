# Resume Pilot — Full Agent Prompt & Technical Report
### For GitHub Copilot with Claude Haiku 4.5 · Phase 1 Build

---

## HOW TO USE THIS DOCUMENT

Copy the content under **MASTER AGENT PROMPT** and paste it as your GitHub Copilot
workspace instruction (`.github/copilot-instructions.md`) or as a persistent system
prompt in your Copilot Chat panel before starting any session.

The **Technical Reference** sections that follow are for you, the developer — use them
to verify what the agent produces, resolve conflicts, and make architectural decisions
the agent cannot make for you.

---

---

# MASTER AGENT PROMPT
### Paste this verbatim into `.github/copilot-instructions.md`

---

You are a senior full-stack engineer building **Resume Pilot** — an AI-powered resume
analysis and job application tracking mobile app. You have complete knowledge of this
project's architecture, conventions, and goals. Follow every instruction in this document
precisely and consistently across all files you generate.

---

## PROJECT IDENTITY

**App name:** Resume Pilot
**Purpose:** Help job seekers create AI-tailored resumes, generate cover letters, and
track job applications — all from a mobile app.
**Current phase:** Phase 1 MVP — core auth, resume management, LLM-powered resume
generation, cover letter generation, application tracking, dashboard.
**Target users:** Job seekers globally, with initial focus on South and Southeast Asia.

---

## TECHNOLOGY STACK — NON-NEGOTIABLE

### Backend
- **Framework:** Python 3.11 + FastAPI (async throughout)
- **Database:** PostgreSQL via Neon (serverless Postgres) — connection string from env
- **ORM:** SQLAlchemy 2.x with async sessions (`asyncpg` driver)
- **Migrations:** Alembic
- **Validation:** Pydantic v2 for all request/response schemas
- **Auth:** Multi-provider auth system — see AUTH SYSTEM section below
- **Rate limiting:** SlowAPI
- **LLM:** Anthropic Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) via `anthropic` SDK
- **PDF export:** WeasyPrint
- **Hosting:** Render (production), local uvicorn (development)
- **Environment:** All secrets via `.env` / environment variables, never hardcoded

### Frontend
- **Framework:** Flutter 3.3+ (Dart)
- **State management:** Riverpod 2.x (`flutter_riverpod`, `riverpod_annotation`)
- **Routing:** GoRouter v14+
- **HTTP client:** Dio 5.x with interceptors for JWT, error mapping, retry
- **Local storage:** `flutter_secure_storage` for JWT, `shared_preferences` for settings
- **Models:** Freezed + json_serializable (immutable, with copyWith and fromJson/toJson)
- **File picking:** `file_picker`
- **PDF viewing:** `flutter_pdfview` or `syncfusion_flutter_pdfviewer`
- **Fonts:** Google Fonts (Inter or similar)
- **Icons:** `lucide_icons` or Material icons

### Infrastructure
- **Backend hosting:** Render (Web Service, paid $7/mo tier — never free tier for production)
- **Database:** Neon Postgres free tier (sufficient for Phase 1)
- **LLM API:** Anthropic API (`claude-haiku-4-5-20251001`)
- **File storage:** Local filesystem on Render for Phase 1 (move to S3 in Phase 2)
- **CI/CD:** GitHub Actions → auto-deploy to Render on push to `main`

---

## REPOSITORY STRUCTURE

```
resume_pilot/
├── backend/
│   ├── app/
│   │   ├── main.py                    # FastAPI app init, middleware, CORS
│   │   ├── config.py                  # Settings from env (pydantic-settings)
│   │   ├── database.py                # Async SQLAlchemy engine + session
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── user.py                # User, UserSettings, OAuthAccount, MagicLinkToken
│   │   │   ├── resume.py              # Resume, ResumeVersion, AnalysisResult
│   │   │   ├── generation.py          # GenerationJob, CoverLetter
│   │   │   └── application.py         # Application, Interview, Reminder, Note, TimelineEvent
│   │   ├── schemas/
│   │   │   ├── auth.py
│   │   │   ├── resume.py
│   │   │   ├── generation.py
│   │   │   └── application.py
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── __init__.py
│   │   │       ├── auth.py            # Magic link + OAuth + TOTP endpoints
│   │   │       ├── resumes.py
│   │   │       ├── generation.py
│   │   │       ├── applications.py
│   │   │       ├── interviews.py
│   │   │       ├── reminders.py
│   │   │       └── dashboard.py
│   │   ├── services/
│   │   │   ├── auth_service.py        # Magic link, OAuth, TOTP logic
│   │   │   ├── email_service.py       # Transactional email (Resend)
│   │   │   ├── resume_service.py
│   │   │   ├── llm_service.py
│   │   │   ├── generation_service.py
│   │   │   └── export_service.py
│   │   └── core/
│   │       ├── security.py            # JWT helpers, token rotation
│   │       ├── dependencies.py        # get_current_user, get_db
│   │       └── exceptions.py
│   ├── alembic/
│   ├── tests/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── render.yaml
│
└── frontend/
    └── resume_pilot_app/
        ├── lib/
        │   ├── main.dart
        │   ├── app/
        │   │   ├── router.dart
        │   │   └── theme.dart
        │   ├── core/
        │   │   ├── api/
        │   │   │   ├── api_client.dart
        │   │   │   └── api_endpoints.dart
        │   │   ├── models/
        │   │   └── providers/
        │   └── features/
        │       ├── auth/
        │       │   ├── screens/
        │       │   │   ├── landing_screen.dart         # Auth method picker
        │       │   │   ├── magic_link_screen.dart      # Email entry + sent confirmation
        │       │   │   ├── magic_link_verify_screen.dart
        │       │   │   ├── oauth_callback_screen.dart  # Deep link handler
        │       │   │   └── totp_setup_screen.dart      # QR code + backup codes
        │       │   └── providers/
        │       ├── dashboard/
        │       ├── resume_lab/
        │       │   ├── screens/
        │       │   │   ├── resume_list_screen.dart
        │       │   │   ├── resume_detail_screen.dart
        │       │   │   ├── upload_resume_screen.dart
        │       │   │   ├── generate_screen.dart
        │       │   │   └── generation_result_screen.dart
        │       │   └── providers/
        │       ├── applications/
        │       └── settings/
        ├── pubspec.yaml
        └── test/
```

---

## DATABASE SCHEMA — COMPLETE

Generate ALL models using SQLAlchemy 2.x declarative style with `Mapped` and
`mapped_column`. Use `uuid.uuid4` as default for all primary keys. Always include
`created_at` and `updated_at` with server defaults. Always define cascade deletes.

### users
```
id                          UUID PK
email                       VARCHAR(255) UNIQUE NOT NULL   -- primary identity (replaces phone)
full_name                   VARCHAR(255) NULLABLE
avatar_url                  VARCHAR(500) NULLABLE          -- from OAuth providers
is_email_verified           BOOLEAN DEFAULT false
is_active                   BOOLEAN DEFAULT true
totp_secret                 VARCHAR(100) NULLABLE ENCRYPTED  -- null = TOTP not enabled
totp_enabled                BOOLEAN DEFAULT false
backup_codes_hash           JSONB NULLABLE                 -- bcrypt-hashed backup codes
subscription_tier           VARCHAR(20) DEFAULT 'free'     -- 'free' | 'pro' | 'premium'
subscription_expires_at     TIMESTAMP NULLABLE
paddle_customer_id          VARCHAR(100) NULLABLE
generation_count_this_month INTEGER DEFAULT 0
generation_reset_date       DATE NULLABLE
last_login_at               TIMESTAMP NULLABLE
last_login_ip               VARCHAR(45) NULLABLE           -- IPv4 or IPv6
created_at                  TIMESTAMP DEFAULT now()
updated_at                  TIMESTAMP DEFAULT now()
```

### oauth_accounts
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
provider        VARCHAR(30) NOT NULL    -- 'google' | 'github' | 'linkedin'
provider_user_id VARCHAR(255) NOT NULL  -- the sub/id from the OAuth provider
access_token    TEXT NULLABLE ENCRYPTED
refresh_token   TEXT NULLABLE ENCRYPTED
token_expires_at TIMESTAMP NULLABLE
scope           TEXT NULLABLE
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()

UNIQUE(provider, provider_user_id)
```

### magic_link_tokens
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
email           VARCHAR(255) NOT NULL
token_hash      VARCHAR(255) NOT NULL   -- SHA-256 hash of the raw token
purpose         VARCHAR(30) NOT NULL    -- 'login' | 'email_verify' | 'email_change'
expires_at      TIMESTAMP NOT NULL      -- 15 minutes from creation
used_at         TIMESTAMP NULLABLE      -- null = not yet used
ip_address      VARCHAR(45) NULLABLE    -- IP that requested the link
user_agent      TEXT NULLABLE
created_at      TIMESTAMP DEFAULT now()

INDEX on (token_hash)
INDEX on (email, purpose, used_at)
```

### refresh_tokens
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
token_hash      VARCHAR(255) NOT NULL UNIQUE  -- SHA-256 of raw token
family_id       UUID NOT NULL           -- for refresh token rotation / reuse detection
expires_at      TIMESTAMP NOT NULL      -- 30 days
revoked_at      TIMESTAMP NULLABLE
ip_address      VARCHAR(45) NULLABLE
user_agent      TEXT NULLABLE
created_at      TIMESTAMP DEFAULT now()

INDEX on (token_hash)
INDEX on (family_id)
```

### user_settings
```
id                      UUID PK
user_id                 UUID FK → users(id) CASCADE DELETE UNIQUE
email_notifications     BOOLEAN DEFAULT true
interview_reminders     BOOLEAN DEFAULT true
marketing_emails        BOOLEAN DEFAULT false
theme                   VARCHAR(10) DEFAULT 'dark'
created_at              TIMESTAMP DEFAULT now()
updated_at              TIMESTAMP DEFAULT now()
```

### resumes
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
title           VARCHAR(255) NOT NULL
original_filename VARCHAR(255) NULLABLE
file_path       VARCHAR(500) NULLABLE
raw_text        TEXT NULLABLE
parsed_json     JSONB NULLABLE
is_master       BOOLEAN DEFAULT false
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()
```

### resume_versions
```
id              UUID PK
resume_id       UUID FK → resumes(id) CASCADE DELETE
user_id         UUID FK → users(id) CASCADE DELETE
title           VARCHAR(255) NOT NULL
content_json    JSONB NOT NULL
job_title       VARCHAR(255) NULLABLE
job_description TEXT NULLABLE
company_name    VARCHAR(255) NULLABLE
generation_mode VARCHAR(20) DEFAULT 'manual'
generated_from_resume_id  UUID NULLABLE FK → resumes(id) SET NULL
generation_metadata  JSONB NULLABLE
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()
```

### analysis_results
```
id              UUID PK
resume_id       UUID FK → resumes(id) CASCADE DELETE NULLABLE
resume_version_id  UUID FK → resume_versions(id) CASCADE DELETE NULLABLE
user_id         UUID FK → users(id) CASCADE DELETE
ats_score       INTEGER NULLABLE
recruiter_score INTEGER NULLABLE
overall_score   INTEGER NULLABLE
score_breakdown JSONB NULLABLE
issues          JSONB NULLABLE
suggestions     JSONB NULLABLE
matched_keywords JSONB NULLABLE
missing_keywords JSONB NULLABLE
job_title       VARCHAR(255) NULLABLE
model_used      VARCHAR(100) NULLABLE
created_at      TIMESTAMP DEFAULT now()
```

### cover_letters
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
resume_version_id  UUID NULLABLE FK → resume_versions(id) SET NULL
job_title       VARCHAR(255) NOT NULL
company_name    VARCHAR(255) NULLABLE
content         TEXT NOT NULL
generation_metadata  JSONB NULLABLE
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()
```

### applications
```
id              UUID PK
user_id         UUID FK → users(id) CASCADE DELETE
company_name    VARCHAR(255) NOT NULL
role            VARCHAR(255) NOT NULL
status          VARCHAR(30) DEFAULT 'saved'
  -- 'saved' | 'applied' | 'assessment' | 'hr_screen' | 'technical'
  -- | 'final_round' | 'offer' | 'rejected' | 'withdrawn'
location        VARCHAR(255) NULLABLE
source_url      TEXT NULLABLE
recruiter_name  VARCHAR(255) NULLABLE
applied_date    DATE NULLABLE
resume_version_id  UUID NULLABLE FK → resume_versions(id) SET NULL
cover_letter_id UUID NULLABLE FK → cover_letters(id) SET NULL
notes_text      TEXT NULLABLE
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()
```

### interviews
```
id              UUID PK
application_id  UUID FK → applications(id) CASCADE DELETE
user_id         UUID FK → users(id) CASCADE DELETE
interview_type  VARCHAR(30) NOT NULL
scheduled_at    TIMESTAMP NOT NULL
duration_minutes INTEGER NULLABLE
location_or_link TEXT NULLABLE
notes           TEXT NULLABLE
created_at      TIMESTAMP DEFAULT now()
updated_at      TIMESTAMP DEFAULT now()
```

### reminders
```
id              UUID PK
application_id  UUID FK → applications(id) CASCADE DELETE
user_id         UUID FK → users(id) CASCADE DELETE
remind_at       TIMESTAMP NOT NULL
message         TEXT NULLABLE
is_sent         BOOLEAN DEFAULT false
created_at      TIMESTAMP DEFAULT now()
```

### timeline_events
```
id              UUID PK
application_id  UUID FK → applications(id) CASCADE DELETE
user_id         UUID FK → users(id) CASCADE DELETE
event_type      VARCHAR(50) NOT NULL
description     TEXT NOT NULL
metadata        JSONB NULLABLE
created_at      TIMESTAMP DEFAULT now()
```

---

## AUTH SYSTEM — STATE-OF-THE-ART IMPLEMENTATION

Resume Pilot uses a **passwordless-first, multi-provider** authentication system. There
are no passwords stored anywhere. Users authenticate via one of three methods:

1. **Magic Link** (primary) — email-based, zero friction, works everywhere
2. **OAuth 2.0 / OIDC** — Google, GitHub, LinkedIn (one-click sign-in)
3. **TOTP / Authenticator App** — optional second factor for users who want it

All sessions are managed with short-lived JWTs + long-lived rotating refresh tokens.

---

### Magic Link Flow

```
1. User enters email on the app
2. Backend checks if user exists; if not, creates account (auto-registration)
3. Backend generates a cryptographically random 32-byte token
4. Backend stores SHA-256(token) in magic_link_tokens table (never the raw token)
5. Backend sends email via Resend containing: https://app.resumepilot.com/auth/verify?token=<raw>
6. User taps link → Flutter deep link handler opens app
7. App sends token to POST /api/v1/auth/magic-link/verify
8. Backend: SHA-256(token) → lookup in DB → check expiry (15 min) + used_at is null
9. Backend marks token as used_at = now(), issues access_token + refresh_token
10. User is authenticated
```

**Security properties:**
- Tokens are single-use and expire in 15 minutes
- Only the hash is stored — even a DB breach cannot replay tokens
- Rate limit: 3 magic link requests per email per 10 minutes
- Tokens are bound to the requesting IP for logging (not enforcement)
- If the same email requests a second link, the first is NOT invalidated (both work until used/expired)

---

### OAuth 2.0 / OIDC Flow (Google, GitHub, LinkedIn)

```
1. User taps "Continue with Google" (or GitHub/LinkedIn) in the app
2. App calls GET /api/v1/auth/oauth/{provider}/authorize
3. Backend generates a cryptographically random `state` parameter (stored in Redis/DB for 10 min)
4. Backend returns the provider's authorization URL with state, client_id, redirect_uri, scope
5. App opens the URL in flutter_web_auth_2 (secure in-app browser, not system browser)
6. User approves → provider redirects to: https://app.resumepilot.com/auth/callback/{provider}?code=...&state=...
7. Flutter deep link handler receives the callback
8. App sends code + state to POST /api/v1/auth/oauth/{provider}/callback
9. Backend validates state, exchanges code for provider tokens via PKCE
10. Backend fetches user profile from provider (email, name, avatar)
11. Backend upserts oauth_accounts record; creates or links user account
12. Backend issues access_token + refresh_token; returns to app
```

**Supported providers:**

| Provider | Scopes requested | Profile fields used |
|----------|-----------------|---------------------|
| Google   | `openid email profile` | sub, email, name, picture |
| GitHub   | `read:user user:email` | id, email, name, avatar_url |
| LinkedIn | `openid profile email` | sub, email, name, picture |

**Security properties:**
- Always use PKCE (`code_challenge_method=S256`) — required for mobile apps
- `state` parameter is a random nonce; validated before token exchange
- Never store provider access tokens in plaintext — encrypt at rest with AES-256-GCM
- On account linking: if the email from OAuth matches an existing user, link the OAuth
  account to that user (do not create a duplicate)
- If a user has no email from GitHub (private email setting), prompt them to enter one

---

### TOTP / Authenticator App (Optional 2FA)

TOTP is an opt-in second factor. It is NOT required for login, but users can enable it
in Settings for extra security. Use the `pyotp` library.

```
SETUP FLOW:
1. User goes to Settings → Security → Enable 2FA
2. Backend generates a 160-bit random TOTP secret via pyotp.random_base32()
3. Backend returns: {secret, otpauth_uri, backup_codes: [10 × 8-char codes]}
4. App displays QR code (qr_flutter package) and the raw secret for manual entry
5. User scans QR with Google Authenticator / Authy / any RFC 6238 app
6. User enters the 6-digit code to confirm setup
7. Backend verifies the code with pyotp.TOTP(secret).verify(code, valid_window=1)
8. Backend stores: totp_secret (AES-256-GCM encrypted), backup_codes (bcrypt-hashed),
   totp_enabled = true
9. App shows one-time backup codes screen — user must acknowledge before closing

LOGIN FLOW (when TOTP is enabled):
1. User completes magic link or OAuth → backend detects totp_enabled = true
2. Instead of issuing full tokens, backend issues a short-lived `mfa_token`
   (JWT, 5-minute expiry, claims: {sub: user_id, scope: "mfa_pending"})
3. App navigates to TOTP challenge screen
4. User enters 6-digit code
5. App sends POST /api/v1/auth/totp/verify {mfa_token, code}
6. Backend verifies code (±1 window for clock drift); issues full access_token + refresh_token

BACKUP CODE FLOW:
- User can enter any of the 10 backup codes instead of a TOTP code
- Backend checks bcrypt against stored hashes; if match, deletes that code (single use)
- If user has < 3 backup codes remaining, prompt to regenerate
```

---

### JWT & Token Architecture

**Access Token** (short-lived)
```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "tier": "pro",
  "totp_verified": true,
  "iat": 1714000000,
  "exp": 1714003600
}
```
- Algorithm: `RS256` (asymmetric — private key signs, public key verifies)
- Expiry: **1 hour** (short to limit blast radius of token theft)
- Never store in shared storage — Flutter uses `flutter_secure_storage`

**Refresh Token** (long-lived, rotating)
```
- Random 256-bit token, stored as SHA-256 hash in refresh_tokens table
- Expiry: 30 days
- On use: old token is revoked, new token is issued (rotation)
- family_id: all refresh tokens for a session share a family_id
- REUSE DETECTION: if a revoked token is presented, revoke ALL tokens in that family
  (indicates token theft — force re-authentication)
```

**MFA Pending Token** (transient)
```json
{
  "sub": "user-uuid",
  "scope": "mfa_pending",
  "iat": 1714000000,
  "exp": 1714000300
}
```
- Expiry: **5 minutes** — only valid for the TOTP challenge step
- Cannot be used to access any protected resource (scope check enforced in middleware)

---

### Auth API Endpoints

All endpoints are prefixed `/api/v1/auth/`. No JWT required unless noted.

```
# Magic Link
POST /magic-link/send
  Body: {email: str}
  Response: {message: "Magic link sent", expires_in: 900}
  Errors: 429 if rate limit exceeded

POST /magic-link/verify
  Body: {token: str}
  Response: AuthResponse | MFARequiredResponse
  AuthResponse: {access_token, refresh_token, token_type: "bearer", user: UserResponse}
  MFARequiredResponse: {mfa_token: str, mfa_required: true}

# OAuth
GET /oauth/{provider}/authorize
  Query: {redirect_uri: str}   -- the app's deep link URI
  Response: {authorization_url: str, state: str}

POST /oauth/{provider}/callback
  Body: {code: str, state: str, redirect_uri: str}
  Response: AuthResponse | MFARequiredResponse

# TOTP
POST /totp/verify          [requires mfa_token in Authorization header]
  Body: {code: str}        -- 6-digit TOTP or 8-char backup code
  Response: AuthResponse

GET  /totp/setup           [requires full JWT — authenticated user]
  Response: {secret: str, otpauth_uri: str, backup_codes: List[str]}

POST /totp/setup/confirm   [requires full JWT]
  Body: {code: str}        -- confirms user scanned QR correctly
  Response: {totp_enabled: true, backup_codes: List[str]}

DELETE /totp/disable       [requires full JWT + valid TOTP code]
  Body: {code: str}
  Response: {totp_enabled: false}

POST /totp/backup-codes/regenerate  [requires full JWT + valid TOTP code]
  Body: {code: str}
  Response: {backup_codes: List[str]}

# Token management
POST /token/refresh
  Body: {refresh_token: str}
  Response: {access_token, refresh_token}   -- new rotation
  Errors: 401 if revoked/expired, triggers family revocation if reuse detected

POST /token/revoke         [requires full JWT]
  Body: {refresh_token: str}
  Response: 204             -- logs out this device

POST /token/revoke-all     [requires full JWT]
  Response: 204             -- logs out all devices (revokes all refresh token families)

# Account
GET  /me                   [requires full JWT]  -- same as /api/v1/users/me
POST /email/verify         -- called when user clicks verification link in welcome email
  Body: {token: str}
  Response: {email_verified: true}
```

---

### Auth Service Implementation

```python
# services/auth_service.py

import secrets
import hashlib
import pyotp
from datetime import datetime, timedelta
from cryptography.fernet import Fernet  # for symmetric encryption of OAuth tokens
import jwt  # python-jose with RS256

class AuthService:

    async def send_magic_link(self, email: str, ip: str, db: AsyncSession) -> None:
        """
        1. Upsert user (create if new, do not overwrite existing data)
        2. Enforce rate limit: max 3 tokens per email per 10 minutes
        3. Generate token, store hash, send email via Resend
        """
        await self._enforce_magic_link_rate_limit(email, db)
        user = await self._upsert_user_by_email(email, db)
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        magic_link = MagicLinkToken(
            user_id=user.id,
            email=email,
            token_hash=token_hash,
            purpose="login",
            expires_at=datetime.utcnow() + timedelta(minutes=15),
            ip_address=ip,
        )
        db.add(magic_link)
        await db.commit()
        await email_service.send_magic_link(email, raw_token)

    async def verify_magic_link(self, raw_token: str, db: AsyncSession) -> tuple[User, bool]:
        """
        Returns (user, mfa_required).
        Raises 401 if token invalid/expired/used.
        """
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        record = await db.execute(
            select(MagicLinkToken)
            .where(MagicLinkToken.token_hash == token_hash)
            .where(MagicLinkToken.used_at.is_(None))
            .where(MagicLinkToken.expires_at > datetime.utcnow())
        )
        token_record = record.scalar_one_or_none()
        if not token_record:
            raise HTTPException(status_code=401, detail="Invalid or expired magic link")
        token_record.used_at = datetime.utcnow()
        user = await db.get(User, token_record.user_id)
        if not user.is_email_verified:
            user.is_email_verified = True
        user.last_login_at = datetime.utcnow()
        await db.commit()
        return user, user.totp_enabled

    async def generate_totp_setup(self, user: User) -> dict:
        """Generate TOTP secret + backup codes. Does NOT save to DB yet."""
        secret = pyotp.random_base32()
        totp = pyotp.TOTP(secret)
        otpauth_uri = totp.provisioning_uri(
            name=user.email,
            issuer_name="Resume Pilot"
        )
        backup_codes = [secrets.token_hex(4).upper() for _ in range(10)]
        return {
            "secret": secret,
            "otpauth_uri": otpauth_uri,
            "backup_codes": backup_codes,
        }

    def verify_totp_code(self, secret: str, code: str) -> bool:
        """Allow ±1 window (30s each side) to handle clock drift."""
        totp = pyotp.TOTP(secret)
        return totp.verify(code, valid_window=1)

    def issue_access_token(self, user: User, totp_verified: bool = False) -> str:
        payload = {
            "sub": str(user.id),
            "email": user.email,
            "tier": user.subscription_tier,
            "totp_verified": totp_verified,
            "iat": datetime.utcnow(),
            "exp": datetime.utcnow() + timedelta(hours=1),
        }
        return jwt.encode(payload, settings.JWT_PRIVATE_KEY, algorithm="RS256")

    async def issue_refresh_token(self, user: User, family_id: UUID,
                                   ip: str, db: AsyncSession) -> str:
        raw = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw.encode()).hexdigest()
        record = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            family_id=family_id,
            expires_at=datetime.utcnow() + timedelta(days=30),
            ip_address=ip,
        )
        db.add(record)
        await db.commit()
        return raw

    async def rotate_refresh_token(self, raw_token: str, ip: str,
                                    db: AsyncSession) -> tuple[str, str]:
        """
        Validates, rotates, and returns (new_access_token, new_refresh_token).
        Detects token reuse: if token is already revoked, revoke entire family.
        """
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        record = await db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
        token_record = record.scalar_one_or_none()
        if not token_record:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        if token_record.revoked_at is not None:
            # Reuse detected — revoke entire family (potential token theft)
            await db.execute(
                update(RefreshToken)
                .where(RefreshToken.family_id == token_record.family_id)
                .values(revoked_at=datetime.utcnow())
            )
            await db.commit()
            raise HTTPException(
                status_code=401,
                detail="Token reuse detected. All sessions have been revoked. Please log in again."
            )
        if token_record.expires_at < datetime.utcnow():
            raise HTTPException(status_code=401, detail="Refresh token expired")
        # Revoke current token
        token_record.revoked_at = datetime.utcnow()
        user = await db.get(User, token_record.user_id)
        # Issue new tokens in same family
        new_access = self.issue_access_token(user)
        new_refresh = await self.issue_refresh_token(user, token_record.family_id, ip, db)
        return new_access, new_refresh
```

---

### Email Service (Resend)

Use **Resend** (resend.com) for transactional email. It has a generous free tier
(3,000 emails/month), a clean Python SDK, and excellent deliverability.

```python
# services/email_service.py
import resend

class EmailService:
    def __init__(self):
        resend.api_key = settings.RESEND_API_KEY

    async def send_magic_link(self, to_email: str, raw_token: str) -> None:
        verify_url = f"{settings.APP_DEEP_LINK_BASE}/auth/verify?token={raw_token}"
        resend.Emails.send({
            "from": "Resume Pilot <noreply@mail.resumepilot.com>",
            "to": [to_email],
            "subject": "Your sign-in link for Resume Pilot",
            "html": f"""
                <p>Click below to sign in. This link expires in 15 minutes and can only be used once.</p>
                <a href="{verify_url}" style="...">Sign in to Resume Pilot</a>
                <p>If you did not request this, ignore this email.</p>
            """
        })

    async def send_welcome_email(self, to_email: str, full_name: str | None) -> None:
        """Sent after first-ever sign-in."""
        ...
```

---

### Settings — Auth-Related Keys

Add these to `config.py`:

```python
class Settings(BaseSettings):
    DATABASE_URL: str
    JWT_PRIVATE_KEY: str          # RSA private key (PEM format) for RS256 signing
    JWT_PUBLIC_KEY: str           # RSA public key (PEM format) for verification
    JWT_ALGORITHM: str = "RS256"
    JWT_ACCESS_EXPIRE_MINUTES: int = 60          # 1 hour
    JWT_REFRESH_EXPIRE_DAYS: int = 30
    JWT_MFA_PENDING_EXPIRE_MINUTES: int = 5

    # OAuth providers
    GOOGLE_CLIENT_ID: str
    GOOGLE_CLIENT_SECRET: str
    GITHUB_CLIENT_ID: str
    GITHUB_CLIENT_SECRET: str
    LINKEDIN_CLIENT_ID: str
    LINKEDIN_CLIENT_SECRET: str

    # Email
    RESEND_API_KEY: str

    # Encryption key for OAuth tokens stored in DB (AES-256 via Fernet)
    TOKEN_ENCRYPTION_KEY: str     # base64url-encoded 32-byte key

    # App
    APP_DEEP_LINK_BASE: str = "resumepilot://app"
    APP_WEB_BASE_URL: str         # e.g. https://app.resumepilot.com (for magic link URLs)
    ANTHROPIC_API_KEY: str
    ENVIRONMENT: str = "development"
    MAX_FILE_SIZE_MB: int = 10
    FREE_TIER_GENERATION_LIMIT: int = 3
    PRO_TIER_MONTHLY_LIMIT: int = 30

    class Config:
        env_file = ".env"
```

---

### Flutter Auth Implementation

**Deep Links** — The app must handle these URIs:
- `resumepilot://app/auth/verify?token=<token>` — magic link callback
- `resumepilot://app/auth/callback/google?code=...&state=...` — OAuth callback
- `resumepilot://app/auth/callback/github?code=...&state=...`
- `resumepilot://app/auth/callback/linkedin?code=...&state=...`

Configure `AndroidManifest.xml` and `Info.plist` for the `resumepilot://` scheme.
Use `app_links` package for cross-platform deep link handling.

**Auth State** — Use a single `AuthNotifier` that holds:
```dart
@freezed
class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.mfaPending({required String mfaToken}) = _MFAPending;
  const factory AuthState.authenticated({required User user}) = _Authenticated;
  const factory AuthState.loading() = _Loading;
}
```

**Token Storage:**
```dart
// flutter_secure_storage — never SharedPreferences for tokens
const storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: accessToken);
await storage.write(key: 'refresh_token', value: refreshToken);
```

**Token Refresh Interceptor (Dio):**
```dart
// AuthInterceptor — on 401, try refresh ONCE, retry original request
// If refresh fails (401), clear tokens and redirect to /auth/landing
// Queue concurrent requests during refresh (do not send multiple refresh calls)
```

**Auth Screens:**

`landing_screen.dart` — Shows three options:
1. "Continue with email" (magic link) — primary CTA
2. "Continue with Google" (OAuth)
3. "Continue with GitHub" (OAuth)
4. "Continue with LinkedIn" (OAuth)

`magic_link_screen.dart` — Email input form. On submit:
- Shows "Check your inbox" confirmation with the email address
- "Resend link" button (available after 60s cooldown)
- "Use a different email" back button

`magic_link_verify_screen.dart` — Handles deep link. Shows spinner while
verifying. On success → navigates to dashboard. On TOTP required → navigates
to TOTP challenge screen.

`totp_setup_screen.dart` — Shows QR code (via `qr_flutter`), raw secret for
manual entry, confirm field. After confirm → shows backup codes screen.

---

## API ENDPOINTS — COMPLETE SPEC

All endpoints are prefixed `/api/v1/`. All responses are JSON. All protected endpoints
require `Authorization: Bearer <jwt>` header. Validation errors return 422. Auth errors
return 401. Not found returns 404.

### Auth — `/api/v1/auth/`
See **AUTH SYSTEM** section above for the full endpoint spec.

### Users — `/api/v1/users/`
```
GET  /me                Response: UserResponse (with settings)
PATCH /me               Body: UpdateUserRequest
                        Response: UserResponse

GET  /me/subscription   Response: SubscriptionStatus
GET  /me/sessions       Response: List[SessionInfo]   -- active refresh token families
DELETE /me/sessions/{family_id}  Response: 204        -- revoke a specific device session
```

### Resumes — `/api/v1/resumes/`
```
GET  /                  Response: List[ResumeListItem]
POST /                  Body: multipart/form-data (file, title, is_master)
                        Response: ResumeResponse

GET  /{resume_id}       Response: ResumeResponse
DELETE /{resume_id}     Response: 204

GET  /{resume_id}/versions           Response: List[ResumeVersionResponse]
GET  /{resume_id}/analysis           Response: AnalysisResultResponse
POST /{resume_id}/analyze            Triggers LLM analysis, returns AnalysisResultResponse
```

### Generation — `/api/v1/generation/`
```
POST /resumes/{resume_id}/generate
  Body: {
    job_title: str,
    job_description: str,
    company_name: str | None,
    generate_cover_letter: bool = true
  }
  Response: GenerationResultResponse {
    resume_version_id: UUID,
    tailored_resume: TailoredResumeSchema,
    ats_score: int,
    recruiter_score: int,
    overall_score: int,
    score_improvement: int | None,
    matched_keywords: List[str],
    missing_keywords: List[str],
    cover_letter: str | None,
    cover_letter_id: UUID | None,
    generation_metadata: dict
  }
  Errors:
    402 if user has exceeded free tier limit (3 lifetime)
    402 if pro user has exceeded monthly limit (30/month)

POST /cover-letters
  Body: {resume_version_id: UUID | None, job_title: str, company_name: str | None, job_description: str}
  Response: CoverLetterResponse

GET  /cover-letters/{id}             Response: CoverLetterResponse
PATCH /cover-letters/{id}            Body: {content: str}
DELETE /cover-letters/{id}           Response: 204
```

### Applications — `/api/v1/applications/`
```
GET  /                  Query: ?status=&search=&page=&size=
                        Response: PaginatedApplications

POST /                  Body: CreateApplicationRequest
                        Response: ApplicationResponse

GET  /{app_id}          Response: ApplicationDetailResponse (with interviews, reminders, timeline)
PATCH /{app_id}         Body: UpdateApplicationRequest
DELETE /{app_id}        Response: 204

PATCH /{app_id}/status  Body: {status: str}
                        Response: ApplicationResponse (also logs timeline event)
```

### Interviews — `/api/v1/applications/{app_id}/interviews/`
```
GET  /                  Response: List[InterviewResponse]
POST /                  Body: CreateInterviewRequest
PATCH /{interview_id}   Body: UpdateInterviewRequest
DELETE /{interview_id}  Response: 204
```

### Dashboard — `/api/v1/dashboard/`
```
GET  /                  Response: DashboardResponse {
                          total_resumes: int,
                          total_applications: int,
                          upcoming_interviews: int,
                          applications_by_status: dict,
                          recent_resumes: List[ResumeListItem],
                          recent_applications: List[ApplicationListItem],
                          generation_usage: {used: int, limit: int, resets_at: date | None}
                        }
```

---

## LLM SERVICE — EXACT IMPLEMENTATION REQUIREMENTS

### Model
Always use `claude-haiku-4-5-20251001`. Never use any other model string.

### Prompt Caching
Always enable prompt caching on the system prompt. Add `cache_control: {"type": "ephemeral"}`
to the system prompt content block. This reduces input cost by 90% after the first call.

### Generation Limits
- Free tier: 3 lifetime generations total (resume + cover letter counts as 1)
- Pro tier: 30 per calendar month, resets on the 1st
- Premium tier: unlimited
- Check limits BEFORE calling the LLM. Return HTTP 402 if exceeded.
- After successful generation, increment `generation_count_this_month` on the User.

### Parallel Execution
When `generate_cover_letter=true`, run the resume generation prompt and cover letter
prompt in PARALLEL using `asyncio.gather()`. Never run them sequentially.

### System Prompt for Resume Generation
```
You are an expert resume writer and ATS specialist. You receive a master resume
(containing ALL of a candidate's career history in JSON format) and a job description.

Your task is to produce a TAILORED version of this resume optimised specifically for
the given role. You must:

1. SELECT only the most relevant experiences, skills, and achievements for this role.
   Remove anything that does not strengthen the candidate's fit. Less is more.

2. REORDER sections so the most relevant content appears first.

3. REWRITE bullet points to:
   - Use strong action verbs (Delivered, Built, Architected, Led, Reduced, Increased)
   - Add quantified metrics wherever the original implies measurable impact
   - Mirror specific terminology and keywords from the job description
   - Follow the pattern: [Action verb] [what you did] [measurable result]

4. HIGHLIGHT transferable skills the candidate may not have emphasised.

5. SCORE the result against the job description:
   - ATS score (0-100): keyword match, required sections present, formatting signals
   - Recruiter score (0-100): clarity, achievement orientation, relevance

6. LIST matched and missing keywords.

You MUST respond with valid JSON only. No preamble. No explanation. No markdown fences.
The JSON must exactly match the provided output schema.
```

### System Prompt for Cover Letter Generation
```
You are an expert career writer. Write a compelling cover letter for this candidate
applying to the specified role.

Requirements:
- Exactly 3 paragraphs
- Paragraph 1: Strong opening hook. Be specific to this company/role.
- Paragraph 2: Prove value with 2-3 specific achievements. Be concrete.
- Paragraph 3: Forward-looking close with clear call to action.
- Match the tone of the job description (formal vs casual)
- Total length: 200-280 words

Respond with plain text only. No JSON. No markdown. Just the letter body.
```

### Output Schema for Resume Generation
```json
{
  "personal_info": {
    "name": "string",
    "email": "string",
    "phone": "string",
    "location": "string",
    "linkedin": "string | null",
    "github": "string | null",
    "portfolio": "string | null"
  },
  "summary": "string",
  "skills": {
    "primary": ["list", "of", "most", "relevant", "skills"],
    "secondary": ["other", "applicable", "skills"]
  },
  "experience": [
    {
      "company": "string",
      "title": "string",
      "start_date": "string",
      "end_date": "string | null",
      "is_current": "boolean",
      "bullets": ["rewritten bullet 1", "rewritten bullet 2"]
    }
  ],
  "education": [
    {
      "institution": "string",
      "degree": "string",
      "field": "string",
      "graduation_year": "string | null"
    }
  ],
  "projects": [
    {
      "name": "string",
      "description": "string",
      "technologies": ["tech1", "tech2"],
      "url": "string | null"
    }
  ],
  "certifications": ["string"],
  "scoring": {
    "ats_score": 0,
    "recruiter_score": 0,
    "overall_score": 0,
    "matched_keywords": ["keyword1"],
    "missing_keywords": ["keyword2"],
    "score_reasoning": "string"
  }
}
```

### Error Handling for LLM Calls
- Wrap all LLM calls in try/except
- If the LLM returns malformed JSON, retry once with an explicit repair prompt
- If retry fails, return HTTP 500 with message "Generation failed — please try again"
- Log token usage from every response to `generation_metadata`
- Set `max_tokens=3000` for resume generation, `max_tokens=600` for cover letters

---

## FLUTTER ARCHITECTURE CONVENTIONS

### File Naming
- All files: `snake_case.dart`
- All classes: `PascalCase`
- All providers: `camelCaseProvider`

### Theme — Dark Mode First
```dart
static const Color accent = Color(0xFF7C5CFA);
static const Color accentLight = Color(0xFFB39DFA);
static const Color bgPrimary = Color(0xFF0D1117);
static const Color bgSecondary = Color(0xFF151B2E);
static const Color bgCard = Color(0xFF1A2133);
static const Color textPrimary = Color(0xFFE8EAF0);
static const Color textSecondary = Color(0xFF8B8FA8);
static const Color textMuted = Color(0xFF6B7280);
static const Color statusSaved = Color(0xFF6B7280);
static const Color statusApplied = Color(0xFF7C5CFA);
static const Color statusOffer = Color(0xFF22C55E);
static const Color statusRejected = Color(0xFFEF4444);
static const Color statusTechnical = Color(0xFF3B82F6);
static const Color scoreHigh = Color(0xFF5DCAA5);
static const Color scoreMid = Color(0xFFF59E0B);
static const Color scoreLow = Color(0xFFEF4444);
```

### Navigation Structure
Bottom navigation bar with 4 tabs:
1. Home (dashboard)
2. Track (applications)
3. Resume Lab (resumes + generation)
4. Settings

Use GoRouter with `StatefulShellRoute` for persistent bottom navigation state.

### Riverpod Conventions
- Use `@riverpod` annotation (code generation) for all providers
- Repository pattern: `XxxRepository` class → `xxxRepositoryProvider`
- State notifiers for mutable state: `XxxNotifier extends AsyncNotifier<T>`
- Simple async reads: `FutureProvider` or `@riverpod Future<T>`
- Never put business logic in widgets — always in providers/notifiers

### Dio API Client
```dart
// Interceptor order:
// 1. AuthInterceptor — adds Bearer token, handles 401 (silent refresh + retry)
// 2. ErrorInterceptor — maps HTTP errors to typed AppException classes
// 3. LoggingInterceptor — debug mode only
// Timeouts: connectTimeout: 30s, receiveTimeout: 60s
```

### Error Handling in Flutter
```dart
sealed class AppException {
  GenerationLimitException   // HTTP 402
  UnauthorizedException      // HTTP 401
  MFARequiredException       // HTTP 403 scope=mfa_pending
  NetworkException
  ServerException
  ValidationException
  NotFoundException
}
```

### Generation Flow UI Requirements
Same as original spec — no changes.

---

## BACKEND CONVENTIONS

### Async Everything
Every endpoint, every DB call, every service method must be async.

### Dependency Injection
```python
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    try:
        payload = jwt.decode(token, settings.JWT_PUBLIC_KEY, algorithms=["RS256"])
        if payload.get("scope") == "mfa_pending":
            raise HTTPException(status_code=403, detail="MFA verification required")
        user_id = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user
```

### Response Schemas
Every endpoint must have an explicit `response_model`. Never return raw dicts.

### Alembic Migrations
- Always review before applying
- Descriptive names: `001_initial_schema.py`, `002_add_oauth_accounts.py`, etc.
- Always include both `upgrade()` and `downgrade()` functions

### CORS
Allow all origins in development. Restrict to app domain in production.

---

## RENDER DEPLOYMENT

```yaml
services:
  - type: web
    name: resume-pilot-api
    env: python
    plan: starter
    buildCommand: "pip install -r requirements.txt && alembic upgrade head"
    startCommand: "uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2"
    envVars:
      - key: DATABASE_URL
        sync: false
      - key: ANTHROPIC_API_KEY
        sync: false
      - key: JWT_PRIVATE_KEY
        sync: false
      - key: JWT_PUBLIC_KEY
        sync: false
      - key: GOOGLE_CLIENT_ID
        sync: false
      - key: GOOGLE_CLIENT_SECRET
        sync: false
      - key: GITHUB_CLIENT_ID
        sync: false
      - key: GITHUB_CLIENT_SECRET
        sync: false
      - key: LINKEDIN_CLIENT_ID
        sync: false
      - key: LINKEDIN_CLIENT_SECRET
        sync: false
      - key: RESEND_API_KEY
        sync: false
      - key: TOKEN_ENCRYPTION_KEY
        sync: false
      - key: ENVIRONMENT
        value: production
```

---

## GENERATION LIMIT ENFORCEMENT — EXACT LOGIC

```python
async def check_and_consume_generation(user: User, db: AsyncSession) -> None:
    today = date.today()
    if user.generation_reset_date and user.generation_reset_date.month != today.month:
        user.generation_count_this_month = 0
        user.generation_reset_date = today

    if user.subscription_tier == "free":
        if user.generation_count_this_month >= settings.FREE_TIER_GENERATION_LIMIT:
            raise HTTPException(status_code=402, detail={
                "error": "generation_limit_exceeded",
                "tier": "free",
                "limit": settings.FREE_TIER_GENERATION_LIMIT,
                "message": "You have used all 3 free generations. Upgrade to Pro for 30/month."
            })
    elif user.subscription_tier == "pro":
        if user.generation_count_this_month >= settings.PRO_TIER_MONTHLY_LIMIT:
            raise HTTPException(status_code=402, detail={
                "error": "generation_limit_exceeded",
                "tier": "pro",
                "limit": settings.PRO_TIER_MONTHLY_LIMIT,
                "resets_at": str(date(today.year, today.month % 12 + 1, 1))
            })

    user.generation_count_this_month += 1
    if not user.generation_reset_date:
        user.generation_reset_date = today
    await db.commit()
```

---

## SECURITY REQUIREMENTS

1. **JWT signing:** Use RS256 (asymmetric). Keep private key out of source control.
2. **Token storage:** Only SHA-256 hashes of magic link tokens and refresh tokens stored in DB.
3. **OAuth tokens:** Encrypted at rest with AES-256-GCM (Fernet) before storage.
4. **TOTP secrets:** Encrypted at rest with AES-256-GCM before storage.
5. **Backup codes:** Stored as bcrypt hashes — never in plaintext.
6. **Refresh token rotation:** Detect reuse (revoked token presented again) → revoke entire family.
7. **File uploads:** Validate MIME type (PDF and DOCX only), max 10MB.
8. **All DB queries** must filter by `user_id` — never trust client-provided IDs alone.
9. **Rate limits:**
   - Magic link send: 3 per email per 10 minutes
   - OAuth callback: 10 per IP per minute
   - TOTP verify: 5 attempts per user per 5 minutes (lock account on breach)
10. **Never log** raw tokens, TOTP secrets, or backup codes.
11. **HTTPS only** in production — enforce via Render's TLS termination.
12. **NEVER commit** `.env` files — add to `.gitignore` immediately.
13. **Email verification:** Send verification email on first sign-in; soft-require
    verification before enabling TOTP setup.

---

## WHAT NOT TO DO

- Do NOT use passwords of any kind — this is a passwordless system
- Do NOT use synchronous SQLAlchemy — this is an async app throughout
- Do NOT use Flask-style global state — all dependencies via FastAPI Depends
- Do NOT put any logic in Flutter widgets — all business logic in Riverpod providers
- Do NOT use `setState` — use Riverpod for all state
- Do NOT hardcode any API keys, secrets, or URLs
- Do NOT use the Render free tier for the web service in production
- Do NOT use `claude-sonnet` or any other model — only `claude-haiku-4-5-20251001`
- Do NOT call the LLM synchronously — always use async SDK client
- Do NOT skip Alembic migrations — never use `create_all()` in production
- Do NOT trust file extension alone for resume uploads — validate MIME type
- Do NOT store raw magic link tokens, raw refresh tokens, or TOTP secrets in plaintext
- Do NOT open OAuth redirect URLs in the system browser — use `flutter_web_auth_2`
- Do NOT skip the `state` parameter in OAuth flows — it prevents CSRF
- Do NOT allow a used magic link token to be reused — check `used_at IS NULL`
- Do NOT put the job description prompt and resume JSON into the system prompt

---

## BUILD ORDER — FOLLOW THIS SEQUENCE

### Step 1 — Backend foundation
1. `config.py` — Settings class with all auth keys
2. `database.py` — async engine, session factory, Base
3. All models: User, UserSettings, OAuthAccount, MagicLinkToken, RefreshToken, Resume,
   ResumeVersion, AnalysisResult, CoverLetter, Application, Interview, Reminder, TimelineEvent
4. `alembic/` — initial migration
5. `core/security.py` — RS256 JWT helpers, token hashing
6. `core/dependencies.py` — get_db, get_current_user (with scope check)
7. `core/exceptions.py` — AppError hierarchy

### Step 2 — Auth service + endpoints
1. `services/email_service.py` — Resend integration, magic link email template
2. `services/auth_service.py` — magic link, OAuth exchange, TOTP, refresh rotation
3. `schemas/auth.py`
4. `api/v1/auth.py` — all auth endpoints
5. Test with curl/Postman: magic link flow end-to-end, OAuth state validation,
   TOTP setup + verify, refresh rotation, reuse detection

### Step 3 — Resume service + endpoints
1. `services/resume_service.py`
2. `schemas/resume.py`
3. `api/v1/resumes.py`

### Step 4 — LLM service + generation endpoints
1. `services/llm_service.py`
2. `services/generation_service.py`
3. `services/export_service.py`
4. `schemas/generation.py`
5. `api/v1/generation.py`

### Step 5 — Application tracking
1. `services/application_service.py`
2. `schemas/application.py`
3. `api/v1/applications.py`, `interviews.py`, `reminders.py`

### Step 6 — Dashboard
1. `api/v1/dashboard.py`

### Step 7 — Flutter: foundation
1. `pubspec.yaml` with all dependencies (including `app_links`, `flutter_web_auth_2`, `qr_flutter`)
2. `app/theme.dart`
3. `core/api/api_client.dart` — Dio + interceptors (with silent refresh logic)
4. `app/router.dart` — GoRouter with deep link handling + bottom nav shell
5. All Freezed models matching backend schemas

### Step 8 — Flutter: auth screens
1. `landing_screen.dart` — magic link + OAuth buttons
2. `magic_link_screen.dart` — email entry + sent state
3. `magic_link_verify_screen.dart` — deep link handler
4. `oauth_callback_screen.dart` — OAuth deep link handler
5. `totp_challenge_screen.dart` — 6-digit code entry
6. `totp_setup_screen.dart` — QR code + backup codes
7. Auth notifier + provider

### Step 9 — Flutter: dashboard + resume lab
1. Dashboard screen
2. Resume list, detail, upload screens

### Step 10 — Flutter: generation flow
1. `generate_screen.dart`
2. `generation_loading_screen.dart`
3. `generation_result_screen.dart`

### Step 11 — Flutter: application tracking
1. Applications list, add, detail screens

### Step 12 — Flutter: settings
1. Settings screen with Security section (enable/disable TOTP, active sessions, revoke device)
2. Subscription status display

---

## QUICK REFERENCE — PACKAGE VERSIONS

### Backend (requirements.txt)
```
fastapi==0.115.0
uvicorn[standard]==0.30.6
sqlalchemy[asyncio]==2.0.35
asyncpg==0.29.0
alembic==1.13.3
pydantic==2.9.2
pydantic-settings==2.5.2
python-jose[cryptography]==3.3.0
cryptography==43.0.1
pyotp==2.9.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.12
anthropic==0.40.0
httpx==0.27.2
slowapi==0.1.9
resend==2.4.0
weasyprint==62.3
PyMuPDF==1.24.10
authlib==1.3.2
```

### Frontend (pubspec.yaml key dependencies)
```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.7
  dio: ^5.7.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.2
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  file_picker: ^8.1.2
  google_fonts: ^6.2.1
  app_links: ^6.3.2           # deep link handling (magic link + OAuth callbacks)
  flutter_web_auth_2: ^4.0.0  # secure in-app browser for OAuth
  qr_flutter: ^4.1.0          # QR code display for TOTP setup

dev_dependencies:
  build_runner: ^2.4.12
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.3
```

---

## TESTING CHECKLIST BEFORE MARKING ANY STEP COMPLETE

After each backend step:
- [ ] `alembic upgrade head` runs without error
- [ ] All new endpoints return correct status codes for valid input
- [ ] All new endpoints return 401 for missing/invalid JWT
- [ ] All new endpoints return 403 for `mfa_pending` scoped tokens on protected routes
- [ ] All new endpoints return 422 for invalid request bodies
- [ ] User A cannot access User B's data

After auth step specifically:
- [ ] Magic link token cannot be reused after first use
- [ ] Magic link token returns 401 after 15-minute expiry
- [ ] OAuth `state` mismatch returns 400
- [ ] TOTP backup code is deleted from DB after single use
- [ ] Refresh token reuse (presenting revoked token) revokes entire family
- [ ] `mfa_pending` JWT cannot access any resource other than `POST /auth/totp/verify`
- [ ] Rate limit: 4th magic link request in 10 min returns 429

After Flutter step:
- [ ] `flutter analyze` returns zero errors
- [ ] `flutter build apk --debug` succeeds
- [ ] Deep links open correct screens on both Android and iOS
- [ ] Token is not stored in `SharedPreferences` — only `flutter_secure_storage`
- [ ] Concurrent API calls during token refresh do not send multiple refresh requests
- [ ] No business logic in widget `build()` methods

After generation feature:
- [ ] Free user gets 402 on 4th generation attempt
- [ ] Pro user counter resets on first day of new month
- [ ] Parallel generation (resume + cover letter) completes in under 12 seconds
- [ ] Malformed LLM JSON triggers exactly one retry

---

*End of agent prompt. All instructions above apply to every file generated in this project.*

---
---

# DEVELOPER REFERENCE
### For your eyes only — not part of the agent prompt

---

## Why This Auth Stack (Not Phone OTP)

Phone OTP via telecoms (SMS) has several problems for a global product targeting
South and Southeast Asia: per-SMS costs of $0.01–0.05/message add up fast, delivery
failures in rural areas are common, and telecom API providers vary by country. Magic
links are zero-cost (email is free), work everywhere that has internet, and have
equivalent or better conversion rates.

OAuth (Google/GitHub/LinkedIn) is included because these are the exact accounts your
target users already have — job seekers universally have a Google account and most have
LinkedIn. One-tap sign-in removes friction at acquisition time.

TOTP is the gold standard for optional 2FA: no SMS, no cost, no provider dependency,
and supported by every major authenticator app. It gives security-conscious users
(especially those applying to finance/tech jobs) a reason to trust the platform.

## RS256 vs HS256

The original spec used HS256 (HMAC). This is replaced with RS256 (RSA) for one key
reason: RS256 allows any service to verify tokens using only the public key, while only
your backend can issue them using the private key. This matters when you add a web app,
webhooks, or third-party integrations. Generate keys with:

```bash
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
# Paste both into Render env vars (escape newlines as \n)
```

## Refresh Token Rotation and Reuse Detection

This is the most important security feature of the token system. The pattern works like
this: every time you use a refresh token, it is immediately revoked and a brand new one
is issued. All refresh tokens for a session share a `family_id`. If someone steals a
refresh token and uses it after the legitimate user has already rotated it, the stolen
token arrives revoked — which triggers a family-wide revocation, forcing both the
attacker and the legitimate user to re-authenticate. The legitimate user will notice and
can investigate.

## Resend vs SendGrid vs AWS SES

Resend has the best developer experience for a Phase 1 build: simple SDK, generous
free tier (3,000/month), and React Email templates if you want beautiful HTML later.
SendGrid is fine but requires domain verification steps that slow you down. SES is
cheapest at scale but has the most setup overhead. Start with Resend, switch to SES in
Phase 2 if volume requires it.

## OAuth Setup Checklist

For each provider, you need to register your app in their developer console:

**Google:** console.cloud.google.com → OAuth 2.0 Client ID → Android + iOS app type.
Add your deep link scheme as an authorized redirect URI. Approved instantly.

**GitHub:** github.com/settings/applications/new. Callback URL = your API's
`/api/v1/auth/oauth/github/callback`. Approved instantly.

**LinkedIn:** developer.linkedin.com → Create App → Products: "Sign In with LinkedIn
using OpenID Connect". Requires company page but approval is fast.

## Payment Setup (Bangladesh)

Stripe is not officially available in Bangladesh. Use **Paddle** as your merchant of
record — they handle global payments, VAT, and chargebacks, and pay in USD to a
Payoneer or Wise account. No foreign company registration required for Phase 1.

## Actual Monthly Cost at Launch

| Item | Cost |
|------|------|
| Render web service (starter) | $7.00 |
| Neon Postgres (free tier) | $0.00 |
| Resend (email, free tier) | $0.00 |
| Haiku 4.5 API (500 generations × $0.0104) | ~$5.20 |
| **Total** | **~$12.20/month** |

Break-even: 2 paying Pro subscribers at $9/month covers all costs.

## The One Critical Bug to Avoid

Any `Text` widget displaying a user-provided URL must have:
```dart
Text(
  url,
  overflow: TextOverflow.ellipsis,
  maxLines: 1,
)
```
Without this, long LinkedIn URLs cause "RIGHT OVERFLOWED BY 896 PIXELS" debug banners
visible to all users.

## Neon Postgres Connection

Use the connection pooler URL (port 5432 via pgBouncer) for the app, not the direct
connection URL. Add `?sslmode=require` to the connection string.

## File Storage Note

Phase 1 uses Render's local filesystem for uploaded resume PDFs. Render's filesystem
is ephemeral — files are lost on redeploy. For Phase 1 this is acceptable. In Phase 2,
move to S3 or Cloudflare R2.

---

*Resume Pilot · Phase 1 Build Document · Updated April 2026*