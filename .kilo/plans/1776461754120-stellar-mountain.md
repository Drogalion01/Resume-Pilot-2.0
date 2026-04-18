# Resume Pilot — MVP Implementation Plan

## Overview

Build the Phase 1 MVP following the `resume_pilot_analysis_report.md` specifications exactly. The app is a mobile-first (Flutter) resume analysis and job tracking platform with passwordless auth, LLM-powered resume generation, and application pipeline management.

**Critical Architecture Decisions from Report:**
- Passwordless auth only (magic link + OAuth + optional TOTP 2FA)
- Backend: FastAPI async, SQLAlchemy 2.x, PostgreSQL (Neon), Pydantic v2
 - LLM: Google Gemini 1.5 Flash (free tier) via `google-generativeai` SDK
 - Prompt caching: Optional for MVP; can add later
- File storage: Local filesystem on Render (Phase 1), move to S3 later
- Frontend: Flutter 3.3+, Riverpod 2.x, GoRouter, Dio with caching
- Deep links for auth callbacks (`resumepilot://` scheme)
- JWT: RS256 asymmetric, 1-hour expiry + rotating refresh tokens (30-day)
- Rate limiting via SlowAPI
- Deployment: Render (Web Service, $7/mo starter tier)
- CI/CD: GitHub Actions auto-deploy

---

## Current State Assessment

### What Already Exists (and can be reused)

**Backend:**
- ✅ `main.py` — FastAPI app with CORS, rate limiter, router registration
- ✅ `config.py` — Settings class (Pydantic v2, env-driven). Needs auth key additions
- ✅ `database.py` — Async SQLAlchemy engine + session factory
- ✅ Models (mostly correct, but need auth adjustments):
  - `user.py` — has `User` and `UserSettings` (needs: remove password_hash, add email_verified, totp fields, subscription_tier, etc.)
  - `resume.py` — Resume, ResumeVersion, AnalysisResult (mostly aligned)
  - `tracker.py` — Application, Interview, Reminder, Note, TimelineEvent (aligned)
- ✅ `dependencies.py` — `get_db` dependency (exists, check correctness)
- ✅ `limiter.py` — SlowAPI limiter singleton
- ✅ Services:
  - `auth_service.py` — JWT helpers (needs RS256 + magic link OTP methods)
  - `email_service.py` — Resend wrapper (needs magic link email template)
  - `storage_service.py` — Cloudinary wrapper (Phase 1 uses local FS, can keep as stub)
   - `ai_service.py` — Mock AI with Gemini stub (needs real Gemini integration)
- ✅ Routes stubs: `auth.py`, `user.py`, `dashboard.py`, `resumes.py` (stub), `applications.py` (stub), `interviews.py` (stub), `reminders.py` (stub), `ai.py`
- ✅ Schemas: `auth.py`, `user.py`, `common.py` (need expansion per spec)

**Frontend:**
- ✅ App bootstrap (`main.dart`) — Hive init, ProviderScope override
- ✅ Theme system (`premium_theme.dart`) — dark-first Material 3, well-built
- ✅ Router (`router.dart`) — GoRouter with auth guard, shell route for bottom nav
- ✅ API client (`api_client.dart`) — Dio + JWT interceptor + Hive cache + error mapping
- ✅ Auth state (`auth_state.dart`, `auth_notifier.dart`) — Riverpod sealed classes, session restore
- ✅ Screens:
  - `welcome_screen.dart` — Landing hero
  - `login_screen.dart` — Email + password form (needs replacing)
  - `register_screen.dart` — Email + password form (needs removing)
  - `dashboard_screen.dart` — Home UI stub (needs API wiring)
  - `settings_screen.dart` — Settings (needs wiring)
- ✅ Shared: `primary_button.dart`, `splash_screen.dart`, `theme_provider.dart`
- ✅ `app_shell.dart` — Bottom nav scaffold

**Infrastructure:**
- ✅ `alembic.ini` + `alembic/env.py` (check if present)
 - ✅ `requirements.txt` (needs `google-generativeai`, `pyotp`, `cryptography`, `qrcode` additions)
- ✅ `render.yaml` (needs updating for production config)
- ✅ `.gitignore` likely present

---

## What Must Be Built / Rebuilt

### Phase 0 — Foundation Cleanup & Auth Re-architecture
**Rationale:** Existing auth uses passwords which violate spec. Must replace entirely.

1. **Backend — Models (auth overhaul)**
   - `User`: remove `password_hash`, `google_id`; add `email_verified`, `totp_secret`, `totp_enabled`, `backup_codes_hash`, `subscription_tier`, `generation_count_this_month`, `generation_reset_date`, `last_login_at`, `ip_address`
   - `UserSettings`: keep mostly as-is
   - Add new models:
     - `OAuthAccount` — linked OAuth identities (provider, provider_user_id, encrypted tokens)
     - `MagicLinkToken` — token_hash, purpose, expires_at, used_at, ip, user_agent
     - `RefreshToken` — token_hash, family_id, expires_at, revoked_at, ip, user_agent
   - Keep existing: Resume, ResumeVersion, AnalysisResult, Application, Interview, Reminder, Note, TimelineEvent
   - Ensure all appropriate indexes, cascade deletes, server defaults

2. **Backend — Config Expansion**
   - Add to `config.py`:
     - JWT: `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY` (RSA PEM strings), `JWT_ALGORITHM="RS256"`, `JWT_ACCESS_EXPIRE_MINUTES=60`, `JWT_REFRESH_EXPIRE_DAYS=30`, `JWT_MFA_PENDING_EXPIRE_MINUTES=5`
     - OAuth: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`
     - Email: `RESEND_API_KEY` (already there), `APP_DEEP_LINK_BASE="resumepilot://app"`, `APP_WEB_BASE_URL` (for magic link URLs)
     - LLM: `GEMINI_API_KEY` (Google AI Studio — free tier available)
- Prompt caching: Optional for MVP; can add later
     - Encryption: `TOKEN_ENCRYPTION_KEY` (Fernet base64 key)
     - Limits: `FREE_TIER_GENERATION_LIMIT=3`, `PRO_TIER_MONTHLY_LIMIT=30`
   - Generate RSA key pair for dev (or use HS256 in dev with note to switch)

3. **Backend — Security Core**
   - `core/security.py` (new):
     - `create_access_token(user_id, email, tier, totp_verified)` → RS256 JWT
     - `verify_token(token, scope=None)` → payload or raise
     - `hash_token(raw)` → SHA-256 hex
     - `generate_family_id()` → UUID4
     - `encrypt_token(data)` / `decrypt_token(encrypted)` — AES via Fernet
   - `core/dependencies.py` (update `get_current_user`):
     - Decode JWT with public key
     - Check `scope != "mfa_pending"` before allowing access
     - Fetch user from DB, verify `is_active`
   - `core/exceptions.py` (new): AppError hierarchy (HTTPException subclasses)

4. **Backend — Email Service**
   - Add `send_magic_link(to_email, raw_token)` in `email_service.py`
   - Use `settings.APP_WEB_BASE_URL` to build verification link
   - Template: simple dark-mode HTML with CTA button, expiry notice

5. **Backend — Auth Service**
   - Extend `services/auth_service.py` with:
     - `send_magic_link(email, ip, db)` — upsert user, rate-limit (3 per 10 min), store hash, send email
     - `verify_magic_link(raw_token, db)` — hash lookup, check expiry+used, mark used, update last_login, return `(user, mfa_required)`
     - `generate_totp_setup(user)` — `pyotp.random_base32()`, provisioning URI, 10 backup codes
     - `verify_totp_code(secret, code)` — `pyotp.TOTP(secret).verify(code, valid_window=1)`
     - `issue_access_token(user, totp_verified=False)` → RS256 JWT
     - `issue_refresh_token(user, family_id, ip, db)` — store hash, return raw
     - `rotate_refresh_token(raw_token, ip, db)` — validate, revoke old, issue new; detect reuse → revoke family
   - Keep existing password helpers (won't be used, harmless)

6. **Backend — Auth API**
   - `routes/auth.py` — replace current password-based routes with:
     - `POST /magic-link/send` — body `{email}`, call `auth_service.send_magic_link()`, return `{message, expires_in: 900}`
     - `POST /magic-link/verify` — body `{token}`, call `auth_service.verify_magic_link()`, return `{access_token, refresh_token, user}` or `{mfa_token, mfa_required: true}`
     - `GET /oauth/{provider}/authorize` — generate state (random 32-byte), store in DB/Redis, return `{authorization_url, state}`
     - `POST /oauth/{provider}/callback` — exchange code via PKCE, validate state, get profile, upsert OAuthAccount, issue tokens
     - `POST /totp/verify` — requires `mfa_token`, verify code, issue full tokens
     - `GET /totp/setup` — return `{secret, otpauth_uri, backup_codes}`
     - `POST /totp/setup/confirm` — verify code, save encrypted secret + hashed backup codes
     - `DELETE /totp/disable` — require valid TOTP, clear fields
     - `POST /totp/backup-codes/regenerate` — generate new codes
     - `POST /token/refresh` — body `{refresh_token}`, call rotate
     - `POST /token/revoke` — revoke specific refresh token
     - `POST /token/revoke-all` — revoke all families for user
     - `GET /me` — keep as-is
   - Implement rate limiting per endpoint as per spec
   - Return typed Pydantic responses (`AuthResponse`, `MFARequiredResponse`, `UserResponse`)

7. **Backend — Schemas**
   - `schemas/auth.py`: add request/response models:
     - `MagicLinkSendRequest`, `MagicLinkVerifyRequest`
     - `OAuthAuthorizeRequest`, `OAuthCallbackRequest`
     - `TOTPVerifyRequest`, `TOTPSetupResponse`, `TOTPConfirmRequest`
     - `RefreshTokenRequest`, `AuthResponse` (access+refresh+user), `MFARequiredResponse`
   - `schemas/user.py`: add `SubscriptionStatus`, `SessionInfo`
   - Keep existing; may need minor additions for generation limits later

12. **Backend — Generation Service Core (MVP Core Feature)**
    - `services/llm_service.py` (new):
      - `async def call_gemini(prompt, system_prompt=None, max_tokens=3000)` — use `google.generativeai` async client
      - Optional: enable Gemini context caching (research & implement if cost-effective; otherwise skip)
      - Return `response.text`, log token usage to metadata
      - Handle JSON mode: use `response_mime={"type": "application/json"}` in generation config if supported; else parse JSON from text
    - `services/resume_service.py` (new):
      - Same as original plan (parse, score, generate)
      - `generate_tailored_resume()` prompts Gemini with master resume JSON + JD
      - System prompt per spec but adapted for Gemini (same content)
      - Request JSON output; enforce via response schema or parse with fallback repair
      - Enforce generation limits atomically

10. **Backend — Resume & Generation API**
     - `routes/resumes.py` (full implementation):
       - Same as original spec
     - `routes/generation.py` (new):
       - Same endpoints; call `generation_service` which uses Gemini

10. **Backend — Application Tracking API**
    - `routes/applications.py` (full):
      - `GET /` — list with filters (status, search), paginate
      - `POST /` — create app, auto-log timeline event "application_created"
      - `GET /{id}` — mega-payload: app + resume_version + cover_letter + interviews + reminders + notes + timeline
      - `PATCH /{id}` — update, detect status change → log timeline
      - `DELETE /{id}` — cascade all children
      - `PATCH /{id}/status` — specialised status-only update with timeline logging
    - `routes/interviews.py`:
      - `GET /applications/{app_id}/interviews` — list
      - `POST /.../interviews` — create, log "interview_scheduled"
      - `PATCH /interviews/{id}` — status changes log timeline
      - `DELETE /interviews/{id}`
    - `routes/reminders.py`:
      - `GET /applications/{app_id}/reminders`, `POST`, `PATCH`, `DELETE`
      - Completing a reminder logs "reminder_completed" timeline event
    - Ensure all queries filter by `user_id` from JWT

11. **Backend — Dashboard**
    - `routes/dashboard.py` (complete):
      - Use `dashboard_service.py` (new) with aggregated queries:
        - Count resumes, applications, interviews
        - Recent 3 resumes (with latest scores)
        - Recent 3 applications
        - Next 3 upcoming interviews
        - Insight message based on activity
      - Return typed `DashboardResponse`

12. **Backend — DB Migration**
    - Generate initial Alembic revision with all tables (matching report schema exactly)
    - Migrate existing passwords? No — fresh start; existing users must re-register
    - Drop old unused columns if any (e.g., `password_hash` in users)

13. **ENV & Deployment Prep**
    - Create `.env.example` with all required vars
    - Update `render.yaml` with env vars from spec
    - Ensure `Dockerfile` or Procfile for Gunicorn + Uvicorn workers
    - Local dev: `uvicorn app.main:app --reload`

---

### Phase 1 — Flutter Auth Rebuild (Frontend Critical Path)

**Auth Flow (per spec):**
1. Landing screen (`landing_screen.dart`) — four options: Magic Link (email), Google, GitHub, LinkedIn
2. Magic Link entry (`magic_link_screen.dart`) — email input, send, show "check inbox" confirmation with resend (60s cooldown)
3. Magic Link verification (`magic_link_verify_screen.dart`) — handled via deep link: `resumepilot://app/auth/verify?token=...`
   - Shows spinner while verifying
   - On success: if `totp_enabled` → navigate to TOTP challenge; else → dashboard
   - On TOTP required: navigate to TOTP screen
4. TOTP Setup (`totp_setup_screen.dart`) — show QR (via `qr_flutter`), raw secret, confirm with 6-digit code → show backup codes screen (acknowledge)
5. OAuth flow:
   - `GET /api/v1/auth/oauth/{provider}/authorize` → get URL + state
   - Open via `flutter_web_auth_2` in-app browser
   - Deep link callback: `resumepilot://app/auth/callback/{provider}?code=...&state=...`
   - POST to backend callback endpoint, receive tokens

**Required Flutter Changes:**

1. **Dependencies (`pubspec.yaml`)**
   - Add: `app_links` (deep links), `flutter_web_auth_2` (OAuth in-app browser), `qr_flutter` (TOTP QR), `google_sign_in` (already there, may keep), remove password fields
   - Consider: `flutter_otp_text_field` or similar for TOTP input

2. **Deep Link Configuration**
   - Android: `AndroidManifest.xml` intent filter for `resumepilot://` scheme
   - iOS: `Info.plist` URL types for `resumepilot`
   - Flutter: initialize `AppLinks` in `main.dart` to handle incoming links

3. **API Client Updates**
   - Token storage: store `access_token`, `refresh_token` (both strings)
   - Auth interceptor: on 401, queue concurrent requests, attempt silent refresh once, retry or logout on failure
   - Error mapping: add `MFARequiredException` (HTTP 403 with scope=mfa_pending scope)

4. **Auth State Machine**
   - `auth_state.dart`: Add `AuthState.mfaPending({required String mfaToken})` state
   - `auth_notifier.dart`:
     - `sendMagicLink(email)` method
     - `verifyMagicLink(token)` method → may result in `mfaPending` state
     - `verifyTotp(code)` method (uses `mfa_token`)
     - `loginWithOAuth(provider)` — initiates OAuth web auth flow, handles callback via deep link receiver
     - `refreshAccessToken()` — calls `/token/refresh`, handles token rotation, updates stored tokens
     - On app start: restore both tokens, verify `access_token` not expired; if expired auto-refresh

5. **New Auth Screens**
   - `lib/features/auth/screens/landing_screen.dart` — 4 CTA buttons
   - `lib/features/auth/screens/magic_link_screen.dart` — email input + "Send link" + cooldown
   - `lib/features/auth/screens/magic_link_verify_screen.dart` — auto-handles deep link after user taps email link
   - `lib/features/auth/screens/totp_setup_screen.dart` — QR + manual entry + confirm
   - `lib/features/auth/screens/totp_challenge_screen.dart` — enter 6-digit code (for login when 2FA enabled)
   - `lib/features/auth/screens/oauth_callback_screen.dart` — handles provider callback deep links

6. **Modify/Remove Existing Auth Screens**
   - Delete `register_screen.dart` (passwordless — no registration)
   - Modify `login_screen.dart` → convert to `landing_screen.dart` (or replace)
   - `welcome_screen.dart` remains as public landing

7. **Auth Flow in Router**
   - Add routes: `/auth/verify`, `/auth/callback/:provider`, `/totp/setup`, `/totp/verify`
   - Update `redirect` logic to handle `AuthState.mfaPending` → navigate to TOTP screen
   - After successful auth (including MFA), go to `/dashboard`

8. **Settings Screen**
   - Add "Enable 2FA" / "Disable 2FA" tile (calls TOTP endpoints)
   - Add "Active Sessions" (list refresh token families with device info)
   - Remove password-related fields (none exist currently)

---

### Phase 2 — Resume Management MVP

1. **Frontend — Resume Feature**
   - Create `lib/features/resume/` structure:
     - `screens/resume_upload_screen.dart` — file picker (`file_picker`), OR paste raw text option, title input
     - `screens/resume_list_screen.dart` — list of uploaded resumes with scores
     - `screens/resume_detail_screen.dart` — view parsed sections, raw text, analysis results
     - `screens/resume_analysis_screen.dart` — score breakdown (ATS, Recruiter), issues list, suggestions
   - Providers in `lib/features/resume/providers/`:
     - `resume_repository.dart` — Dio calls to `/resumes`, `/resume-versions`
     - `resume_state_notifier.dart` — upload progress, analysis polling (poll `/analyze/{id}/status` every 2s until done)
   - Widgets: score gauges (fl_chart), issue cards, keyword badges

2. **Backend — Resume Upload & Analysis**
   - `routes/resumes.py` — complete implementation
   - Service: `resume_service.py` parsing logic (pdfplumber, python-docx, regex sectioner)
   - Analysis: deterministic scoring function (report's rubric: contact, sections, formatting, metrics, verbs)
   - Store `AnalysisResult` with `status="completed"` + breakdown JSON
   - Background task: no Celery; use FastAPI `BackgroundTasks` (simple, report doesn't require distributed)
   - File storage: local `/tmp/uploads/` (Render ephemeral) — ensure path exists, handle cleanup later

3. **Frontend — Dashboard Integration**
   - Wire `dashboard_screen.dart` to `GET /dashboard`
   - Display stats cards (resumes, applications, interviews)
   - Show 3 recent resumes (with score pills), 3 upcoming interviews
   - Navigate to respective detail screens

---

### Phase 3 — Application Tracking & Interviews

1. **Frontend — Applications Feature**
   - Create `lib/features/applications/`:
     - `screens/applications_tracker_screen.dart` — list with status chips (Kanban-style or grouped)
     - `screens/add_application_screen.dart` — form: company, role, status, date, source, recruiter, attach resume version
     - `screens/application_detail_screen.dart` — full detail + timeline (ListView of events) + tabs for Interviews/Reminders/Notes
     - `screens/add_interview_screen.dart` — datetime picker, type (phone/video/onsite), interviewer, link
   - Providers: `application_repository.dart`, `application_state_notifier.dart`

2. **Backend** — already covered above (routes exist but need implementation)

---

### Phase 4 — LLM Generation & Resume Lab

1. **Backend — LLM Integration**
   - Install `google-generativeai` SDK
   - Implement `llm_service.py` with `call_gemini()` using `genai.generate_content_async()`
   - Use Gemini 1.5 Flash: `model = genai.GenerativeModel('gemini-1.5-flash')`
   - Resume generation prompt (per spec) — ensure JSON output using `response_mime={"type": "application/json"}` or structured output with `response_schema`
   - Cover letter prompt: 3 paragraphs, 200-280 words
   - Parallel execution: `await asyncio.gather(resume_task, cover_letter_task)`
   - Generation limit check before each call
   - Error handling: retry once on malformed JSON with repair prompt

2. **Backend — Generation Endpoints**
   - Complete `routes/ai.py` or `routes/generation.py` (report says `/api/v1/generation/`)
   - Implement `POST /resumes/{id}/generate` with all schema fields
   - Persist generated resume as `ResumeVersion`, cover letter as `CoverLetter` model (need to add CoverLetter model if not present)

3. **Frontend — Resume Lab**
   - `lib/features/resume_lab/` screens:
     - `resume_lab_screen.dart` — entry: select master resume, enter job description, target role, company
     - `generation_loading_screen.dart` — animated progress, "AI tailoring your resume..."
     - `generation_result_screen.dart` — show before/after, scores comparison, keywords matched, action buttons (save version, generate cover letter, edit)
   - Provider: `generation_repository.dart`, `generation_state_notifier.dart`
   - Use `fl_chart` for score radar/bar charts

---

### Phase 5 — Polish & Integration

1. **Complete Missing Schemas**
   - `schemas/resume.py` — Resume, Version, Analysis DTOs
   - `schemas/application.py` — Application, Interview, Reminder, Note, TimelineEvent DTOs
   - `schemas/generation.py` — `ResumeGenerationResponse`, `CoverLetterResponse`

2. **Model Adjustments**
   - Add `CoverLetter` model to `models/` (id, user_id, resume_version_id, job_title, company_name, content, metadata, created_at)
   - Update `User` model: add fields per spec (check report section 4.1)
   - Add `OAuthAccount`, `MagicLinkToken`, `RefreshToken` models

3. **Alembic Migration**
   - Generate initial migration with all tables
   - Review for correct field types, indexes, foreign keys

4. **Error Handling & Exceptions**
   - Define custom exception classes in `core/exceptions.py`
   - Map to proper HTTP status codes in route handlers
   - Frontend: extend `AppException` sealed class in Dart to match

5. **Rate Limiting**
   - Apply decorators per spec:
     - Auth endpoints: 5-10/min
     - Magic link send: 3/10min per email
     - LLM generation: account-based, not IP
   - Configure SlowAPI in `main.py` or `limiter.py`

6. **Frontend — Not Yawn Features**
   - Profile screen (`lib/features/profile/screens/profile_screen.dart`) — view/edit profile
   - Interview calendar (`lib/features/interviews/screens/interview_calendar_screen.dart`) — simple list or calendar view
   - Notifications (local only for MVP; push later)

7. **Wiring**
   - Connect all screens via router
   - Ensure all providers are registered in `main.dart` overrides if needed
   - Test deep link flows on emulator + physical device

---

## Build Order (Sequential Phases)

### Phase A: Backend Foundation (Week 1)
1. Update `config.py` with all new env vars
2. Rebuild ORM models: User (passwordless), OAuthAccount, MagicLinkToken, RefreshToken, keep existing others
3. Create `core/security.py` (RS256 JWT, token hash, encryption)
4. Create `core/exceptions.py`
5. Update `core/dependencies.py` — `get_current_user` with scope check
6. Expand `email_service.py` with magic link template
7. Implement full `auth_service.py` (magic link, OAuth state, TOTP, refresh rotation)
8. Build Pydantic schemas in `schemas/auth.py`, `schemas/user.py`
9. Implement all auth API routes in `routes/auth.py`
10. Create initial Alembic migration; review
11. Test auth flow with curl/Postman:
    - Send magic link (mocked email to console)
    - Verify token (valid/invalid/expired/used)
    - Setup TOTP, verify
    - Refresh token rotation and reuse detection

### Phase B: LLM & Resume Service (Week 1-2)
1. Add `google-generativeai` to `requirements.txt`
2. `services/llm_service.py` — Gemini async client, JSON mode, error handling with retry once for malformed JSON
3. `services/resume_service.py` — parser + scorer + generator (Gemini prompts)
4. `services/generation_service.py` — orchestrator with `asyncio.gather()` for parallel resume + cover letter
5. Implement `routes/resumes.py` (upload, parse, analysis background task)
6. Implement `routes/generation.py` (resume + cover letter generation)
7. Add `CoverLetter` model + migration
8. Test with sample PDFs and job descriptions; validate JSON schema compliance

### Phase C: Application Tracking & Dashboard (Week 2)
1. Implement `routes/applications.py` (CRUD + status + timeline)
2. Implement `routes/interviews.py`
3. Implement `routes/reminders.py`
4. Implement `routes/dashboard.py` with service
5. Test end-to-end: create app → add interview → add reminder → complete → timeline events

### Phase D: Flutter Auth Rebuild (Week 2-3)
1. Update `pubspec.yaml` with new deps
2. Configure deep links (AndroidManifest, Info.plist)
3. Create new auth screens: Landing, MagicLinkSend, MagicLinkVerify, TOTPChallenge, TOTPSetup, OAuthCallback
4. Update `api_client.dart` token refresh logic
5. Update `auth_notifier.dart` with new methods
6. Update `router.dart` with new routes + auth guard for MFA
7. Remove `register_screen.dart` references; ensure welcome screen links to landing
8. Test auth flow on emulator (email, mock OAuth)

### Phase E: Flutter Resume & Application Features (Week 3-4)
1. Build Resume Upload screen (file picker + text paste)
2. Build Resume List + Detail screens
3. Build Analysis Result screen with breakdown gauges
4. Connect Dashboard to backend
5. Build Applications List + Add/Edit screens
6. Build Application Detail (with timeline, interviews, reminders tabs)
7. Build Interview Add/Edit screens
8. Build Resume Lab (generation flow): input JD → loading → result → actions
9. Polish navigation between screens

### Phase F: Final Integration & Deployment (Week 4)
1. Add `CoverLetter` schema + model (if not done)
2. Complete any missing schemas (resume, generation)
3. Add error handling middleware (global exception handler in main.py)
4. Add logging configuration
5. Create GitHub Actions workflow (`.github/workflows/deploy.yml`) for Render deployment
6. Final end-to-end testing (auth → upload → analyze → generate → apply → track)
7. Update README with setup instructions
8. Commit and push to GitHub; verify Render auto-deploy

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| RS256 key management complexity in dev | High | Use HS256 for local dev with switch; store dev keys in .env; document keygen script |
| Deep link handling platform quirks | Medium | Test on real Android/iOS early; use `app_links` package for cross-platform |
| Gemini API latency affects UX | Medium | Show spinner; use response streaming; optimize prompts |
| Token refresh race conditions | High | Implement request queue in Dio interceptor (lock during refresh) |
| File upload validation bypassed | High | Check MIME type + file signature magic bytes, not just extension |
| Free tier generation limit abuse | Medium | Enforce server-side, increment atomically in DB transaction |
| OAuth state replay attacks | High | Store state in Redis or DB with 10min expiry, validate on callback |
| Existing code conflicts with new auth model | High | Delete password-based auth files completely; rename User model cleanly via migration |

---

## Success Criteria (MVP Definition)

- [ ] User can sign in via magic link (email) without password
- [ ] User can sign in via Google OAuth (GitHub, LinkedIn next)
- [ ] Optional TOTP 2FA setup works end-to-end
- [ ] User can upload PDF/DOCX resume
- [ ] Resume analysis returns ATS + Recruiter scores within 30s
- [ ] User can tap "Generate Tailored Resume" → Gemini produces tailored JSON with scores in <15s
- [ ] Generated resume can be saved as a new version
- [ ] Cover letter generation works in parallel
- [ ] User can create a job application, set status, add interview + reminder + note
- [ ] Timeline auto-logs status changes
- [ ] Dashboard shows aggregated stats
- [ ] All data isolated per authenticated user
- [ ] Refresh tokens rotate on use; reuse detected → all sessions revoked
- [ ] Deployed on Render with Neon DB + Resend emails configured

---

## Excluded from MVP (Phase 2+)

- Email verification (magic link implicitly verifies)
- Password reset flow (not needed without passwords)
- Stripe/payment integration (subscription tiers enforced by generation limits only)
- Push notifications (local notifications OK)
- Rich text resume editor (plain text edit only)
- Advanced analytics (trends over time)
- Multiple file storage backends (local only)
- Resume PDF export (WeasyPrint planned Phase 2)
- Web version (mobile-first; web responsive later)

---

## Notes

- The existing codebase has some useful scaffolding (theme, API client, models, basic screens). We will reuse all non-auth infrastructure.
- Auth must be rebuilt from scratch following passwordless spec. This is the largest change.
- **LLM: Use Google Gemini 1.5 Flash via `google-generativeai` SDK.** Model: `gemini-1.5-flash`. Free tier available.
- JSON output: use Gemini's `response_mime={"type": "application/json"}` or parse text; retry once on parse failure with repair prompt.
- Never store raw tokens, secrets, or TOTP seeds in DB — always hash/encrypt.
- All backend code async. No sync SQLAlchemy anywhere.
- Flutter business logic in Riverpod providers only; widgets stay dumb.

This plan is comprehensive. Implementation can begin immediately.
