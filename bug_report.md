# Resume Pilot 2.0 — Bug Report & Fix Log

> Generated: 2026-06-25 | Session: Authentication & Feature Stabilization

---

## Summary

Six root-cause bugs were identified that collectively caused **every post-login feature to fail**. The most critical was a single API contract mismatch (Bug #1) that produced the 422 errors visible in the screenshot — it cascaded to every authenticated endpoint. The deep-link bug (#2) explains why the magic link stays in the browser. The remaining bugs are schema mismatches and missing eager-loading that caused individual features to crash.

---

## Bug #1 — Magic Link Verify: Token sent as query param, backend expects JSON body

| Field | Detail |
|-------|--------|
| **Severity** | 🔴 Critical |
| **Symptoms** | `ApiException(422, null): An unexpected error occurred` on every screen after login |
| **Root cause** | `AuthNotifier.verifyMagicLink()` called `POST /auth/magic-link/verify` with `queryParameters: {'token': token}`. FastAPI's route declared `token: str` as a plain parameter on a `POST` endpoint — FastAPI interprets bare `str` params on a POST as **request body fields**, not query strings. The query param was silently ignored, FastAPI saw a missing required field → **422 Unprocessable Entity**. Since the 422 came back from the verify step, the `access_token` and `refresh_token` were never stored, meaning every subsequent authenticated request had no token → every feature failed. |
| **Files affected** | `frontend/lib/core/auth/auth_notifier.dart` · `backend/app/api/v1/auth.py` |
| **Fix applied** | ✅ **Backend**: Changed route signature from `token: str` (bare param) to `body: MagicLinkVerifyRequest` (Pydantic model). **Frontend**: Changed `queryParameters: {'token': token}` → `data: {'token': token}` (JSON body). |

```diff
# backend/app/api/v1/auth.py
-async def magic_link_verify(token: str, db: ...):
+async def magic_link_verify(body: MagicLinkVerifyRequest, db: ...):
-    user = await auth_service.verify_magic_link(token, db)
+    user = await auth_service.verify_magic_link(body.token, db)

# frontend/lib/core/auth/auth_notifier.dart
-        queryParameters: {'token': token},
+        data: {'token': token},
```

---

## Bug #2 — Deep Link: Magic link email stays in browser, never opens the app

| Field | Detail |
|-------|--------|
| **Severity** | 🔴 Critical |
| **Symptoms** | Tapping the magic link email opens the web fallback page. Tapping "Open in App" does nothing. The native app never receives the link. |
| **Root cause** | **`app_links` listener was never initialized.** The app had no code to subscribe to incoming deep links from the OS. `app_links` is installed as a package but `AppLinks().getInitialLink()` and `AppLinks().uriLinkStream` were never called anywhere. Without this listener, Android's intent system has no Flutter handler to forward the `resumepilot://` URI to — so the OS silently ignores it. Additionally, the app was a `ConsumerWidget` (stateless) which cannot hold a `StreamSubscription`. |
| **Files affected** | `frontend/lib/app/app.dart` |
| **Fix applied** | ✅ Converted `ResumePilotApp` from `ConsumerWidget` → `ConsumerStatefulWidget`. Added `_initDeepLinks()` in `initState()` that: (1) reads `getInitialLink()` for cold-start (app opened by the link), (2) subscribes to `uriLinkStream` for warm-start (app already running). Both paths call `_handleLink(uri)` which maps `resumepilot://app/auth/verify?token=...` and `https://resume-pilot.tech/auth/...` URIs to GoRouter paths via `router.go(path)`. |

```dart
// app.dart — new deep link subscription (added in initState)
final initialUri = await _appLinks.getInitialLink();
if (initialUri != null) _handleLink(initialUri);

_linkSub = _appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});

void _handleLink(Uri uri) {
  final router = ref.read(routerProvider);
  if (uri.scheme == 'resumepilot') {
    router.go('${uri.path}?${uri.query}');
  } else if (uri.scheme == 'https' && uri.host == 'resume-pilot.tech') {
    router.go('${uri.path}?${uri.query}');
  }
}
```

---

## Bug #3 — In-App Re-Authentication Loop: App re-asks for magic link after session restore

| Field | Detail |
|-------|--------|
| **Severity** | 🟠 High |
| **Symptoms** | After logging in once and closing the app, reopening it shows the magic link screen again instead of the dashboard. |
| **Root cause** | This is a **consequence of Bug #1**: since the 422 error prevented token storage (`_persistSession` was never called), `_restoreSession()` on cold-start found no stored `access_token` → `AuthStateUnauthenticated` → redirected to `/landing`. Now that Bug #1 is fixed, tokens will be correctly stored and the session restore will work. |
| **Files affected** | `frontend/lib/core/auth/auth_notifier.dart` |
| **Fix applied** | ✅ Fixed indirectly by fixing Bug #1. No additional code change needed. |

---

## Bug #4 — Resume Upload & Detail: 422 / model parse crash

| Field | Detail |
|-------|--------|
| **Severity** | 🔴 Critical |
| **Symptoms** | Resume upload fails. `ResumeDetail` screen shows `ApiException(422)`. |
| **Root cause (part A)** | `POST /auth/magic-link/verify` returning 422 (Bug #1) meant no `access_token` was stored → all resume API calls were made without a Bearer token → 422/401. Fixed by Bug #1 fix. |
| **Root cause (part B)** | `Resume.fromJson()` in the frontend expected `user_id`, `file_path`, `parsed_json` fields. The backend `ResumeDetail` schema did not expose `user_id` or `file_path`. `ResumeVersion.fromJson()` expected `resume_id`, `user_id`, `updated_at` — none of which were in `ResumeVersionOut`. This caused a `Null check operator used on a null value` / `type 'Null' is not a subtype of type 'String'` crash immediately after a successful API response. |
| **Files affected** | `backend/app/schemas/resume.py` |
| **Fix applied** | ✅ Added `user_id`, `file_path` to `ResumeDetail`. Added `resume_id`, `user_id`, `updated_at` to `ResumeVersionOut`. |

```diff
# backend/app/schemas/resume.py
class ResumeDetail(BaseModel):
    id: uuid.UUID
+   user_id: uuid.UUID
    title: str
    original_filename: Optional[str]
    file_type: Optional[str]
+   file_path: Optional[str] = None
    ...

class ResumeVersionOut(BaseModel):
    id: uuid.UUID
+   resume_id: uuid.UUID
+   user_id: uuid.UUID
    title: str
    ...
+   updated_at: datetime
```

---

## Bug #5 — Applications: MissingGreenlet crash on create/get/update

| Field | Detail |
|-------|--------|
| **Severity** | 🔴 Critical |
| **Symptoms** | Adding an application fails with 500 Internal Server Error. Application detail screen is blank. |
| **Root cause** | `ApplicationDetail` schema has four relationship fields: `interviews`, `reminders`, `notes`, `timeline_events`. The ORM routes used `await db.refresh(app)` or `db.get(Application, id)` — both return the object with **lazy-loaded** relationships. When `ApplicationDetail.model_validate(app)` tries to access `app.interviews` etc., SQLAlchemy's async engine raises `MissingGreenlet: greenlet_spawn has not been called`. Additionally `ApplicationListItem` and `ApplicationDetail` both lacked `user_id`, which the frontend model expected. |
| **Files affected** | `backend/app/api/v1/applications.py` · `backend/app/schemas/application.py` |
| **Fix applied** | ✅ All four application routes (list, create, get, patch, status-patch) now use `select(Application).options(selectinload(Application.interviews), selectinload(Application.reminders), selectinload(Application.notes), selectinload(Application.timeline_events))`. Added `user_id` to both `ApplicationListItem` and `ApplicationDetail` schemas. |

---

## Bug #6 — Token Refresh: MissingGreenlet crash + wrong JWT decode call

| Field | Detail |
|-------|--------|
| **Severity** | 🟠 High |
| **Symptoms** | Silent token refresh (on 401 retry) returns 500 and forces logout. |
| **Root cause** | `POST /auth/token/refresh` called `jwt.decode(new_access, settings.JWT_PUBLIC_KEY, ...)` directly (using `jose` library raw, which doesn't handle the HS256 fallback). It then did `await db.get(User, user_id)` which lazy-loads `User.settings` → MissingGreenlet. |
| **Files affected** | `backend/app/api/v1/auth.py` |
| **Fix applied** | ✅ Replaced `jwt.decode()` with the project's own `verify_token()` which handles RS256→HS256 fallback. Replaced `db.get(User, ...)` with `select(User).options(selectinload(User.settings))` to eager-load settings before serialization. |

---

## Bug #7 — Structural: Missing closing brace in magic_link_verify_screen.dart

| Field | Detail |
|-------|--------|
| **Severity** | 🔴 Critical (compile error) |
| **Symptoms** | `flutter analyze` reports: `Classes can't be declared inside other classes` on `_WebConfirmView` and `_ErrorView`. App would not compile at all. |
| **Root cause** | The closing `}` for `_MagicLinkVerifyScreenState` was missing between the `_buildBody` method (line 131) and the `_WebConfirmView` class definition (line 132). This caused both helper classes to be nested inside the state class — a Dart compile error. |
| **Files affected** | `frontend/lib/features/auth/screens/magic_link_verify_screen.dart` |
| **Fix applied** | ✅ Inserted the missing `}` on line 131 to close `_MagicLinkVerifyScreenState` before `_WebConfirmView`. |

---

## Bug #8 — Security: Hardcoded JWT fallback secret in security.py

| Field | Detail |
|-------|--------|
| **Severity** | 🟠 High |
| **Symptoms** | Not a runtime crash, but a security regression introduced during local debugging. |
| **Root cause** | During investigation, `_FALLBACK_SECRET` in `security.py` was temporarily set to the literal string `"supersecret"` to isolate token verification issues. This was committed to the working directory. |
| **Files affected** | `backend/app/core/security.py` |
| **Fix applied** | ✅ Reverted to `os.environ.get("JWT_SECRET_KEY") or secrets.token_hex(32)` — uses env var in production, ephemeral random secret otherwise. |

---

## Remaining Issues (Not Yet Fixed)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 9 | Payment Gateway | ⏳ Needs investigation | Paddle integration — needs endpoint audit for lazy-load + 402 handling |
| 10 | PDF Generation / Resume Download | ⏳ Needs investigation | S3 presigned URL flow — AWS keys may not be set in Vercel env vars |
| 11 | GitHub / LinkedIn OAuth | ⏳ Callback URL mismatch | Provider console must match `https://resume-pilot.tech/auth/callback/{provider}` exactly |
| 12 | Re-auth loop (full test) | ⏳ Needs live test | Fixed in theory by Bug #1; needs real device verification after rebuild |

---

## Deployment Checklist

After pushing these changes:

- [ ] `git push` backend changes → Vercel redeploys `api.resume-pilot.tech`
- [ ] `flutter run` to test deep link on physical device
- [ ] Request a fresh magic link email and tap it — should open app directly
- [ ] Upload a resume → should succeed with 201
- [ ] Add an application → should succeed with 201
- [ ] Check Vercel env vars contain `JWT_SECRET_KEY` (for consistent HS256 tokens across cold redeploys)
- [ ] Check Vercel env vars for `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET_NAME` (for resume uploads)

