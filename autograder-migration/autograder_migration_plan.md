# Autograder → MyOSv2 Migration Plan (Final)

## What Changed From Previous Drafts

- **No subscriber role in autograder at all.** Publishers are both creator and operator. They log in, create the assessment, register students, upload PDFs, and read results under their own publisher account. Subscriber JWTs get HTTP 403 on every autograder route.
- **`ag_assessment_operators` table is gone.** No enrollment bridge is needed.
- **No NETids on the platform — FERPA.** The platform generates opaque `STU-NNN` codes. The publisher copies those codes and maintains their own offline mapping (Google Sheet, etc.) from `STU-NNN → student NETid`. MyOS never stores, receives, or transmits NETids or any PII that would identify a real student.
- The entity is an **Assessment**, not a course. The word "course" does not apply here.
- No avatar is involved. The grading prompt comes from a backend asset file, not any avatar template.

---

## 1. Real-World Flow

```
Publisher (professor / TA / grading operator)
  └─ Logs into MyOS → Publisher Dashboard → Autograder section
       └─ Creates Assessment: "Math 101 Placement Test"
            ├── optionally uploads per-assessment:
            │       rubric.pdf, solution.pdf, webassign_solution.pdf, grading_prompt
            │   (null → falls back to platform-wide defaults in data/autograder/)
            │
            └─ For each student who handed in work:
                 ├─ Creates ag_student → platform returns STU-007
                 │   Publisher writes "STU-007 → Ahmed Khalil" in their own Google Sheet
                 │   NETid never enters the platform
                 ├─ Opens SSE stream for real-time grading progress
                 ├─ Uploads: Ahmed's handwritten PDF + webassign PDF
                 │   → FallbackProvider grades → score, review_required, result_json stored
                 └─ Repeats for each student

Admin
  └─ Read-only view of all assessments and submissions across all publishers
```

---

## 2. Domain Boundary

### What Autograder reuses from v2

| v2 concept | How Autograder reuses it |
|---|---|
| `users` table + JWT auth | Same JWT — publisher token works as-is |
| Role system | `publisher` creates and operates assessments; `admin` has read-only access |
| `credit_balances` / `usage_records` / `pricing_configs` | Grading billed per submission — `operation_type = 'autograder_submission'` |
| Alembic migrations | Same pipeline; all autograder migrations prefixed `ag_` |
| FastAPI app + router registration | Autograder router is a sibling `include_router` in `main.py` |
| AWS S3 | Submission PDFs stored on S3 |

### What Autograder does NOT reuse

| v2 concept | Reason |
|---|---|
| Subscriber role | Publishers are the only users — no subscriber access |
| `courses` / `sessions` / `session_runs` | Wrong domain — no live teaching session |
| `avatar_subscriptions` / `avatar_variants` | No avatar; prompt is a backend file |
| `avatar_access_codes` | Publisher owns assessments directly |
| `programs` / `program_memberships` | Learning branding layer — not relevant |
| `user_memories` / `slide_chunks` / RAG | No learning loop |
| `AIOrchestrator` | Autograder runs its own `FallbackProvider`; parallel systems |

---

## 3. Database Schema

All tables prefixed `ag_`. No existing v2 tables are modified.

### `ag_assessments`

```sql
id                          UUID         PK
publisher_id                UUID         FK → users NOT NULL
name                        VARCHAR(255) NOT NULL      -- e.g. "Math 101 Placement Test"
description                 TEXT
-- Per-assessment grading asset overrides (all nullable → fall back to platform defaults)
rubric_s3_key               VARCHAR(500)               -- publisher-uploaded rubric PDF
solution_s3_key             VARCHAR(500)               -- solution PDF
webassign_solution_s3_key   VARCHAR(500)               -- webassign solution PDF
grading_prompt              TEXT                       -- prompt override; NULL = use default file
-- State
is_active                   BOOLEAN      NOT NULL DEFAULT TRUE
created_at                  TIMESTAMP    DEFAULT now()
updated_at                  TIMESTAMP    DEFAULT now()
INDEX: (publisher_id)
```

Publishers can upload their own grading assets per assessment, or leave them null to use the
platform-wide defaults in `data/autograder/`. One deployment can serve multiple grading
contexts without a redeployment.

### `ag_students`

External test-takers. **Not MyOS users. No NETid field — ever.**

```sql
id              UUID         PK
assessment_id   UUID         FK → ag_assessments NOT NULL
student_code    VARCHAR(20)  UNIQUE NOT NULL INDEX      -- STU-NNN; platform SQL sequence
display_name    VARCHAR(255)                            -- optional free-text label (e.g. "Seat 12A")
                                                        -- never a real identifier like NETid
created_by      UUID         FK → users NOT NULL        -- the publisher who registered this student
created_at      TIMESTAMP    DEFAULT now()
updated_at      TIMESTAMP    DEFAULT now()
INDEX: (assessment_id)
INDEX: (created_by)
```

> **FERPA design principle:** `student_code` is an opaque platform-generated token. The publisher
> copies it and maintains their own **offline** mapping (`STU-NNN → university NETid`) in a Google
> Sheet or similar tool. MyOS never stores, receives, or transmits NETids or any PII linking
> a code to a real person.

`STU-NNN` codes are **globally unique** across the entire platform (one PostgreSQL sequence,
not per-assessment). If a publisher re-registers the same physical student in a second assessment,
they get a new code — the offline mapping stays unambiguous.

### `ag_submissions`

```sql
id                      UUID           PK   -- also used as S3 path prefix
assessment_id           UUID           FK → ag_assessments NOT NULL
student_id              UUID           FK → ag_students NOT NULL
version_number          INTEGER        NOT NULL    -- 1-based per student; latest = is_active
submitted_by            UUID           FK → users NOT NULL    -- the publisher who uploaded
handwritten_filename    VARCHAR(255)   NOT NULL
handwritten_s3_key      VARCHAR(500)   NOT NULL
webassign_filename      VARCHAR(255)   NOT NULL
webassign_s3_key        VARCHAR(500)   NOT NULL
score                   NUMERIC(5,2)
overall_confidence      NUMERIC(5,2)
review_required         BOOLEAN        NOT NULL DEFAULT FALSE
result_json             JSONB                       -- full GradingResult
is_active               BOOLEAN        NOT NULL DEFAULT TRUE   -- only latest is active
created_at              TIMESTAMP      DEFAULT now()
UNIQUE (student_id, version_number)
INDEX: (assessment_id, is_active)
INDEX: (student_id, is_active)
INDEX: (submitted_by)
```

### Billing integration

Seed one row in `pricing_configs`:

```sql
operation_type            = 'autograder_submission'
cost_per_1k_input_tokens  = <provider-actual>
platform_fee_multiplier   = 1.2
minimum_charge_credits    = 5     -- ~$0.05 per grading run
```

When a submission completes, `GradingService` inserts a `usage_records` row with
`session_run_id = NULL` and the new `operation_type`. No other billing tables change.

---

## 4. Access Control

| Action | Admin | Publisher | Subscriber |
|---|---|---|---|
| Create / edit Assessment | ✗ | ✓ own only | ✗ — 403 |
| View all assessments (platform-wide) | ✓ read-only | ✗ | ✗ |
| Create `ag_student` | ✗ | ✓ own assessments | ✗ |
| Submit PDF for grading | ✗ | ✓ own assessments | ✗ |
| View submissions | ✓ read-only | ✓ own assessments | ✗ |
| Export CSV | ✗ | ✓ | ✗ |

**Publisher isolation:** Every query filters `ag_assessments.publisher_id = current_user.id`.

**Subscriber role:** Has zero access to any autograder route. Any request with a subscriber
JWT to `/api/autograder/*` returns HTTP 403 immediately.

---

## 5. Route Design

All under `/api/autograder/`. Auth: `publisher` or `admin` only.

### Assessment management

| Method | Path | Notes |
|---|---|---|
| `POST` | `/assessments` | Create assessment |
| `GET` | `/assessments` | List own (publisher) or all (admin) |
| `GET` | `/assessments/{id}` | Detail |
| `PATCH` | `/assessments/{id}` | Update name / description / grading assets |
| `DELETE` | `/assessments/{id}` | Soft-delete (`is_active = false`) |

### Student management

| Method | Path | Notes |
|---|---|---|
| `POST` | `/assessments/{id}/students` | Create student → `{ student_code: "STU-007" }` |
| `GET` | `/assessments/{id}/students` | List; `?code=STU-007` lookup |
| `GET` | `/assessments/{id}/students/{student_id}` | Student detail |
| `GET` | `/assessments/{id}/students/{student_id}/submissions` | All versions |
| `GET` | `/assessments/{id}/students/{student_id}/submissions/latest` | Latest active |

### Grading

| Method | Path | Notes |
|---|---|---|
| `GET` | `/grade/events/{request_id}` | SSE stream — **open before POST** |
| `POST` | `/grade` | Multipart: `assessment_id`, `student_id`, `request_id`, handwritten PDF, webassign PDF |

### Submissions

| Method | Path | Notes |
|---|---|---|
| `GET` | `/assessments/{id}/submissions` | All submissions; filters: `student_id`, `review_required`, `all_versions` |
| `GET` | `/submissions/{id}` | Single submission detail + full `result_json` |
| `GET` | `/assessments/{id}/submissions/export` | CSV export (publisher only) |

### Admin

| Method | Path | Notes |
|---|---|---|
| `GET` | `/admin/assessments` | Platform-wide list (admin JWT only) |

---

## 6. Frontend Routes

Same Next.js app, same login, same JWT. Autograder adds a new section in the **publisher
sidebar only**. Subscribers see nothing.

```
/publisher/
    dashboard                                ← unchanged
    avatars/...                              ← unchanged (teaching system)
    autograder/                              ← NEW: hub — assessment list + summary stats
    autograder/assessments/new               ← Create assessment; optionally upload grading assets
    autograder/assessments/[id]/             ← Assessment workspace
        students/                            ← Table of STU-NNN codes; add student button
        grade/                               ← Pick student → upload 2 PDFs → SSE progress panel
        submissions/                         ← Submission log; filter review_required / student
        submissions/[subId]                  ← Full result: score, confidence, result_json viewer
    autograder/assessments/[id]/export       ← CSV download
```

### No avatar or program required

A publisher who only uses Autograder:
- Logs in → Publisher Dashboard → **Autograder** in sidebar
- Never touches Avatar Templates, Variants, Programs, or Courses
- Sidebar conditionally renders Autograder section when `autograder_enabled = true`

Subscribers **never see the Autograder section** — it is not rendered in their sidebar.

---

## 7. Auth: Two New FastAPI Dependencies (No Schema Changes)

```python
async def require_autograder_publisher(
    current_user: User = Depends(get_current_user),
) -> User:
    """Gates every autograder route. Subscriber JWT → 403."""
    if current_user.role not in ("publisher", "admin"):
        raise HTTPException(
            status_code=403,
            detail="Autograder is not available for this account type."
        )
    return current_user


async def require_assessment_owner(
    assessment_id: UUID,
    current_user: User = Depends(require_autograder_publisher),
    db: AsyncSession = Depends(get_db),
) -> AgAssessment:
    """Additionally verifies the publisher owns this specific assessment."""
    assessment = await db.get(AgAssessment, assessment_id)
    if not assessment or not assessment.is_active:
        raise HTTPException(status_code=404)
    if current_user.role == "admin":
        return assessment       # admins can read anything
    if assessment.publisher_id != current_user.id:
        raise HTTPException(status_code=403)
    return assessment
```

No new JWT claims. No new auth tables. Existing `get_current_user` dependency is unchanged.

---

## 8. LLM Pipeline (Unchanged Core Logic)

The `FallbackProvider` chain is kept exactly as-is, with one new wrinkle: **per-assessment
asset resolution** before each grading call.

```python
async def resolve_grading_assets(
    assessment: AgAssessment,
    cache: GeminiFileCache,
) -> tuple[str, str, str, str]:
    """Returns (rubric_uri, solution_uri, webassign_uri, prompt_text)."""
    if assessment.rubric_s3_key:
        rubric_bytes = await s3.download(assessment.rubric_s3_key)
        rubric_uri = await cache.upload_ephemeral(rubric_bytes, "rubric.pdf")
    else:
        rubric_uri = cache.get_uri("rubric.pdf")    # pre-warmed at startup

    # same pattern for solution and webassign_solution ...

    prompt = (
        assessment.grading_prompt
        or Path("data/autograder/grading_prompt.txt").read_text()
    )
    return rubric_uri, solution_uri, webassign_uri, prompt
```

Provider chain (unchanged):
1. OpenAI `gpt-4.1` — all 5 PDFs inline base64, max 2 attempts
2. Gemini Pro `gemini-2.5-pro` — static PDFs via cached Files API URIs, max 2 attempts
3. Gemini Flash `gemini-2.0-flash` — URI cache or inline fallback, max 1 attempt
4. Gemini Free `gemini-2.5-pro` — same rule as Flash, max 1 attempt

`RetryableError` (429/5xx/timeout) → retry up to `max_attempts`, skip provider.
`FatalError` → skip immediately.

---

## 9. Startup

Platform-wide defaults pre-warmed at server start when `autograder_enabled = true`.
Per-assessment override assets are uploaded on-demand and cached for the Gemini Files API TTL.

```python
async def autograder_startup():
    for fname in ["grading_prompt.txt", "rubric.pdf", "solution.pdf", "webassign_solution.pdf"]:
        if not Path(f"data/autograder/{fname}").exists():
            raise RuntimeError(f"Missing autograder asset: {fname}")
    await GeminiFileCache.warm_defaults()   # uploads to Gemini Files API; crash on failure
    FallbackProvider.initialize()
```

---

## 10. Module Layout

```
app/
├── api/autograder/
│   ├── router.py           ← mounts sub-routers; prefix="/api/autograder"
│   ├── assessments.py      ← assessment CRUD routes
│   ├── students.py         ← student management routes
│   ├── grade.py            ← POST /grade + GET /grade/events/{request_id}
│   ├── submissions.py      ← submission read + export routes
│   └── admin.py            ← admin-only platform-wide reads
│
├── autograder/
│   ├── models.py           ← AgAssessment, AgStudent, AgSubmission (SQLAlchemy)
│   ├── schemas.py          ← Pydantic I/O models
│   ├── assessment_service.py
│   ├── student_service.py  ← STU-NNN sequence generation
│   ├── grading_service.py  ← orchestrates FallbackProvider + DB write + billing debit
│   ├── event_bus.py        ← in-memory SSE queues (request_id → asyncio.Queue, 600s TTL)
│   ├── startup.py          ← asset verification + Gemini cache warm
│   └── llm/
│       ├── base.py         ← LLMProvider ABC, StudentFiles, GradingResult dataclasses
│       ├── errors.py       ← RetryableError, FatalError
│       ├── fallback.py     ← FallbackProvider orchestrator + lazy singleton
│       ├── gemini.py       ← GeminiProvider (Pro / Flash / Free tiers)
│       └── openai.py       ← OpenAIGradingProvider (name distinct from v2 OpenAIProvider)
│
├── services/
│   ├── autograder_cache.py ← Gemini Files API cache (warm + 404-triggered refresh)
│   └── autograder_files.py ← PDF validation + pdf2image + LibreOffice conversion
│
└── data/autograder/
    ├── grading_prompt.txt
    ├── rubric.pdf
    ├── solution.pdf
    ├── webassign_solution.pdf
    └── autograder_cache.json
```

---

## 11. Alembic Migrations (Additive Only)

1. `ag_sequence` — PostgreSQL sequence `ag_student_code_seq`
2. `ag_tables` — `ag_assessments`, `ag_students`, `ag_submissions`
3. `ag_pricing` — seed `pricing_configs` row for `operation_type = 'autograder_submission'`

No existing v2 tables are modified.

---

## 12. Deployment Checklist

- [ ] Copy `data/autograder/{grading_prompt.txt, rubric.pdf, solution.pdf, webassign_solution.pdf}` to VPS
- [ ] Set env vars: `AUTOGRADER_ENABLED=true`, `GEMINI_PRO_API_KEY`, `OPENAI_API_KEY`
- [ ] Run Alembic: `ag_sequence` → `ag_tables` → `ag_pricing`
- [ ] Verify startup logs: "Gemini cache warmed successfully"
- [ ] Smoke test: create assessment → create student → POST `/grade` with sample PDFs

---

## 13. Final Decision Table

| Question | Decision |
|---|---|
| Separate domain or inside Avatar/Session? | Separate — parallel sibling module |
| Top-level entity | `ag_assessments` — not courses, not sessions |
| Who creates and operates assessments? | **Publisher only** |
| Subscriber role in autograder? | **None** — HTTP 403 on all autograder routes |
| `ag_assessment_operators` enrollment table? | **Gone** — not needed |
| Can a publisher skip avatars/programs? | Yes — autograder is fully independent |
| External students as MyOS users? | No — `ag_students` with `STU-NNN` codes only |
| NETids stored on platform? | **Never** — FERPA. Publisher maps offline |
| Avatar or template prompt used? | No — backend file, per-assessment override or platform default |
| Auth changes needed? | None — same JWT; two new FastAPI dependencies |
| File storage | S3 |
| `FallbackProvider` and `AIOrchestrator` | Parallel, not merged |
| Billing | `usage_records` with `operation_type = 'autograder_submission'` |
| Frontend | Same app, same login — Autograder section in publisher sidebar only |
