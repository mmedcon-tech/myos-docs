# ProfSidekick - Product Roadmap & Technical Audit

**Prepared:** 2026-05-25  
**Last updated:** 2026-05-25  
**Scope:** Full-stack audit of `backend-main` + `profsidekick-frontend-main`, plus feature specifications for the next development phases.

---

## Part 1 - Current Architecture

### Deployment Topology

```
User (browser)
    │
    ▼
Cloudflare  ──── DNS + subdomain proxy (DDoS, caching, SSL termination)
    │
    ▼
Vercel  ──── Next.js 15 frontend (profsidekick-frontend-main)
    │           App Router, BFF pattern: browser → Next.js API routes → backend
    │
    │  HTTPS REST
    ▼
Contabo VPS  ──── Ubuntu, self-managed
    ├─ FastAPI (backend-main, uvicorn)
    ├─ PostgreSQL  ──── primary database
    └─ Redis  ──── session/ephemeral cache
    │
    ├─→ AWS S3  ──── file storage: PDF, PPTX, slide images (optional CloudFront CDN)
    └─→ OpenAI API  ──── Vision, Chat Completions, Realtime (WebRTC)
```

### Key Technology Choices

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Next.js 15, React 19, TypeScript strict, Tailwind CSS | App Router, BFF proxy pattern |
| Backend | FastAPI, Python 3.11+, SQLAlchemy ORM | Async route handlers, Pydantic schemas |
| Database | PostgreSQL + Alembic migrations | UUID PKs, JSONB for slide metadata |
| Cache | Redis | Session caching, ephemeral token storage |
| File storage | AWS S3 + optional CloudFront CDN | Falls back to local disk in dev |
| Auth | JWT HS256 (24h expiry), bcrypt passwords | Email verification + professor approval flow |
| Billing | Credit-based (1 credit = $0.01 USD) | Access codes + Wix webhook purchase flow |
| AI | OpenAI Vision, Chat Completions, Realtime API | Ephemeral tokens for WebRTC voice |

### External Payment Flow (Wix)

Wix Store → Wix Automation (Velo code) → `POST /api/webhooks/wix-payment` → `ProcessedWixOrder` idempotency guard → `add_credits()` → `CreditBalance`.

---

## Part 2 - Active Bugs and Issues

### CRITICAL - Auth Persistence (Frontend)

**Bug 1: Wrong verify endpoint URL**

`AuthContext.tsx:61` hardcodes `/api/auth/verify` but the backend endpoint is `/api/auth/verify-token`. Every page refresh calls `GET /api/auth/verify` → 404 → `checkAuth()` clears localStorage → user is forced to log in on every page load.

```typescript
// CURRENT (broken) - AuthContext.tsx:61
const response = await fetch(config.getApiUrl('/api/auth/verify'), { ... });

// CORRECT - matches backend route and config.ts
const response = await fetch(config.getApiUrl(config.api.auth.verify), { ... });
// config.api.auth.verify = '/api/auth/verify-token'
```

**Fix:** Replace the hardcoded string with `config.api.auth.verify` in `checkAuth()`.

---

**Bug 2: Auth calls bypass the BFF pattern**

`AuthContext.tsx` calls `config.getApiUrl(...)` (direct backend URL) for `login`, `logout`, `checkAuth`, and `refreshToken`. The AGENTS.md contract requires all browser→backend traffic to go through `src/app/api/` Next.js route handlers. In production, direct cross-origin requests from the browser to the Contabo VPS may fail or require CORS to be open on the backend, which weakens security.

**Fix:** Create BFF route handlers:
- `src/app/api/auth/login/route.ts`
- `src/app/api/auth/logout/route.ts`
- `src/app/api/auth/verify/route.ts`
- `src/app/api/auth/refresh/route.ts`

Then update `AuthContext` to call `/api/auth/login` (Next.js route) instead of `config.getApiUrl('/api/auth/login')` (direct backend).

---

**Bug 3: No automatic 401 retry with token refresh**

When any authenticated API call returns 401 (expired token), there is no interceptor that automatically attempts a token refresh and retries the request. Users receive opaque errors or are silently broken. The `refreshToken()` function exists in `AuthContext` but is never called reactively.

**Fix:** Add a 401 interceptor to `src/lib/api.ts` (`apiFetch`):
```typescript
if (response.status === 401) {
  await refreshToken();
  return apiFetch(url, { ...init, token: newToken }); // retry once
}
```

---

**Bug 4: Flash of blank content during protected route check**

`ProtectedRoute` returns `null` (blank) while `isLoading=true`, then redirects when `isLoading=false && !isAuthenticated`. Combined with Bug 1 (verify fails → isLoading stays true longer), users see a white flash or blank screen on every navigation.

**Fix:** Return the loading spinner instead of `null`. Never render blank.

---

### HIGH - Backend

**Bug 5: `get_optional_user` is not actually optional**

`app/dependencies/auth.py:38` - `get_optional_user` declares `credentials: HTTPAuthorizationCredentials = Depends(security)` where `security = HTTPBearer()`. FastAPI's `HTTPBearer` raises HTTP 403 automatically when no `Authorization` header is present. This means `get_optional_user` behaves identically to `get_current_user`.

**Fix:**
```python
async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False)),
    db: Session = Depends(get_db),
) -> Optional[User]:
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None
```

---

**Bug 6: Token expiry not communicated to frontend**

`create_access_token()` returns `expires_at` but `AuthContext` never stores it. No proactive refresh before expiry. Users with sessions older than 24h silently break.

**Fix:** Store `expires_at` in localStorage. On `checkAuth()`, if within 30 minutes of expiry, call `refreshToken()` proactively.

---

**Bug 7: AGENTS.md incorrect - bcrypt claim**

`backend-main/AGENTS.md §3.5` states "hashed with bcrypt via **passlib**". The implementation uses the `bcrypt` library directly. Minor but misleading for future contributors.

**Fix:** Update AGENTS.md §3.5 to say "hashed with `bcrypt` directly (not passlib)".

---

### MEDIUM - Wix Integration

**Bug 8: Unmatched line items not logged at item level**

The `catalogs` key observed in live Wix payloads may carry product data for certain order types alongside `lineItems`. Unmatched items are silently skipped. Add per-item warning logging when `_extract_product_id` returns `None`.

---

### LOW

**Bug 9: `start.py` `create_all` / Alembic conflict on schema additions**

On first Railway deploy, `start.py` calls `create_all()` and stamps Alembic `head`. Any model added after initial deployment requires an explicit `alembic upgrade head` - `create_all` will not add the table. Teams that deployed before billing migrations must run `alembic upgrade head` manually.

**Bug 10: Redis failure is fully silent**

`connection.py` never alerts when Redis is unavailable. Add a startup Redis ping with a `WARNING` log so operations teams are alerted when it goes down.

**Bug 11: No rate limiting on auth endpoints**

`POST /api/auth/login` has no rate limiting. Add `slowapi` or an nginx rate limit before wider production rollout.

---

## Part 3 - Feature Roadmap

### Platform Model: Professor (Publisher) ↔ Student (Subscriber)

The core model of ProfSidekick is a **two-sided platform**:

- **Professor (Publisher):** Uploads course material, defines their AI avatar's persona (teaching style, voice, behaviour), and controls how the AI represents their knowledge in sessions. The professor is the content owner.
- **Student (Subscriber):** Joins sessions created by their professor and interacts with the professor's AI avatar. The avatar's behaviour is entirely defined by the professor's configuration. The student's interaction history feeds back to improve that specific professor–student context over time.

All features below are designed around this model.

---

### Feature 1 - AI Avatar Selection & Persona

**Summary:** Professors choose a base avatar from a curated library (visual identity + default voice), then fully define the persona - the avatar's name, teaching style, tone, and post-session behaviour. A built-in LLM refinement step converts their preference selections into a polished system prompt they can review and adjust.

#### 1a - Curated Avatar Library (base identities)

Professors choose a visual identity and default voice. These are cosmetic starting points - the persona is defined separately.

| Avatar | Default voice | Default persona |
|---|---|---|
| Prof. Carter | Measured, precise | University academic |
| Dr. Rivera | Calm, clinical | Medical professional |
| Advocate Chen | Structured, persuasive | Legal practitioner |
| Coach Morgan | Energetic, concise | Sports & performance |
| Dr. Amara | Inquisitive, thorough | Research scientist |

#### 1b - Professor Persona Definition

After selecting a base avatar, the professor configures how it will behave with students. All selections are stored as structured preferences, then refined into a system prompt by an LLM.

**Predefined preference dimensions:**

| Dimension | Options |
|---|---|
| Pacing | Thorough & detailed / Balanced / Fast & concise |
| Questioning style | Socratic (question-led) / Direct (explain then check) / Guided discovery |
| Formality | Casual & encouraging / Balanced / Formal & academic |
| Depth | Surface (key points) / Standard / Deep (theory + edge cases) |
| Post-session check | Enabled: AI quizzes student at session end / Disabled |
| Encouragement | High (frequent affirmation) / Neutral / Minimal |
| Language complexity | Introductory / Intermediate / Advanced / Adaptive |

**LLM persona refinement:** After the professor sets their preferences, they click "Refine with AI". The backend sends the preference selections to GPT-4o with a prompt:

```
Given a professor with these teaching preferences: {preferences_json},
generate a concise, effective AI system prompt persona for an educational
assistant. The persona should be specific, consistent, and natural.
Maximum 150 words. Output only the persona description.
```

The professor sees the result, can regenerate or edit it manually, then saves. The refined prompt is stored as `professor_personas.refined_prompt` and injected into every session's system prompt.

#### 1c - Post-Session Understanding Check

If the professor enables post-session check, the AI automatically runs a short quiz at the end of each session:
- Generates 2–4 questions from the session's slide content
- Asks the student by voice
- Stores the student's responses as `SessionQuizResult`
- The professor can review quiz results per student per session

**Backend changes required:**
- New model: `Avatar` - `id`, `name`, `thumbnail_url`, `voice_id`, `default_persona_hint`, `is_active`
- New model: `ProfessorPersona` - `id`, `professor_id`, `avatar_id`, `preference_selections` (JSONB), `refined_prompt`, `post_session_quiz_enabled`, `created_at`, `updated_at`
- New model: `SessionQuizResult` - `id`, `session_run_id`, `student_id`, `questions` (JSONB), `answers` (JSONB), `created_at`
- New endpoints:
  - `GET /api/avatars` - list base avatars
  - `GET /api/professor/persona` - get current persona
  - `POST /api/professor/persona` - create/update persona
  - `POST /api/professor/persona/refine` - LLM refinement call, returns refined prompt
  - `GET /api/sessions/{id}/runs/{runId}/quiz-results` - professor views student quiz results
- `generate_ephemeral_token()` - inject `refined_prompt` + quiz instructions if enabled
- Alembic migration: `avatars`, `professor_personas`, `session_quiz_results` tables

**Frontend changes required:**
- Persona setup wizard in professor onboarding / settings
- Step 1: Avatar selection grid
- Step 2: Preference sliders/toggles
- Step 3: AI refinement - show generated prompt, allow edit, confirm
- Avatar display in `TeachingInterface` header
- Quiz results panel in `SessionRuns` history view
- New hooks: `useAvatars.ts`, `useProfessorPersona.ts`
- New BFF routes: `src/app/api/avatars/route.ts`, `src/app/api/professor/persona/`

---

### Feature 2 - RAG-Based Content Pipeline (replaces raw file injection)

**Summary:** The current approach embeds full slide text directly into the system prompt for every session. This is expensive (all tokens charged every call), inaccurate (irrelevant slides dilute focus), and does not scale. Replace with a **Retrieval-Augmented Generation (RAG)** pipeline: slides are chunked, embedded, stored in a vector database, and only relevant chunks are retrieved at query time.

#### Architecture: RAG Pipeline

```
File Upload
    │
    ▼
LangChain Document Loader
    │  (PDFLoader / UnstructuredPowerPointLoader)
    ▼
Text Splitter  - chunk size: 400 tokens, overlap: 50
    │
    ▼
OpenAI Embeddings (text-embedding-3-small)
    │
    ▼
pgvector (PostgreSQL extension)  - stored as SlideChunk rows
    │
                        ┌─────────────────────┐
At session time:        │   Student question   │
                        └──────────┬──────────┘
                                   ▼
                        Embed question → cosine search
                                   │
                        Top-k relevant chunks retrieved
                                   │
                        Injected into system prompt context window
                                   │
                        OpenAI Realtime / Chat Completions
```

#### Why this approach

| Problem (current) | Solution (RAG) |
|---|---|
| All slides injected every turn - high token cost | Only retrieve the 3–5 most relevant chunks per query |
| Full PPTX context = 2,000–8,000 tokens per session | Retrieved context = 300–600 tokens per query |
| Irrelevant slide content confuses the model | Only topically matched content is shown |
| Model hallucinates when slides are ambiguous | Grounded retrieval with source attribution |
| No cross-session memory without full re-injection | Student memory summaries stored as embeddable documents |

#### Implementation components

**New dependency:** `langchain`, `langchain-openai`, `langchain-community`, `pgvector` (SQLAlchemy extension)

**New model: `SlideChunk`**
```python
class SlideChunk(Base):
    __tablename__ = "slide_chunks"
    id          = UUID primary key
    session_id  = FK → sessions.id
    slide_number = Integer
    chunk_index  = Integer
    content      = Text
    embedding    = Vector(1536)   # pgvector column
    created_at   = DateTime
```

**New model: `KnowledgeChunk`** (for professor answers, knowledge captures)
```python
class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"
    id           = UUID primary key
    session_id   = FK → sessions.id
    source       = String  # "professor_answer" | "slide" | "post_session_note"
    content      = Text
    embedding    = Vector(1536)
    created_at   = DateTime
```

**New service: `rag_service.py`**
- `ingest_session_document(session_id, file_path, db)` - runs on upload, replaces direct Vision embedding
- `retrieve_context(session_id, query, top_k=5, db)` - cosine similarity search, returns ranked chunks
- `build_grounded_prompt(session_id, query, persona, student_memory, db)` - assembles final context block for injection

**Changes to `openai_service.py`:**
- `generate_ephemeral_token()` - no longer injects all slides; injects a short grounded preamble + retrieval instructions
- For Realtime sessions, implement a `searchKnowledge(query)` tool that calls `rag_service.retrieve_context()` on the backend via a real-time function call, returning the relevant chunks as tool output

**Changes to `file_processor.py`:**
- After slide image generation, call `rag_service.ingest_session_document()` to embed text content
- Vision API still used for image understanding (diagrams, charts) - output is embedded as a knowledge chunk

**Alembic migration:** Add `pgvector` extension, `slide_chunks` table, `knowledge_chunks` table. Requires `pgvector` PostgreSQL extension on Contabo VPS (`apt install postgresql-16-pgvector`).

**Frontend changes:**
- No visible change in upload flow - RAG ingestion is a backend pipeline
- `TeachingInterface` shows a "Sources" indicator on AI responses when `citeSlide` or `searchKnowledge` tool fires
- Source slide highlighted in `SlidesPreview` component

---

### Feature 3 - Student Context Memory & Cross-Session Continuity

**Summary:** The AI accumulates a compressed memory of each student's interaction history. When a student enters a new session, the AI can make references across related sessions ("as we covered in your networking session last week…"). The memory system is designed to minimize token cost - full transcripts are never re-injected.

#### Memory architecture

```
Session ends
    │
    ▼
SessionMemorySummary generated by GPT-4o-mini
    │  Prompt: "Summarize this student's learning session in 3 sentences:
    │   what they understood, what they struggled with, key questions asked."
    │  Cost: ~500 tokens input, ~80 tokens output per session
    ▼
Stored as StudentMemory row with embedding
    │
At next session start:
    │
    ▼
Retrieve top-3 relevant past memories by cosine similarity to current session topic
    │
    ▼
Inject as compressed preamble (≈ 200 tokens total):
    "Student context: In a previous Networking session, this student
     understood TCP/IP but struggled with subnetting. They asked about
     CIDR notation and found visual diagrams helpful."
```

#### Token cost analysis

| Approach | Tokens per session start | Cost at $0.15/1M tokens |
|---|---|---|
| Inject last 3 full transcripts | ~12,000 tokens | $0.0018 per session |
| Inject 3 memory summaries (proposed) | ~200 tokens | $0.00003 per session |
| **Savings** | **98.3% reduction** | |

#### Cross-session reference capability

The AI does not access past sessions raw - it reads the injected summaries. When it references a past session, it is doing so from the 200-token summary, not a full re-read. This is accurate enough for subject continuity while keeping cost negligible.

**Backend changes required:**
- New model: `StudentMemory` - `id`, `student_id`, `session_run_id`, `course_id`, `summary_text`, `embedding` (Vector 1536), `key_topics` (JSONB array), `created_at`
- New service: `memory_service.py`
  - `generate_session_summary(session_run_id, transcript, db)` - called async on session end
  - `retrieve_student_context(student_id, current_session_id, top_k=3, db)` - cosine search on embeddings
  - `build_student_preamble(student_id, current_session_id, db)` → `str` (≤200 tokens)
- `generate_ephemeral_token()` - call `build_student_preamble()` and prepend to system prompt
- New endpoint: `POST /api/sessions/{id}/runs/{runId}/generate-memory` - called by Celery worker on run end
- Alembic migration: `student_memories` table

**Frontend changes required:**
- No new UI required at launch
- Optional Phase 2 addition: "Your Learning Journey" panel in student dashboard showing past session summaries

---

### Feature 4 - Hallucination Reduction (RAG + Constraints)

**Summary:** Combines the RAG pipeline (Feature 2) with policy-level constraints and source citation to structurally reduce fabricated responses.

**4a - Grounded retrieval replaces full-context injection**

See Feature 2. By retrieving only relevant chunks, the model cannot confabulate from irrelevant slides it was never shown.

**4b - Constrained answer policy in system prompt**

```
STRICT GROUNDING RULE: You may only answer questions using information
present in the retrieved context blocks marked <source>. If a student
asks something not covered in those blocks, say exactly:
"That's outside our material for today - I'll note that question."
Never fabricate clinical, legal, financial, or technical facts.
```

**4c - `searchKnowledge` tool (Realtime sessions)**

The AI calls this tool before answering factual questions. The tool performs a live RAG query against the session's vector store and returns grounded chunks. The AI's response is anchored to the tool's output.

```json
{
  "name": "searchKnowledge",
  "description": "Search the session's knowledge base for relevant content before answering.",
  "parameters": {
    "query": { "type": "string", "description": "The topic or question to look up." }
  }
}
```

**4d - `citeSlide` tool (Realtime sessions)**

When answering from a specific slide, the AI calls `citeSlide(slideNumber)`. The frontend highlights that slide in `SlidesPreview`, making the source auditable.

**4e - Confidence disclaimer (Chat Completions)**

For non-Realtime calls, request `logprobs: true` in Chat Completions. If the mean log-probability of the response is below threshold (-2.5), append: "*(This answer is based on general knowledge and may need verification.)*"

**Backend changes required:**
- `openai_service.py` - add `_build_grounded_system_prompt()` composing: persona + policy constraint + retrieved RAG context + student memory preamble
- Add `searchKnowledge` and `citeSlide` tool definitions to `generate_ephemeral_token()`
- Add a `/api/sessions/{id}/search-knowledge` endpoint the Realtime tool can call via a server-sent function response

**Frontend changes required:**
- Handle `searchKnowledge` tool call in `useHandleServerEvent.ts` - show a "Looking up..." indicator briefly
- Handle `citeSlide` tool call - highlight slide in `SlidesPreview`, add source badge to transcript message

---

### Feature 5 - Student Interaction Feedback Loop

**Summary:** Structured signals captured from every student interaction are used to progressively adjust the professor's AI persona and improve context quality over time. This is not RLHF - it is a cost-effective feedback store that drives prompt tuning decisions.

#### Feedback signals collected

| Signal | Trigger | Storage |
|---|---|---|
| Session rating | Student rates session 1–5 after disconnect | `SessionFeedback.rating` |
| Incorrect flag | Student taps "Flag as incorrect" on a transcript message | `TranscriptFeedback.type = "incorrect"` |
| Helpful upvote | Student taps "Helpful" on a message | `TranscriptFeedback.type = "helpful"` |
| Comprehension score | Post-session quiz result (Feature 1c) | `SessionQuizResult` |
| Topic confusion | AI uses `flagForReview(topic)` tool when student asks the same question 3+ times | `SessionConfusionLog` |

#### Feedback → context adjustment loop

```
Feedback signals accumulate
    │
    ▼  (weekly / on-demand for professor)
Feedback summary generated:
  "Students consistently flag explanations of [topic X] as incorrect.
   Average session rating: 3.2/5. Most flagged slide: #7."
    │
    ▼
Professor reviews summary in dashboard
    │
    ▼
Professor refines persona (adjusts preferences, edits prompt)
    ├── OR triggers LLM auto-refinement:
    │   "Given this feedback, suggest 2 changes to the persona prompt."
    └── Updated persona stored → active on next session
```

The feedback loop is **human-in-the-loop**: the AI surfaces patterns, the professor decides what to change. No automatic prompt mutation without professor approval.

**Backend changes required:**
- New model: `SessionFeedback` - `id`, `session_run_id`, `user_id`, `rating` (1–5), `comment`, `created_at`
- New model: `TranscriptFeedback` - `id`, `session_run_id`, `message_index`, `feedback_type`, `user_id`, `created_at`
- New model: `SessionConfusionLog` - `id`, `session_run_id`, `topic`, `student_id`, `created_at`
- New endpoints:
  - `POST /api/sessions/{id}/runs/{runId}/feedback`
  - `POST /api/sessions/{id}/runs/{runId}/transcript-feedback`
  - `GET /api/professor/feedback-summary` - aggregated across all professor's sessions
  - `POST /api/professor/persona/refine-from-feedback` - LLM suggests prompt changes based on summary
- Alembic migration: `session_feedback`, `transcript_feedback`, `session_confusion_logs` tables

**Frontend changes required:**
- Star rating modal triggered on `TeachingInterface` disconnect
- Flag / upvote micro-actions on `Transcript.tsx` message bubbles (subtle icon buttons)
- Feedback analytics page: `/professor/analytics` - rating trends, most flagged topics, quiz pass rates
- "Refine Persona" button on analytics page that triggers LLM suggestion flow

---

### Feature 6 - Stripe Recurring Subscriptions

**Summary:** Replace the one-off Wix credit purchase model with on-platform subscription billing via Stripe. Wix checkout remains available but Stripe becomes the primary billing path.

**Proposed subscription tiers:**

| Tier | Price | Credits/month | Key unlocks |
|---|---|---|---|
| Free | $0 | 200 | 1 session, default avatar, no RAG |
| Educator | $15/month | 5,000 | All avatars, persona builder, RAG pipeline, 50 sessions |
| Professional | $40/month | 20,000 | Knowledge capture, feedback analytics, cross-session memory |
| Institution | Custom | Unlimited | Custom avatars, SSO, admin dashboard, SLA |

**Backend changes required:**
- New dependency: `stripe` Python SDK
- New model: `StripeSubscription` - `id`, `user_id`, `stripe_customer_id`, `stripe_subscription_id`, `plan`, `status`, `current_period_end`, `cancel_at_period_end`, `created_at`
- New model: `StripeInvoice` - `id`, `subscription_id`, `stripe_invoice_id`, `amount_paid_usd`, `credits_granted`, `created_at`
- New config vars: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID_EDUCATOR`, `STRIPE_PRICE_ID_PROFESSIONAL`
- New endpoints:
  - `POST /api/billing/subscription/create-checkout` - returns Stripe Checkout URL
  - `POST /api/billing/subscription/cancel`
  - `GET /api/billing/subscription/status`
  - `POST /api/webhooks/stripe` - handles `invoice.paid`, `customer.subscription.deleted`, `customer.subscription.updated`
- On `invoice.paid`: top up `CreditBalance` for the plan's monthly allotment
- Tier enforcement middleware: gate RAG ingestion, persona builder, and memory features by `StripeSubscription.plan`
- Alembic migration: `stripe_subscriptions`, `stripe_invoices` tables

**Frontend changes required:**
- Public pricing page: `/pricing`
- Subscription management page: `/billing/subscription`
- Plan badge in `NavigationHeader` (Free / Educator / Pro)
- Feature gates in UI - show "Upgrade to Educator" prompt when a locked feature is accessed
- `@stripe/react-stripe-js` for Checkout redirect

---

### Feature 7 - GDPR Compliance & Data Encryption

**Summary:** ProfSidekick handles personally identifiable information (PII) - student names, emails, interaction transcripts, quiz results, and learning histories. GDPR compliance is required for any European users and is good practice universally.

#### 7a - Data classification

| Data type | Classification | Retention policy |
|---|---|---|
| User email, name | PII - personal data | Retained until account deletion |
| Session transcripts | PII - sensitive (learning behaviour) | 12 months default; configurable per institution |
| Student memory summaries | PII - derived personal data | Retained until account deletion |
| Quiz results | PII - assessment data | Retained until account deletion or course end |
| Usage/billing records | Financial data | 7 years (legal minimum) |
| Slide content | Professor intellectual property | Retained until session/course deletion |

#### 7b - Encryption at rest

**Database-level encryption:**
- Enable PostgreSQL Transparent Data Encryption (TDE) on Contabo VPS, or use disk-level encryption (`dm-crypt` / LUKS on the VPS volume)
- Sensitive text fields (transcript content, student memory summaries) encrypted at the application layer using AES-256-GCM before storing:
  - New utility: `app/utils/crypto.py` - `encrypt_field(value, key)` / `decrypt_field(ciphertext, key)`
  - New env var: `FIELD_ENCRYPTION_KEY` (32-byte base64-encoded key, rotatable)
  - Fields to encrypt: `StudentMemory.summary_text`, `SessionQuizResult.answers`, `TranscriptFeedback` content

**S3 encryption:**
- Enable S3 Server-Side Encryption (SSE-S3 or SSE-KMS) on the bucket - one-click setting in AWS console, no code change required

**Encryption in transit:**
- Already handled by Cloudflare (TLS to browser) and HTTPS between Vercel and Contabo VPS
- Ensure TLS 1.2+ is enforced on the VPS nginx/uvicorn layer

#### 7c - Right to erasure (Article 17)

New endpoint: `DELETE /api/users/me` (or `POST /api/users/me/erase`)

What it does:
1. Anonymises `User` row: scrambles email/name with a UUID placeholder, nulls PII fields
2. Deletes: `StudentMemory`, `SessionFeedback`, `TranscriptFeedback`, `SessionQuizResult`, `AccessCodeRedemption`, `UsageRecord` rows for this user
3. Deletes uploaded files from S3 (slide images, presentation files)
4. Sets `User.is_deleted = True`, records `deleted_at` timestamp
5. Preserves: billing records (financial compliance), anonymised `UsageRecord` aggregate (platform analytics)
6. Triggers email confirmation to user that erasure is complete

**Important:** `ProcessedWixOrder` and `StripeInvoice` records linked to the user are retained for 7 years (financial regulation) but the user FK is nulled (anonymous).

#### 7d - Data portability (Article 20)

New endpoint: `GET /api/users/me/export`

Returns a ZIP archive containing:
- `profile.json` - name, email, registration date
- `sessions.json` - list of sessions created
- `transcripts/` - one JSON file per session run with full transcript
- `quiz_results.json` - all quiz results
- `billing.json` - credit history, purchase records

Archive is encrypted with the user's password (AES-256) and a download link is emailed. Files are deleted from S3 after 48 hours.

#### 7e - Consent management

- Registration flow: explicit consent checkbox for data processing, stored as `User.gdpr_consent_at` timestamp
- Cookie consent banner on public pages (currently none exists)
- Email unsubscribe: `User.marketing_emails_opt_in` boolean field; all transactional emails (verification, approval) are exempt

#### 7f - Data minimisation

- Transcripts: stored as compressed JSONB, not full verbatim text where possible
- Student memory summaries: maximum 3 sentences by design (already in Feature 3)
- Slide embeddings: contain no PII, safe to retain
- Auto-delete session run transcripts after 12 months unless institution has extended retention configured

**Backend changes required:**
- New util: `app/utils/crypto.py` - AES-256-GCM field encryption
- New env var: `FIELD_ENCRYPTION_KEY`
- Model updates: `User` - add `gdpr_consent_at`, `marketing_emails_opt_in`, `deleted_at`, `is_deleted` fields
- New endpoints:
  - `DELETE /api/users/me` - erasure
  - `GET /api/users/me/export` - portability
  - `POST /api/users/me/consent` - update consent preferences
- New Alembic migration for GDPR fields
- Background job: monthly sweep to delete transcripts older than retention policy

**Frontend changes required:**
- Consent checkbox on registration form
- Cookie consent banner component
- "Delete my account" button in profile settings with confirmation flow
- "Export my data" button in profile settings
- Privacy settings page: `/profile/privacy`

---

## Feature 8 — Auto Top-Up (Credit Refill)

**What it is:** An opt-in setting (off by default) that automatically triggers a top-up action when a user's credit balance falls below a configurable threshold. Users configure the threshold and the top-up amount; the system handles the rest.

**Why it matters:** Users running sessions mid-flow should never be blocked by a zero balance. This feature provides a safety net without requiring the user to monitor their credits manually.

**Phase 3 scope (current Wix payment flow):**
When a user's balance crosses below the threshold after any credit deduction, the system sends them an email containing a direct Wix payment link pre-set to the configured top-up amount. A 24-hour cooldown prevents notification spam.

**Phase 4 upgrade path (Stripe):**
When Stripe is integrated, the same `AutoTopUpSettings` record drives an automatic charge against the user's saved payment method. No UI changes are required — only the `_trigger_top_up_notification()` function is replaced by a Stripe charge call.

**New database model:**

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | UUID | auto | PK |
| `user_id` | UUID FK → users | — | unique per user |
| `is_enabled` | Boolean | `False` | **off by default** |
| `threshold_credits` | Integer | 100 | trigger when balance falls below this |
| `top_up_amount_usd` | Numeric(10,2) | 5.00 | amount to charge / link to |
| `notification_sent_at` | DateTime | null | rate-limits emails to 1 per 24h |
| `updated_at` | DateTime | now | auto-updated |

**New API endpoints:**

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/billing/auto-top-up` | Yes | Get current settings |
| `PUT` | `/api/billing/auto-top-up` | Yes | Upsert settings (creates on first call) |

**Backend changes required:**
- New model: `AutoTopUpSettings` in `app/database/models.py`
- New Alembic migration: `add_auto_top_up_settings`
- New Pydantic schemas: `AutoTopUpSettingsResponse`, `AutoTopUpSettingsUpdateRequest`
- Hook in `app/services/billing_service.py` → `deduct_credits()` calls `_trigger_top_up_notification()` when conditions are met
- New env var: `WIX_STORE_BASE_URL` — base URL of the Wix credit store (add to `config.py` and `env.example`)

**Frontend changes required:**
- Auto top-up settings card in `src/app/(dashboard)/billing/balance/page.tsx`
- Toggle (off by default), threshold input, amount dropdown, save button
- New hook: `src/hooks/useAutoTopUp.ts`
- New BFF route: `src/app/api/billing/auto-top-up/route.ts`
- New type: `AutoTopUpSettings` in `src/types/types.ts`

**Allocation:** Task J-18 (backend) + Task J-19 (frontend) — see `docs/task-allocation.md`.

---

## Part 4 - Implementation Priority

### Immediate fixes (before any new features)

| # | Fix | File(s) | Effort |
|---|---|---|---|
| 1 | Auth verify endpoint URL | `AuthContext.tsx:61` | 1 line |
| 2 | Auth BFF route handlers | `src/app/api/auth/*/route.ts` × 4 | 2–3 hours |
| 3 | Fix `get_optional_user` | `app/dependencies/auth.py` | 5 lines |
| 4 | 401 auto-refresh in `apiFetch` | `src/lib/api.ts` | 30 lines |
| 5 | Store + proactive check of `expires_at` | `AuthContext.tsx` | 20 lines |
| 6 | ProtectedRoute blank flash | `ProtectedRoute.tsx` | 5 lines |
| 7 | AGENTS.md bcrypt wording | `backend-main/AGENTS.md §3.5` | 1 line |

### Phase 1 - Foundation (4–6 weeks)

1. **Auth BFF + persistence fixes** - prerequisite for everything; sessions must actually persist
2. **RAG pipeline** - `SlideChunk`, `KnowledgeChunk`, pgvector, LangChain ingestion, `rag_service.py`; replaces all raw file injection
3. **Avatar library + persona builder** - base avatars, preference UI, LLM refinement, system prompt injection
4. **Constrained answer policy + `searchKnowledge` tool** - hooks into RAG, immediate hallucination improvement

### Phase 2 - Intelligence layer (6–10 weeks)

5. **Student memory + cross-session context** - `StudentMemory`, `memory_service.py`, 200-token preamble injection
6. **Feedback loop** - session ratings, transcript flagging, professor analytics dashboard
7. **Post-session quiz** - AI-generated questions, student voice responses, `SessionQuizResult`
8. **Feedback → persona refinement** - LLM surfaces patterns, professor approves changes
9. **GDPR compliance** - field encryption, erasure endpoint, export endpoint, consent fields

### Phase 3 - Business model (10–16 weeks)

10. **Stripe subscriptions** - recurring billing, tier enforcement, credit top-up on `invoice.paid`
11. **Tier gating** - enforce feature access by subscription plan in backend middleware
12. **Institution tier** - SSO (SAML/OIDC), bulk seat management, admin analytics dashboard

---

## Part 5 - Architecture Changes Required

### Phase 1 infrastructure additions (Contabo VPS)

| Addition | Purpose | Install command |
|---|---|---|
| `pgvector` PostgreSQL extension | Vector similarity search for RAG | `apt install postgresql-16-pgvector` then `CREATE EXTENSION vector;` |
| Python packages | LangChain RAG pipeline | `pip install langchain langchain-openai langchain-community pgvector` |
| Disk encryption (LUKS) | GDPR encryption at rest | Configure on VPS volume at provision time |

### Phase 2 infrastructure additions

| Addition | Purpose | Notes |
|---|---|---|
| Celery + Redis worker | Async jobs: session summary generation, data export, transcript cleanup | Same Redis instance; add `celery` to requirements |
| S3 SSE-KMS | GDPR encryption for uploaded files | One-click in AWS S3 bucket settings |

### Phase 3 infrastructure considerations

| Concern | Current | Recommended |
|---|---|---|
| Background jobs | Celery (added Phase 2) | Already in place |
| Search (if marketplace added later) | pgvector already present | PostgreSQL full-text sufficient to 50k records |
| Payment webhooks | Wix (custom) | Stripe handler added alongside Wix handler |
| Autoscaling | Single VPS | Adequate to ~500 concurrent; migrate to multi-instance if needed |

### Token cost optimisation summary

| Component | Before RAG | After RAG + Memory |
|---|---|---|
| Slide context per query | 2,000–8,000 tokens | 300–600 tokens (retrieved chunks only) |
| Student context per session | 0 (not implemented) | ~200 tokens (3 summaries) |
| Total context overhead | ~8,000 tokens | ~800 tokens |
| Approximate cost saving | - | ~90% reduction in context tokens |

---

## Appendix A - Files to Create or Modify: Immediate Fixes

| File | Change |
|---|---|
| `profsidekick-frontend-main/src/contexts/AuthContext.tsx` | Fix verify URL; replace all direct `getApiUrl` auth calls with Next.js routes |
| `profsidekick-frontend-main/src/app/api/auth/login/route.ts` | New BFF proxy |
| `profsidekick-frontend-main/src/app/api/auth/logout/route.ts` | New BFF proxy |
| `profsidekick-frontend-main/src/app/api/auth/verify/route.ts` | New BFF proxy → `/api/auth/verify-token` |
| `profsidekick-frontend-main/src/app/api/auth/refresh/route.ts` | New BFF proxy |
| `profsidekick-frontend-main/src/lib/api.ts` | Add 401 interceptor + refresh-and-retry |
| `profsidekick-frontend-main/src/components/auth/ProtectedRoute.tsx` | Spinner instead of `null` while loading |
| `backend-main/app/dependencies/auth.py` | Fix `get_optional_user` with `auto_error=False` |
| `backend-main/AGENTS.md §3.5` | Correct bcrypt/passlib wording |

## Appendix B - New Database Tables Summary

| Table | Feature | Phase |
|---|---|---|
| `avatars` | Avatar library | 1 |
| `professor_personas` | Persona definition | 1 |
| `slide_chunks` | RAG vector store | 1 |
| `knowledge_chunks` | RAG knowledge embeddings | 1 |
| `student_memories` | Cross-session memory | 2 |
| `session_quiz_results` | Post-session quiz | 2 |
| `session_feedback` | Feedback loop | 2 |
| `transcript_feedback` | Per-message feedback | 2 |
| `session_confusion_logs` | Topic confusion tracking | 2 |
| `stripe_subscriptions` | Recurring billing | 3 |
| `stripe_invoices` | Invoice records | 3 |

GDPR additions to existing tables: `User` - add `gdpr_consent_at`, `marketing_emails_opt_in`, `deleted_at`, `is_deleted`.
