# ProfSidekick — Dev Task Allocation

**Prepared:** 2026-05-31
**Scope:** Bug fixes + Phase 1 & 2 features, excluding Stripe implementation.
**Devs:** Two full-stack engineers (TypeScript/Python). Each dev owns end-to-end slices — both frontend and backend — for their module.

> **RAG Note:** The lead engineer is driving the RAG pipeline (Feature 2). Job is allocated to that module as a direct collaborator under lead supervision — tasks within the RAG section marked **[Job owns]** are Job's deliverables; tasks marked **[Lead owns]** are the lead's responsibility. Job should not start RAG work until the lead has set up the pgvector extension and created the `rag_service.py` scaffold.

---

## Coordination Rules

| Rule | Detail |
|---|---|
| **No shared file edits in parallel** | The conflict table below defines file ownership. If both Devs need to touch the same file, the second Dev branches off the first's merged work. |
| **API contract is the handoff boundary** | Backend endpoint signature changes must be documented in `profsidekick-frontend-main/AGENTS.md §5` before the frontend side begins. |
| **Migrations are sequential** | Only one Alembic migration may be in-flight at a time. Coordinate with the lead before generating a migration. Rebase to include all prior migrations before generating a new one. |
| **Tests ship with the feature** | Every PR must include tests. Backend: `pytest`. Frontend: `vitest`. See each `AGENTS.md §4` for required test types. |
| **Commit format** | Follow the commit format defined in `profsidekick-frontend-main/AGENTS.md §6`: `<type>(<scope>): <description>`. |

### File Ownership (no parallel edits)

| File | Owner |
|---|---|
| `src/contexts/AuthContext.tsx` | Seidu |
| `src/components/auth/ProtectedRoute.tsx` | Seidu |
| `src/lib/api.ts` | Seidu |
| `src/app/api/auth/` (new BFF handlers) | Seidu |
| `app/dependencies/auth.py` | Job |
| `app/database/models.py` | Both — coordinate on timing; one PR at a time |
| `app/schemas/schemas.py` | Both — coordinate on timing |
| `app/services/openai_service.py` | Job (RAG integration), after lead scaffolds |
| `backend-main/AGENTS.md` | Job (§3.5 wording fix) |
| `profsidekick-frontend-main/AGENTS.md §5` | Whoever adds the endpoint updates it in the same PR |

---

## Seidu — Auth Hardening & AI Avatar / Persona Module

**Theme:** Fix the broken authentication layer that forces users to re-login on every page load, then build the Avatar and Persona feature that gives professors a configurable AI identity for their sessions.

### Priority 1 — Immediate Bug Fixes (Week 1)

---

#### Task S-1: Fix auth verify endpoint URL
**Effort:** 30 minutes | **Priority:** CRITICAL

**Problem:**
`AuthContext.tsx` line 61 calls `config.getApiUrl('/api/auth/verify')` (a hardcoded path), but the backend endpoint is `/api/auth/verify-token`. Every page load fires a 404, causing `checkAuth()` to clear localStorage and log the user out silently.

**Expected outcome:**
- Replace the hardcoded string with `config.api.auth.verify` (which resolves to `/api/auth/verify-token`).
- After the fix, a logged-in user refreshing the page stays logged in.

**Files to change:**
- `profsidekick-frontend-main/src/contexts/AuthContext.tsx` — one-line change at the `checkAuth()` fetch call.

**Definition of done:**
- [ ] The hardcoded `/api/auth/verify` string is replaced with `config.api.auth.verify`.
- [ ] Manual test: log in, refresh the page — user stays authenticated.
- [ ] `npm test` passes.

---

#### Task S-2: Create BFF auth route handlers
**Effort:** 2–3 hours | **Priority:** CRITICAL

**Problem:**
`AuthContext.tsx` calls `config.getApiUrl(...)` for `login`, `logout`, `checkAuth`, and `refreshToken` — these are direct browser-to-backend requests. The AGENTS.md contract requires all backend calls to go through Next.js `src/app/api/` route handlers (BFF pattern). In production, direct cross-origin requests from the browser may fail or force CORS to be open on the backend.

**Expected outcome:**
Four new Next.js route handler files that proxy the auth calls server-side. `AuthContext` is updated to call the BFF routes (`/api/auth/login`, `/api/auth/logout`, `/api/auth/verify`, `/api/auth/refresh`) instead of the backend URL directly.

**Files to create:**
```
src/app/api/auth/login/route.ts
src/app/api/auth/logout/route.ts
src/app/api/auth/verify/route.ts
src/app/api/auth/refresh/route.ts
```

**Files to change:**
- `src/contexts/AuthContext.tsx` — update all four fetch calls to use relative `/api/auth/*` paths.

**Route handler pattern** (same for all four — adapt method and path):
```typescript
// src/app/api/auth/login/route.ts
import { NextRequest, NextResponse } from 'next/server';
import config from '@/lib/config';

export async function POST(req: NextRequest) {
  const body = await req.json();
  const res = await fetch(config.getApiUrl('/api/auth/login'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
```
For `verify` and `refresh`, forward the `Authorization` header from the incoming request:
```typescript
headers: {
  'Content-Type': 'application/json',
  Authorization: req.headers.get('Authorization') ?? '',
},
```

**Definition of done:**
- [ ] Four BFF route handlers created.
- [ ] `AuthContext` no longer references `config.getApiUrl()` for auth calls — only `/api/auth/*` paths.
- [ ] Manual test: login, logout, page refresh all work correctly in browser.
- [ ] `profsidekick-frontend-main/AGENTS.md §5` endpoint table updated with the four new BFF paths.
- [ ] Each new `src/app/api/auth/*/route.ts` file has a test (see `AGENTS.md §4`).

---

#### Task S-3: Fix ProtectedRoute blank flash
**Effort:** 30 minutes | **Priority:** HIGH

**Problem:**
`ProtectedRoute` returns `null` while `isLoading === true`, rendering a blank white screen during the auth check on every navigation. Combined with the broken verify URL (A-1), users saw a full blank screen on every page load.

**Expected outcome:**
`ProtectedRoute` renders a loading spinner instead of `null` while `isLoading` is true.

**Files to change:**
- `profsidekick-frontend-main/src/components/auth/ProtectedRoute.tsx` — replace the `null` return with a centered spinner.

**Definition of done:**
- [ ] No blank screen on navigation. A spinner is visible for the duration of the auth check.
- [ ] `npm test` passes.

---

#### Task S-4: Store `expires_at` and proactive token refresh
**Effort:** 2–3 hours | **Priority:** HIGH

**Problem:**
`AuthContext` never stores the `expires_at` field returned by the login endpoint. Users whose tokens are within 30 minutes of expiry are not refreshed proactively, so they hit a wall exactly at expiry.

**Expected outcome:**
- `expires_at` is stored in `localStorage` alongside the token on login.
- `checkAuth()` reads `expires_at`: if the token is within 30 minutes of expiry, call `refreshToken()` before the session proceeds.
- `refreshToken()` updates `localStorage` with the new token and new `expires_at`.

**Files to change:**
- `src/contexts/AuthContext.tsx`

**Definition of done:**
- [ ] `expires_at` is persisted in `localStorage` on login and refresh.
- [ ] `checkAuth()` calls `refreshToken()` proactively when `expires_at` is within 30 minutes.
- [ ] `AuthContext` unit test covers the proactive refresh path.

---

#### Task S-5: 401 auto-refresh interceptor in `apiFetch`
**Effort:** 2 hours | **Priority:** HIGH

**Problem:**
When any authenticated API call returns 401 (token expired mid-session), there is no interceptor that attempts a token refresh and retries. Users see broken UI or console errors with no recovery.

**Expected outcome:**
`src/lib/api.ts`'s `apiFetch` (or equivalent wrapper) intercepts 401 responses, calls `refreshToken()`, and retries the original request once with the new token. On a second 401 (refresh itself failed), it clears auth and redirects to login.

**Files to change:**
- `src/lib/api.ts`

**Implementation sketch:**
```typescript
if (response.status === 401) {
  const newToken = await refreshToken(); // from AuthContext
  if (newToken) {
    return apiFetch(url, { ...init, token: newToken }); // retry once
  }
  clearAuth();
  redirect('/login');
}
```

**Definition of done:**
- [ ] 401 responses trigger a single refresh + retry.
- [ ] Infinite refresh loops are prevented (retry is done at most once per call).
- [ ] Unit test in `src/lib/api.test.ts` covering the 401 intercept path.

---

### Priority 2 — Phase 1 Feature: AI Avatar & Persona Builder (Weeks 2–5)

This feature gives professors a curated avatar identity and a preference-driven AI persona that the system refines with GPT-4o into a system prompt. It feeds directly into how `generate_ephemeral_token()` constructs the AI's instructions for every session.

Reference: `docs/product-roadmap-and-audit.md §Feature 1`, `docs/uml-implementation.md §7 (Professor Persona Setup sequence)`.

---

#### Task S-6: Backend — Avatar & ProfessorPersona data layer
**Effort:** 1 day | **Priority:** Phase 1

**What to build:**

**New models** in `app/database/models.py`:

```python
class Avatar(Base):
    __tablename__ = "avatars"
    id                  = Column(UUID, primary_key=True, default=uuid4)
    name                = Column(String, nullable=False)
    thumbnail_url       = Column(String, nullable=False)
    voice_id            = Column(String, nullable=False)   # OpenAI Realtime voice name
    default_persona_hint = Column(Text)                   # Seed hint for LLM refinement
    is_active           = Column(Boolean, default=True)

class ProfessorPersona(Base):
    __tablename__ = "professor_personas"
    id                       = Column(UUID, primary_key=True, default=uuid4)
    professor_id             = Column(UUID, ForeignKey("users.id"), nullable=False)
    avatar_id                = Column(UUID, ForeignKey("avatars.id"), nullable=False)
    preference_selections    = Column(JSONB)  # {"pacing": "thorough", "style": "socratic", ...}
    refined_prompt           = Column(Text)
    post_session_quiz_enabled = Column(Boolean, default=False)
    created_at               = Column(DateTime, default=datetime.utcnow)
    updated_at               = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

**Alembic migration:** `alembic revision --autogenerate -m "add_avatars_and_professor_personas"`. Review the generated SQL — verify JSONB is correct, no enum issues.

**Seed data script** at `scripts/seed_avatars.py`:
Seed the five base avatars from the product roadmap (Prof. Carter, Dr. Rivera, Advocate Chen, Coach Morgan, Dr. Amara) with their default voice IDs and persona hints.

**New Pydantic schemas** in `app/schemas/schemas.py`:
- `AvatarResponse`
- `PersonaPreferenceSelections` (typed JSONB shape — validate required keys)
- `ProfessorPersonaCreateRequest` / `ProfessorPersonaResponse`
- `PersonaRefineRequest` / `PersonaRefineResponse`

**Definition of done:**
- [ ] Models in `models.py`.
- [ ] Alembic migration generated, reviewed, applied locally.
- [ ] Seed script populates all five avatars.
- [ ] Pydantic schemas defined.

---

#### Task S-7: Backend — Avatar & Persona API endpoints
**Effort:** 1 day | **Priority:** Phase 1

**New file:** `app/api/avatars/api.py`
**New file:** `app/api/professor/persona/api.py`
**New service functions** in `app/services/persona_service.py`

**Endpoints to implement:**

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/avatars` | Yes | List active avatars |
| `GET` | `/api/professor/persona` | Yes (professor) | Get current professor's persona |
| `POST` | `/api/professor/persona` | Yes (professor) | Create or update (upsert) professor's persona |
| `POST` | `/api/professor/persona/refine` | Yes (professor) | Generate refined prompt via GPT-4o |

**`POST /api/professor/persona/refine` — LLM call:**
```
Prompt template (send to GPT-4o via chat completions):
"Given a professor with these teaching preferences: {preferences_json},
generate a concise, effective AI system prompt persona for an educational
assistant. The persona should be specific, consistent, and natural.
Maximum 150 words. Output only the persona description."
```
Return the generated string as `{ "refined_prompt": "..." }`. Do not auto-save — the professor reviews and saves separately.

**Register routers** in `app/main.py`.

**Update `generate_ephemeral_token()`** in `app/services/openai_service.py`:
After this task, modify `generate_ephemeral_token()` to look up the professor's `ProfessorPersona.refined_prompt` for the session owner and prepend it to the system instructions. If no persona exists, use the existing default instructions unchanged.

**Definition of done:**
- [ ] All four endpoints implemented and registered.
- [ ] `persona_service.py` contains service functions; route handlers are thin.
- [ ] GPT-4o refinement call works end-to-end.
- [ ] `generate_ephemeral_token()` injects `refined_prompt` when present.
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated with new endpoints.
- [ ] Integration tests for all four endpoints.

---

#### Task S-8: Frontend — Avatar picker & persona preference form
**Effort:** 2–3 days | **Priority:** Phase 1

**New components:**
- `src/components/professor/AvatarPicker.tsx` — grid of avatar cards. Each card shows thumbnail, name, and default voice. Clicking selects it (highlighted border).
- `src/components/professor/PreferencesForm.tsx` — form with the seven preference dimensions from the roadmap (pacing, questioning style, formality, depth, post-session check, encouragement, language complexity). Use `<select>` or radio group per dimension.
- `src/components/professor/RefinedPromptEditor.tsx` — textarea showing the refined prompt returned from the API. Editable. "Regenerate" button calls the refine endpoint again. "Save" calls the persona upsert endpoint.

**New hooks:**
- `src/hooks/useAvatars.ts` — fetches `GET /api/avatars` via BFF route.
- `src/hooks/useProfessorPersona.ts` — fetches current persona, submits upsert, calls refine.

**New BFF routes:**
- `src/app/api/avatars/route.ts` — proxies `GET /api/avatars`.
- `src/app/api/professor/persona/route.ts` — proxies `GET` and `POST /api/professor/persona`.
- `src/app/api/professor/persona/refine/route.ts` — proxies `POST /api/professor/persona/refine`.

**New page:**
- `src/app/(dashboard)/professor/persona/page.tsx` — three-step wizard:
  - Step 1: `<AvatarPicker>` — choose base avatar.
  - Step 2: `<PreferencesForm>` — set preference dimensions.
  - Step 3: `<RefinedPromptEditor>` — review/edit generated prompt, save.

**Navigation:**
Add a "My Persona" link to `NavigationHeader.tsx` (visible to professors only, based on `user.role`).

**Types:**
Add `Avatar`, `PersonaPreferenceSelections`, `ProfessorPersona` to `src/types/types.ts`.

**Definition of done:**
- [ ] Three-step wizard renders and submits correctly.
- [ ] `useAvatars` and `useProfessorPersona` hooks handle loading/error states.
- [ ] All three BFF routes created.
- [ ] `AvatarPicker`, `PreferencesForm`, `RefinedPromptEditor` have component tests.
- [ ] Persona page is accessible only to professors (protected route + role guard).

---

#### Task S-9: Milestone check — Avatar & Persona integration test
**Effort:** Half day | **Priority:** Phase 1

End-to-end manual test with both frontend and backend running:
1. Log in as a professor.
2. Navigate to `/professor/persona`.
3. Select an avatar, set preferences, click "Refine with AI".
4. Confirm the prompt appears in the textarea.
5. Edit and save.
6. Start a session — verify the system prompt in the OpenAI Realtime call now contains the refined persona.

---

### Seidu — Milestone Summary

| Milestone | Target | Deliverables |
|---|---|---|
| **M-S1: Auth Fixed** | End of Week 1 | Tasks S-1 through S-5 merged, users stay logged in |
| **M-S2: Persona Data Layer** | End of Week 2 | Tasks S-6, S-7 merged; avatars seeded in DB |
| **M-S3: Persona UI** | End of Week 4 | Task S-8 merged; wizard functional |
| **M-S4: Integration Complete** | Week 5 | Task S-9 complete; ephemeral token injects persona |

---
---

## Job — Backend Reliability, RAG Support & Feedback Loop

**Theme:** Fix the backend's reliability gaps, assist the lead on the RAG pipeline data layer, then build the Feedback Loop and GDPR foundations that complete the Phase 2 intelligence layer.

### Priority 1 — Immediate Bug Fixes (Week 1)

---

#### Task J-1: Fix `get_optional_user` — it is not actually optional
**Effort:** 30 minutes | **Priority:** CRITICAL

**Problem:**
`app/dependencies/auth.py` — `get_optional_user` uses `Depends(HTTPBearer())`. FastAPI's `HTTPBearer` raises HTTP 403 automatically when no `Authorization` header is present. This makes `get_optional_user` behave identically to `get_current_user`, breaking any endpoint designed to accept unauthenticated access.

**Expected outcome:**
`get_optional_user` returns `None` gracefully when no token is provided. It only attempts to decode when a token is present.

**Fix:**
```python
from typing import Optional
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security_optional = HTTPBearer(auto_error=False)

async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_optional),
    db: Session = Depends(get_db),
) -> Optional[User]:
    if credentials is None:
        return None
    # existing JWT decode logic here
    ...
```

**Files to change:**
- `app/dependencies/auth.py`

**Definition of done:**
- [ ] `get_optional_user` returns `None` when no `Authorization` header is sent.
- [ ] `get_optional_user` returns the decoded `User` when a valid token is provided.
- [ ] Regression test added: unauthenticated request to any endpoint using `get_optional_user` returns 200 (not 403).

---

#### Task J-2: Fix AGENTS.md — incorrect bcrypt claim
**Effort:** 5 minutes | **Priority:** LOW

**Problem:**
`backend-main/AGENTS.md §3.5` states "hashed with bcrypt via **passlib**". The implementation uses the `bcrypt` library directly, not passlib.

**Fix:** Update §3.5 to read: "Passwords are hashed with the `bcrypt` library directly (not passlib). Never store plaintext passwords or reversible hashes."

**Files to change:**
- `backend-main/AGENTS.md`

---

#### Task J-3: Redis startup ping and warning log
**Effort:** 1 hour | **Priority:** LOW

**Problem:**
`app/database/connection.py` — Redis failure is fully silent. When Redis is unavailable the app boots without warning, and caching-dependent features silently degrade. Operations teams have no signal.

**Expected outcome:**
On application startup (in the lifespan or at connection initialisation), attempt a `PING` to Redis. If it fails, log a `WARNING` at the `logging` level. Do not raise an exception — the app should still start.

**Files to change:**
- `app/database/connection.py` — add the ping check.
- Optionally `app/main.py` lifespan if connection.py is not the right location.

**Definition of done:**
- [ ] Redis unavailability produces a `WARNING` log line on startup.
- [ ] App still starts when Redis is down.
- [ ] Unit test mocking a failed Redis connection confirms the warning is logged.

---

#### Task J-4: Per-item warning logging for unmatched Wix line items
**Effort:** 1 hour | **Priority:** MEDIUM (payment-related)

**Problem:**
The Wix webhook handler silently skips line items where `_extract_product_id` returns `None`. Unmatched items produce no log entry, making it impossible to diagnose payment processing failures.

**Expected outcome:**
For every line item where `_extract_product_id` returns `None`, log a `WARNING` with the full item payload (sanitised — no PII) so engineers can diagnose which product catalogue entries are unrecognised.

**Files to change:**
- `app/api/` — locate the Wix webhook handler (likely `app/api/webhooks/wix.py` or similar).
- The relevant service function in `app/services/`.

**Definition of done:**
- [ ] Every unmatched line item produces a `WARNING` log with the item identifier and payload.
- [ ] The log message includes the `wix_order_id` for correlation.
- [ ] Unit test confirms the warning is emitted when `_extract_product_id` returns `None`.

---

#### Task J-5: Rate limiting on auth endpoints
**Effort:** 2–3 hours | **Priority:** LOW (security hygiene)

**Problem:**
`POST /api/auth/login` has no rate limiting. A brute-force attack can try unlimited passwords.

**Expected outcome:**
Add `slowapi` rate limiting to `POST /api/auth/login` and `POST /api/auth/register`. Reasonable limit: 10 requests per minute per IP.

**Implementation:**
```python
# requirements.txt: add slowapi
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/login")
@limiter.limit("10/minute")
async def login(request: Request, ...):
    ...
```

Register the `SlowAPIMiddleware` and the rate limit error handler in `app/main.py`.

**Files to change:**
- `app/api/auth/api.py`
- `app/main.py`
- `requirements.txt`

**Definition of done:**
- [ ] `POST /api/auth/login` returns HTTP 429 after 10 requests per minute from the same IP.
- [ ] Same limit applied to `/api/auth/register`.
- [ ] Test that the 11th request in a minute returns 429.

---

### Priority 2 — Phase 1: RAG Pipeline Support (Weeks 2–4, with Lead)

> Job works on this module under direct lead supervision. Wait for the lead to:
> 1. Install `pgvector` on the Contabo VPS.
> 2. Create the `rag_service.py` file scaffold with function signatures.
> Then begin the tasks below.

Reference: `docs/product-roadmap-and-audit.md §Feature 2`, `docs/uml-implementation.md §5 (RAG Ingestion sequence)` and `§6 (Live Session sequence)`.

---

#### Task J-6: RAG data models and Alembic migration
**Effort:** Half day | **Priority:** Phase 1 (with Lead)
**[Job owns]**

**New models** in `app/database/models.py`:

```python
from pgvector.sqlalchemy import Vector

class SlideChunk(Base):
    __tablename__ = "slide_chunks"
    id           = Column(UUID, primary_key=True, default=uuid4)
    session_id   = Column(UUID, ForeignKey("sessions.id"), nullable=False)
    slide_number = Column(Integer, nullable=False)
    chunk_index  = Column(Integer, nullable=False)
    content      = Column(Text, nullable=False)
    embedding    = Column(Vector(1536))   # text-embedding-3-small output dimension
    created_at   = Column(DateTime, default=datetime.utcnow)

class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"
    id           = Column(UUID, primary_key=True, default=uuid4)
    session_id   = Column(UUID, ForeignKey("sessions.id"), nullable=False)
    source       = Column(String)         # "vision", "professor_note", etc.
    content      = Column(Text, nullable=False)
    embedding    = Column(Vector(1536))
    created_at   = Column(DateTime, default=datetime.utcnow)
```

**Alembic migration:** `alembic revision --autogenerate -m "add_rag_slide_chunks_knowledge_chunks"`. The migration must also include `CREATE EXTENSION IF NOT EXISTS vector;` — add this manually to the `upgrade()` function as a raw SQL statement before the table creation lines:
```python
op.execute('CREATE EXTENSION IF NOT EXISTS vector')
```

> Coordinate with the lead before running this migration — they will confirm the `pgvector` extension is installed on Postgres first.

**Definition of done:**
- [ ] Models added to `models.py`.
- [ ] Migration includes `CREATE EXTENSION IF NOT EXISTS vector`.
- [ ] Migration applies cleanly with `alembic upgrade head` locally.

---

#### Task J-7: `ingest_session_document()` service function
**Effort:** 1 day | **Priority:** Phase 1 (with Lead)
**[Job owns under lead supervision]**

**Where:** `app/services/rag_service.py` (the lead will have created the file with function signatures).

**Function to implement:**
```python
async def ingest_session_document(
    session_id: UUID,
    slide_texts: list[dict],   # [{"slide_number": 1, "text": "..."}, ...]
    db: Session,
) -> int:
    """
    For each slide:
      1. Split text into chunks using LangChain RecursiveCharacterTextSplitter
         (chunk_size=400, chunk_overlap=50).
      2. Request embeddings from OpenAI text-embedding-3-small.
      3. Insert SlideChunk rows.
    Returns the total number of chunks inserted.
    """
```

**Dependencies to add to `requirements.txt`:** `langchain`, `langchain-openai`, `langchain-community`, `pgvector`.

**Integration point:** After this function is complete, the lead will wire it into `file_processor.py` as the final step of the upload pipeline. Do not modify `file_processor.py` — that is the lead's integration task.

**Definition of done:**
- [ ] Function splits text, embeds, and inserts `SlideChunk` rows correctly.
- [ ] Dependencies added to `requirements.txt`.
- [ ] Unit test with a mock OpenAI embeddings client confirms chunks are created at the right count and shape.

---

#### Task J-8: Frontend — "Sources" indicator in `TeachingInterface` and `SlidesPreview`
**Effort:** 1 day | **Priority:** Phase 1 (with Lead)
**[Job owns]**

**What to build:**
When the AI fires the `searchKnowledge` tool call (a Realtime API function call event), show a brief "Looking up..." indicator in `TeachingInterface`. When the AI fires `citeSlide({ slideNumber })`, highlight the cited slide in `SlidesPreview` and add a source badge to the transcript message.

**Where to add logic:** `src/hooks/useHandleServerEvent.ts` — add `case` handlers for the `searchKnowledge` and `citeSlide` tool names.

**UI changes:**
- `TeachingInterface.tsx`: show a subtle pulsing "Searching knowledge base…" text while `searchKnowledge` tool call is in flight (clear it when the tool result is sent back).
- `SlidesPreview.tsx`: add a `highlightedSlide: number | null` prop. When `citeSlide` fires, set `highlightedSlide` to the cited slide number. Apply a highlight ring to that slide card.
- `Transcript.tsx`: when a message has a `citedSlide` metadata field set, render a small "Slide N" badge next to the message.

**Important:** Tool names in `useHandleServerEvent.ts` must exactly match the tool names defined in `constants/teachingAssistant.ts` (see `AGENTS.md §3.5` — tool coupling rule). Add `searchKnowledge` and `citeSlide` to the `AgentConfig.tools` array in `teachingAssistant.ts` atomically in the same commit.

> These tool definitions will be provided by the lead when the backend `generate_ephemeral_token()` is updated. Implement the frontend handler stubs first, then test end-to-end with the lead.

**Definition of done:**
- [ ] `useHandleServerEvent` handles `searchKnowledge` and `citeSlide` events.
- [ ] `searchKnowledge` shows a "looking up" indicator while pending.
- [ ] `citeSlide` highlights the cited slide in `SlidesPreview`.
- [ ] Tool names added to `teachingAssistant.ts` in the same commit.
- [ ] Component tests for the indicator and highlight state.

---

### Priority 3 — Phase 2: Feedback Loop Feature (Weeks 5–8)

This feature captures structured student signals (ratings, flags, upvotes, confusion logs) and surfaces them on a professor analytics dashboard. It does **not** include the LLM auto-refinement from feedback — that is a Phase 2 extension that requires the persona builder (Seidu, Task S-7) to be merged first.

Reference: `docs/product-roadmap-and-audit.md §Feature 5`, `docs/uml-implementation.md §8 (Student Feedback Loop sequence)`.

---

#### Task J-9: Backend — Feedback data models and migration
**Effort:** Half day | **Priority:** Phase 2

**New models** in `app/database/models.py`:

```python
class SessionFeedback(Base):
    __tablename__ = "session_feedback"
    id             = Column(UUID, primary_key=True, default=uuid4)
    session_run_id = Column(UUID, ForeignKey("session_runs.id"), nullable=False)
    user_id        = Column(UUID, ForeignKey("users.id"), nullable=False)
    rating         = Column(Integer)    # 1–5
    comment        = Column(Text)
    created_at     = Column(DateTime, default=datetime.utcnow)

class TranscriptFeedback(Base):
    __tablename__ = "transcript_feedback"
    id             = Column(UUID, primary_key=True, default=uuid4)
    session_run_id = Column(UUID, ForeignKey("session_runs.id"), nullable=False)
    user_id        = Column(UUID, ForeignKey("users.id"), nullable=False)
    message_index  = Column(Integer, nullable=False)
    feedback_type  = Column(String, nullable=False)  # "incorrect" | "helpful"
    created_at     = Column(DateTime, default=datetime.utcnow)

class SessionConfusionLog(Base):
    __tablename__ = "session_confusion_logs"
    id             = Column(UUID, primary_key=True, default=uuid4)
    session_run_id = Column(UUID, ForeignKey("session_runs.id"), nullable=False)
    student_id     = Column(UUID, ForeignKey("users.id"), nullable=False)
    topic          = Column(String, nullable=False)
    created_at     = Column(DateTime, default=datetime.utcnow)
```

**Alembic migration:** `alembic revision --autogenerate -m "add_feedback_tables"`.

**Definition of done:**
- [ ] Three models in `models.py`.
- [ ] Migration applies cleanly.

---

#### Task J-10: Backend — Feedback API endpoints
**Effort:** 1 day | **Priority:** Phase 2

**New file:** `app/api/sessions/feedback_api.py` (or extend `sessions/api.py` if it doesn't become too large — use a separate router either way).
**New service functions** in `app/services/feedback_service.py`.

**Endpoints:**

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/sessions/{id}/runs/{runId}/feedback` | Yes (student) | Submit session rating + comment |
| `POST` | `/api/sessions/{id}/runs/{runId}/transcript-feedback` | Yes (student) | Flag or upvote a message |
| `GET` | `/api/professor/feedback-summary` | Yes (professor) | Aggregated feedback across all professor's sessions |

**`GET /api/professor/feedback-summary` response shape:**
```json
{
  "avg_rating": 3.8,
  "total_ratings": 42,
  "top_flagged_topics": [
    { "topic": "subnetting", "flag_count": 8 },
    { "topic": "CIDR", "flag_count": 5 }
  ],
  "top_helpful_messages": 12,
  "total_incorrect_flags": 23
}
```

**Definition of done:**
- [ ] All three endpoints implemented, registered, tested.
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated.
- [ ] Integration tests for all three endpoints.

---

#### Task J-11: Frontend — Star rating modal and transcript micro-actions
**Effort:** 2 days | **Priority:** Phase 2

**Star rating modal:**
- Trigger: when `TeachingInterface` receives the WebRTC disconnect event, show a modal asking "How was your session?" with a 1–5 star rating and optional comment.
- On submit: call `POST /api/sessions/{id}/runs/{runId}/feedback` via a BFF route.
- The modal must be dismissible without rating (skip is allowed).

**Transcript flag/upvote:**
- In `Transcript.tsx`, add subtle icon buttons (thumbs up / flag icon) on each AI message bubble. They appear on hover.
- Clicking "flag as incorrect" calls `POST .../transcript-feedback` with `type: "incorrect"`.
- Clicking "helpful" calls with `type: "helpful"`.
- After submission, the icon shows a confirmation state (filled icon) and is disabled.

**New BFF routes:**
- `src/app/api/sessions/[id]/runs/[runId]/feedback/route.ts`
- `src/app/api/sessions/[id]/runs/[runId]/transcript-feedback/route.ts`
- `src/app/api/professor/feedback-summary/route.ts`

**Definition of done:**
- [ ] Rating modal appears on disconnect, submits correctly, is dismissible.
- [ ] Flag/upvote icons on AI transcript messages function correctly.
- [ ] Confirmed state prevents double-submission.
- [ ] Component tests for modal and flag action.

---

#### Task J-12: Frontend — Professor analytics dashboard
**Effort:** 2 days | **Priority:** Phase 2

**New page:** `src/app/(dashboard)/professor/analytics/page.tsx`

**Layout:**
- Average session rating (large number + star display).
- Bar chart or list of "Most flagged topics" (use a simple HTML table or a lightweight chart — do not introduce a heavy charting library without approval).
- Count of helpful upvotes vs incorrect flags.
- "Refine Persona from Feedback" button (disabled until Seidu's persona feature is merged — show a tooltip explaining what it will do).

**New hook:** `src/hooks/useFeedbackSummary.ts` — fetches `GET /api/professor/feedback-summary` via BFF route.

**Navigation:** Add "Analytics" link to `NavigationHeader` (professors only).

**Definition of done:**
- [ ] Analytics page renders with real data from the API.
- [ ] Empty state handled gracefully when no feedback exists yet.
- [ ] "Refine Persona" button visible but appropriately disabled/labelled until persona module is live.
- [ ] Page is protected (professor role required).

---

### Priority 4 — Phase 2: GDPR Foundations (Weeks 8–10)

> Only the foundational backend pieces are in scope here: field encryption utility, consent fields, right-to-erasure, and data export. The cookie consent banner and privacy settings page are included. The full retention sweep background job is out of scope for this Devship.

Reference: `docs/product-roadmap-and-audit.md §Feature 7`.

---

#### Task J-13: AES-256-GCM field encryption utility
**Effort:** Half day | **Priority:** Phase 2

**New file:** `app/utils/crypto.py`

```python
import os, base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def encrypt_field(value: str, key: bytes) -> str:
    """Encrypts a UTF-8 string. Returns base64-encoded nonce+ciphertext."""
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ct = aesgcm.encrypt(nonce, value.encode(), None)
    return base64.b64encode(nonce + ct).decode()

def decrypt_field(ciphertext: str, key: bytes) -> str:
    """Decrypts a base64-encoded nonce+ciphertext. Returns plaintext string."""
    raw = base64.b64decode(ciphertext)
    nonce, ct = raw[:12], raw[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ct, None).decode()
```

**New env var:** `FIELD_ENCRYPTION_KEY` — a 32-byte hex string. Add to `app/config.py` (as a `SecretStr`) and `env.example`.

**Add dependency:** `cryptography` to `requirements.txt`.

**Definition of done:**
- [ ] `encrypt_field` / `decrypt_field` round-trip test passes.
- [ ] `FIELD_ENCRYPTION_KEY` declared in `config.py` as `SecretStr`.
- [ ] Added to `env.example` with a comment explaining its format.

---

#### Task J-14: GDPR user fields and consent migration
**Effort:** Half day | **Priority:** Phase 2

**Model changes** in `app/database/models.py` (add to `User`):
```python
gdpr_consent_at        = Column(DateTime, nullable=True)
marketing_emails_opt_in = Column(Boolean, default=False)
deleted_at             = Column(DateTime, nullable=True)
is_deleted             = Column(Boolean, default=False)
```

**Alembic migration:** `alembic revision --autogenerate -m "add_gdpr_user_fields"`.

**Frontend — consent checkbox:**
Add a required consent checkbox to the registration form (`src/app/(auth)/register/page.tsx`):
```
☐ I agree to the processing of my personal data as described in the Privacy Policy.
```
On registration, pass `gdpr_consent: true` in the request body. Backend records `gdpr_consent_at = datetime.utcnow()`.

**Definition of done:**
- [ ] Four new fields on `User`.
- [ ] Migration applies cleanly.
- [ ] Registration form has consent checkbox; submission is blocked until checked.
- [ ] `gdpr_consent_at` is stored on successful registration.

---

#### Task J-15: Right-to-erasure endpoint
**Effort:** 1 day | **Priority:** Phase 2

**New endpoint:** `DELETE /api/users/me`

**What it does (in a single database transaction):**
1. Anonymise `User` row: set `email = f"{uuid4()}@deleted.invalid"`, `first_name = "[deleted]"`, `last_name = "[deleted]"`, `password_hash = "[redacted]"`, `is_deleted = True`, `deleted_at = datetime.utcnow()`.
2. Delete all rows belonging to the user from: `StudentMemory`, `SessionFeedback`, `TranscriptFeedback`, `SessionQuizResult` (when those tables exist — skip gracefully if the table doesn't exist yet in the current migration state).
3. Null the `user_id` FK on `ProcessedWixOrder` rows (retain the order records for financial compliance, but unlink the user).
4. Delete all S3 objects under the user's upload prefix (call `cloud_storage_service` — handle S3 errors gracefully, log but do not fail the erasure).
5. Send an erasure confirmation email via `email_service`.

**New service:** `app/services/gdpr_service.py` — `erase_user(user_id, db)`.

**Definition of done:**
- [ ] Endpoint anonymises the `User` row correctly.
- [ ] Related PII rows are deleted.
- [ ] Financial records (`ProcessedWixOrder`) retain their row but with a null `user_id`.
- [ ] Confirmation email is sent.
- [ ] Integration test covering the full erasure flow on a test user.

---

#### Task J-16: Data export endpoint
**Effort:** 1–2 days | **Priority:** Phase 2

**New endpoint:** `GET /api/users/me/export`

**What it does:**
1. Queries all data belonging to the user: profile, sessions, session runs.
2. Assembles a ZIP archive containing:
   - `profile.json` — name, email, registration date
   - `sessions.json` — list of sessions
   - `billing.json` — credit balance history, access code redemptions
3. Uploads the ZIP to S3 with a 48-hour expiry pre-signed URL.
4. Emails the download link to the user.
5. Returns `{ "message": "Export link has been emailed to you." }` synchronously.

> Full transcript export (one JSON per session run) can be deferred to a follow-up task — the initial export ships without transcripts if the transcript storage format is not yet finalised by the RAG work.

**Definition of done:**
- [ ] ZIP is created and uploaded to S3.
- [ ] Pre-signed URL with 48-hour TTL is emailed.
- [ ] Endpoint returns 200 immediately; ZIP generation runs synchronously (Celery is out of scope for this task).
- [ ] Integration test confirms ZIP contains the correct files.

---

#### Task J-17: Frontend — Privacy settings and account deletion
**Effort:** 1 day | **Priority:** Phase 2

**New page:** `src/app/(dashboard)/profile/privacy/page.tsx`
- "Export my data" button — calls `GET /api/users/me/export` and shows "Check your email for the download link."
- "Delete my account" section — shows a warning, asks the user to type "DELETE" to confirm, then calls `DELETE /api/users/me`. On success, clears auth and redirects to `/`.
- Marketing email preference toggle (calls `POST /api/users/me/consent` to update `marketing_emails_opt_in`).

**New BFF routes:**
- `src/app/api/users/me/export/route.ts`
- `src/app/api/users/me/erase/route.ts`
- `src/app/api/users/me/consent/route.ts`

**Definition of done:**
- [ ] Deletion flow requires the user to type "DELETE" — no accidental deletions.
- [ ] After deletion, `clearAuth()` is called and the user is sent to the homepage.
- [ ] Component test for the confirmation input guard.

---

### Priority 5 — Phase 3: Auto Top-Up / Credit Refill (Weeks 10–11)

This feature lets users configure an automatic credit refill that triggers when their balance falls below a set threshold. **Auto top-up is off by default.** With the current Wix payment flow, a low-balance email notification is sent with a direct payment link when the threshold is crossed. When Stripe is later integrated in Phase 3, the same `AutoTopUpSettings` record drives automatic charges against the saved payment method — no model or API changes required.

Reference: `docs/product-roadmap-and-audit.md §Feature 8`.

---

#### Task J-18: Backend — Auto top-up data model and API
**Effort:** 1 day | **Priority:** Phase 3

**What to build:**

**New model** in `app/database/models.py`:

```python
class AutoTopUpSettings(Base):
    __tablename__ = "auto_top_up_settings"
    id                   = Column(UUID, primary_key=True, default=uuid4)
    user_id              = Column(UUID, ForeignKey("users.id"), unique=True, nullable=False)
    is_enabled           = Column(Boolean, default=False)   # OFF by default
    threshold_credits    = Column(Integer, default=100)     # trigger when balance falls below this
    top_up_amount_usd    = Column(Numeric(10, 2), default=Decimal("5.00"))
    notification_sent_at = Column(DateTime, nullable=True)  # rate-limits notifications to 1/24h
    updated_at           = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

**Alembic migration:** `alembic revision --autogenerate -m "add_auto_top_up_settings"`.

**New Pydantic schemas** in `app/schemas/schemas.py`:
- `AutoTopUpSettingsResponse`
- `AutoTopUpSettingsUpdateRequest` — `is_enabled`, `threshold_credits`, `top_up_amount_usd`

**New endpoints** (extend the existing billing router in `app/api/billing/api.py`):

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/billing/auto-top-up` | Yes | Get current user’s auto top-up settings |
| `PUT` | `/api/billing/auto-top-up` | Yes | Upsert settings (creates record on first call) |

**Hook into `deduct_credits()`** in `app/services/billing_service.py`:

After every successful deduction, check: `is_enabled AND new_balance < threshold_credits AND (notification_sent_at is None OR notification_sent_at < now() − 24h)`. If all true, call `_trigger_top_up_notification(user, settings, db)`:

```python
def _trigger_top_up_notification(user: User, settings: AutoTopUpSettings, db: Session) -> None:
    """Sends a low-balance email with a Wix payment link for the configured amount.
    Updates notification_sent_at to prevent repeat emails within 24 hours."""
```

The Wix payment link is built from `WIX_STORE_BASE_URL` (new env var — add to `app/config.py` and `env.example`). When Stripe is integrated, this function is replaced by an automatic charge; the model and API contract are unchanged.

**Definition of done:**
- [ ] `AutoTopUpSettings` model with `is_enabled=False` default in `models.py`.
- [ ] Alembic migration applies cleanly.
- [ ] `GET` and `PUT` endpoints work correctly (upsert on first `PUT`).
- [ ] `deduct_credits()` triggers notification when all conditions are met.
- [ ] Notification rate-limited: no repeat within 24 hours per user.
- [ ] `WIX_STORE_BASE_URL` added to `config.py` and `env.example`.
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated with new endpoints.
- [ ] Integration tests for both endpoints and the notification trigger path.

---

#### Task J-19: Frontend — Auto top-up settings UI
**Effort:** 1 day | **Priority:** Phase 3

**Where to build:** Add a settings card to `src/app/(dashboard)/billing/balance/page.tsx` (or within the existing billing layout — do not create a standalone page).

**UI elements:**
- **Toggle:** “Enable auto top-up” — **off by default**. All other controls are greyed-out when off.
- **Threshold input:** “Top up when balance falls below ___ credits” — numeric input, default 100, minimum 10.
- **Amount selector:** “Recharge amount” — dropdown of preset options: $2 (200 cr) / $5 (500 cr) / $10 (1,000 cr) / $20 (2,000 cr).
- **Save button** — calls `PUT /api/billing/auto-top-up`. Disabled if no changes have been made.
- **Status chip:** When enabled, shows “Active — will notify below {threshold} credits”.
- **Helper text when disabled:** “Auto top-up is off. Enable it to receive an email with a payment link when your credits run low.”

**New hook:** `src/hooks/useAutoTopUp.ts` — fetches settings on mount, exposes update function.

**New BFF route:** `src/app/api/billing/auto-top-up/route.ts` — proxies `GET` and `PUT /api/billing/auto-top-up`.

**Types:** Add `AutoTopUpSettings` to `src/types/types.ts`.

**Definition of done:**
- [ ] Toggle defaults to off on first load (before the user has configured anything).
- [ ] Controls are disabled/greyed-out when toggle is off.
- [ ] Settings persist correctly across page reloads.
- [ ] Save button disabled until user makes a change.
- [ ] BFF route created; no direct backend calls from the browser.
- [ ] Component test: toggling off disables other controls; save submits correct payload.
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated with new BFF route.

---

### Job — Milestone Summary

| Milestone | Target | Deliverables |
|---|---|---|
| **M-J1: Backend Reliability** | End of Week 1 | Tasks J-1 through J-5 merged |
| **M-J2: RAG Data Layer** | End of Week 3 | Tasks J-6, J-7 merged (with lead sign-off) |
| **M-J3: RAG Frontend** | End of Week 4 | Task J-8 merged (after lead integrates backend) |
| **M-J4: Feedback Loop Complete** | End of Week 7 | Tasks J-9 through J-12 merged |
| **M-J5: GDPR Foundations** | End of Week 10 | Tasks J-13 through J-17 merged |
| **M-J6: Auto Top-Up Complete** | End of Week 11 | Tasks J-18, J-19 merged; toggle off by default; email notification works end-to-end |

---

## Combined Priority Order (Lead View)

| # | Task | Dev | Week | Blocking? |
|---|---|---|---|---|
| 1 | S-1: Auth verify URL fix | Seidu | 1 | Unblocks everything frontend |
| 2 | J-1: Fix `get_optional_user` | Job | 1 | Unblocks guest-access endpoints |
| 3 | S-2: BFF auth routes | Seidu | 1 | Unblocks secure cross-origin auth |
| 4 | S-3: ProtectedRoute spinner | Seidu | 1 | UX fix |
| 5 | J-2: AGENTS.md bcrypt fix | Job | 1 | Documentation |
| 6 | J-3: Redis startup warning | Job | 1 | Ops observability |
| 7 | S-4: expires_at + proactive refresh | Seidu | 1 | Token longevity |
| 8 | S-5: 401 interceptor | Seidu | 1 | API resilience |
| 9 | J-4: Wix unmatched item logging | Job | 1 | Payment bug |
| 10 | J-5: Rate limiting on auth | Job | 1 | Security |
| 11 | S-6: Avatar + Persona models | Seidu | 2 | Needs migration slot |
| 12 | J-6: RAG models + migration | Job | 2 | Lead must set up pgvector first |
| 13 | S-7: Avatar + Persona API | Seidu | 2–3 | Needs S-6 |
| 14 | J-7: `ingest_session_document` | Job | 2–3 | Lead scaffolds rag_service.py first |
| 15 | S-8: Avatar/Persona wizard UI | Seidu | 3–4 | Needs S-7 |
| 16 | J-8: Sources indicator (FE) | Job | 4 | Lead integrates backend first |
| 17 | J-9: Feedback models | Job | 5 | Needs migration slot |
| 18 | J-10: Feedback API | Job | 5–6 | Needs J-9 |
| 19 | J-11: Rating modal + transcript flags | Job | 6–7 | Needs J-10 |
| 20 | J-12: Analytics dashboard | Job | 7–8 | Needs J-10 |
| 21 | J-13: Crypto utility | Job | 8 | GDPR foundation |
| 22 | J-14: GDPR user fields | Job | 8–9 | Needs migration slot |
| 23 | J-15: Erasure endpoint | Job | 9–10 | Needs J-14 |
| 24 | J-16: Data export endpoint | Job | 9–10 | Needs J-14 |
| 25 | J-17: Privacy settings UI | Job | 10 | Needs J-15 + J-16 |
| 26 | J-18: Auto top-up data model + API | Job | 10 | Needs migration slot |
| 27 | J-19: Auto top-up settings UI | Job | 11 | Needs J-18 |

---

## No-Conflict Zone Summary

The table below is the absolute rule: if both Devs need a file, the one listed goes first. The second branches from the first's merged commit.

| File | First to touch | Second (branches after merge) |
|---|---|---|
| `app/database/models.py` | Job (J-6, week 2) | Seidu (S-6, week 2 — coordinate timing) |
| `app/schemas/schemas.py` | Job (week 2) | Seidu (week 2 — coordinate timing) |
| `app/main.py` | Job (J-5 rate limiting) | Seidu (S-7 router registration) |
| `src/hooks/useHandleServerEvent.ts` | Job (J-8 tool handlers) | — |
| `src/constants/teachingAssistant.ts` | Job (J-8 tool names) | — |
| `NavigationHeader.tsx` | Seidu (S-8 persona link) | Job (J-12 analytics link — after S-8 merged) |
| `app/services/billing_service.py` | Job (J-18 auto top-up hook) | — |

---

## Definition of "Done" (applies to every task)

Before any PR is marked ready for review:

**Backend checklist:**
- [ ] `black . --check` exits 0
- [ ] `flake8 app/` exits 0
- [ ] `pytest tests/ -v` exits 0 (all tests pass, new tests written)
- [ ] Alembic migration included if any model changed; migration applied locally
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated if any endpoint added or changed
- [ ] No secrets or credentials in committed files

**Frontend checklist:**
- [ ] `npm run lint` exits 0
- [ ] `npx tsc --noEmit` exits 0
- [ ] `npm test` exits 0
- [ ] Manual smoke test in browser with backend running
- [ ] `profsidekick-frontend-main/AGENTS.md §5` updated if BFF routes added
