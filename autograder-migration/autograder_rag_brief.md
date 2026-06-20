# Autograder RAG — AI Engineer Brief
**Scope:** Only the AI/LLM layer — `app/autograder/llm/rag/` and the `GradingContextBuilder`.  


---

## 1. Why RAG for Autograding?

The current system passes all three reference PDFs (rubric, solution, webassign_solution) inline to
the LLM on every call. For a short problem set this works. It breaks down in three ways:

1. **Token budget.** A full solution PDF for a math exam can run 20–50 pages. Inline base64 of five
   PDFs eats most of a model's context window before the student's work is even included.
2. **Grading precision.** Asking the LLM to grade question 3 while it also has to read all 40 pages
   of a full solution manual degrades accuracy. The model needs to see *only the relevant reference
   material for the question it is grading*.
3. **Mathematics.** Math grading requires aligning the student's work on question N against the
   rubric criteria for question N and the solution steps for question N — not the full document.
   Mis-alignment is a hallucination surface.

RAG solves all three by chunking the reference documents **by question** at ingestion time,
embedding those chunks, and at grading time retrieving only the chunks relevant to what the
student actually wrote. The LLM prompt becomes precise and short.

---

## 2. What You Own

```
app/autograder/llm/rag/
├── __init__.py
├── ingestion.py          ← process reference PDFs → chunks → embeddings → DB
├── extraction.py         ← vision-based question/math extraction from any PDF
├── embedding.py          ← embedding calls + caching wrapper
├── retrieval.py          ← vector search against ag_rag_chunks
├── context_builder.py    ← GradingContextBuilder — the main integration point
└── math_utils.py         ← LaTeX normalisation, equation detection helpers
```

The only file outside this directory that you write to is a thin change in
`app/autograder/llm/fallback.py` — one call to `GradingContextBuilder` before each provider
invocation. The backend engineer handles the DB table, migration, and S3 download.

---

## 3. System Overview

```
── INGESTION (runs once when publisher uploads / updates reference PDFs) ──────────────────

  rubric.pdf                  ┐
  solution.pdf                ├─→ extraction.py (GPT-4.1 Vision)
  webassign_solution.pdf      ┘       │
                                      │ structured chunks per question:
                                      │   { question_number, question_text,
                                      │     content_text, math_latex[], doc_type }
                                      ▼
                              embedding.py (text-embedding-3-small)
                                      │
                                      ▼
                              pgvector  →  ag_rag_chunks table

── GRADING (runs per student submission) ──────────────────────────────────────────────────

  handwritten.pdf  ─→ extraction.py (GPT-4.1 Vision)
  webassign.pdf    ─→        │
                             │ identified questions + student work text
                             ▼
                    retrieval.py
                             │ cosine search against ag_rag_chunks
                             │ returns top-k chunks per question:
                             │   rubric criteria + solution steps + webassign context
                             ▼
                    context_builder.py  →  GradingContext object
                             │
                             ▼
                    FallbackProvider (unchanged internally)
                       provider.grade(student_files, grading_context)
```

---

## 4. DB Table You Will Read/Write

The backend engineer creates and migrates this table. You only need to know its shape:

```sql
-- ag_rag_chunks
id               UUID         PK
assessment_id    UUID         FK → ag_assessments NOT NULL
doc_type         VARCHAR(30)  NOT NULL   -- 'rubric' | 'solution' | 'webassign_solution'
question_number  INTEGER                 -- NULL if chunk is a preamble / general section
question_label   VARCHAR(50)            -- e.g. "Q3b", "Part II" — from doc structure
content_text     TEXT         NOT NULL   -- human-readable text of this chunk
math_latex       JSONB                   -- list of LaTeX strings extracted from the chunk
embedding        Vector(1536) NOT NULL   -- text-embedding-3-small output
created_at       TIMESTAMP    DEFAULT now()

INDEX: ivfflat on embedding (vector_cosine_ops)
INDEX: (assessment_id, doc_type)
INDEX: (assessment_id, question_number)
```

The `math_latex` column stores extracted equations as a list so they survive embedding faithfully.
The `content_text` that gets embedded includes the equations rendered in words/LaTeX inline.

---

## 5. Ingestion Pipeline (`ingestion.py`)

### When it runs

Triggered by the backend service when a publisher uploads or updates reference PDFs for an
assessment. You expose one async function; the backend calls it:

```python
async def ingest_assessment_documents(
    assessment_id: UUID,
    rubric_bytes: bytes,
    solution_bytes: bytes,
    webassign_bytes: bytes,
    db: AsyncSession,
) -> None:
    """
    Full ingestion pipeline. Idempotent — deletes existing chunks for this
    assessment before re-inserting. Call this on first upload and on any
    replacement of reference PDFs.
    """
```

### Step 1 — Extract structured chunks from each PDF

Call `extraction.py` for each document. The extraction step is a **vision model call** because
math content in PDFs cannot be reliably extracted with text parsers.

```python
# extraction.py
async def extract_question_chunks(
    pdf_bytes: bytes,
    doc_type: str,          # 'rubric' | 'solution' | 'webassign_solution'
    model: str = "gpt-4.1",
) -> list[QuestionChunk]:
    """
    Converts PDF → images (pdf2image, 150 DPI), sends to vision model with a
    structured extraction prompt, returns one QuestionChunk per question/section.
    """
```

**Extraction prompt design (for reference PDFs):**

```
You are extracting structured grading reference material from a {doc_type} document.

For each question or sub-question you find:
  - Extract the question number / label exactly as written (e.g. "3", "3b", "Part II Q1")
  - Extract the full content: criteria, point values, solution steps, or constraints
  - Identify all mathematical expressions and render them in LaTeX
  - If a section is a preamble (applies to all questions), set question_number = null

Return a JSON array:
[
  {
    "question_number": 3,
    "question_label": "3b",
    "content_text": "Solve the integral ... using integration by parts. [3 pts]",
    "math_latex": ["\\int_0^1 x e^x dx", "= [xe^x - e^x]_0^1 = 1"]
  },
  ...
]

Be exhaustive. Do not skip partial credit criteria or intermediate steps.
```

**Key constraint:** Each page image is sent as a group for context. Do not split single questions
across separate vision calls — the model needs to see multi-line equations intact.

### Step 2 — Build embeddable text per chunk

Raw LaTeX in isolation embeds poorly. Convert each chunk to a rich natural-language + LaTeX
representation before embedding:

```python
# math_utils.py
def build_embed_text(chunk: QuestionChunk) -> str:
    """
    Combines content_text with math context for better embedding.
    LaTeX is kept inline using $ delimiters so the embedding model
    sees the symbolic structure.
    """
    parts = [f"[{chunk.doc_type.upper()} | Question {chunk.question_label}]"]
    parts.append(chunk.content_text)
    if chunk.math_latex:
        parts.append("Mathematical expressions: " + "  ".join(
            f"${eq}$" for eq in chunk.math_latex
        ))
    return "\n".join(parts)
```

### Step 3 — Embed and persist

```python
# embedding.py
async def embed_text(text: str) -> list[float]:
    """Calls OpenAI text-embedding-3-small. Returns 1536-dim vector."""

async def embed_batch(texts: list[str]) -> list[list[float]]:
    """Batches up to 100 texts per API call. Handles rate limits with exponential backoff."""
```

Persist each chunk to `ag_rag_chunks`. Delete existing chunks for the assessment first
(idempotent replacement on re-upload).

---

## 6. Student Submission Extraction (`extraction.py`)

Before retrieval can happen, you need to know which questions the student answered and
what they wrote. This is a **separate vision call** on the student's PDFs.

```python
async def extract_student_work(
    handwritten_bytes: bytes,
    webassign_bytes: bytes,
    model: str = "gpt-4.1",
) -> list[StudentAnswerChunk]:
    """
    Processes the student's two PDFs and returns one chunk per answered question.
    Handwritten math is described in LaTeX where possible.
    """
```

**Student extraction prompt:**

```
You are reading a student's submitted work. The student has answered math problems.

For each question or sub-question you can identify:
  - Extract the question number / label as written or inferred from position
  - Describe what the student wrote: their approach, steps taken, final answer
  - For any mathematical expression, render it in LaTeX
  - Note if the answer appears blank, illegible, or incomplete

Return a JSON array:
[
  {
    "question_number": 3,
    "question_label": "3b",
    "student_work_text": "Student wrote: let u = x, dv = e^x dx ...",
    "math_latex": ["u = x", "dv = e^x dx", "\\int x e^x dx = xe^x - e^x + C"],
    "appears_blank": false,
    "appears_illegible": false
  },
  ...
]

If handwriting is unclear, make your best effort and set a note in student_work_text.
Do not invent content that is not present on the page.
```

> **Why two documents?** The webassign PDF shows the typed problem statement and any
> computer-entry work. The handwritten PDF shows scratch work and final answers. Together
> they give a complete picture. Some students write final answers on webassign and work on
> the handwritten sheet — both must be considered.

---

## 7. Retrieval Pipeline (`retrieval.py`)

For each `StudentAnswerChunk`, retrieve the most relevant rubric, solution, and webassign
reference chunks.

```python
async def retrieve_for_question(
    assessment_id: UUID,
    student_chunk: StudentAnswerChunk,
    db: AsyncSession,
    top_k_per_doc_type: int = 3,
) -> RetrievedContext:
    """
    1. Build a retrieval query from the student's work text + math.
    2. Run cosine similarity search against ag_rag_chunks filtered by assessment_id.
    3. Return top_k matches per doc_type (rubric, solution, webassign_solution).
    """
```

### Retrieval query formulation

Do NOT embed just the question number — the embedding model has no concept of "question 3."
Build a query from the student's actual work:

```python
def build_retrieval_query(student_chunk: StudentAnswerChunk) -> str:
    parts = [f"Question {student_chunk.question_label}"]
    parts.append(student_chunk.student_work_text)
    if student_chunk.math_latex:
        parts.append("Math: " + "  ".join(f"${eq}$" for eq in student_chunk.math_latex[:5]))
    return "\n".join(parts)
```

### Exact question-number pre-filter

Before vector search, attempt an **exact match** on `question_number`:

```python
# Prefer exact question_number match first
exact_chunks = await db.scalars(
    select(AgRagChunk)
    .where(AgRagChunk.assessment_id == assessment_id)
    .where(AgRagChunk.question_number == student_chunk.question_number)
    .order_by(AgRagChunk.doc_type)  # get one per doc type
)
```

If exact chunks are found for all three doc types, skip vector search for this question —
exact is always better than semantic for numbered questions. Use vector search as the
fallback when `question_number` is NULL or the question label format differs.

### Vector search (pgvector)

```sql
SELECT id, doc_type, question_label, content_text, math_latex,
       1 - (embedding <=> :query_embedding) AS similarity
FROM ag_rag_chunks
WHERE assessment_id = :assessment_id
ORDER BY embedding <=> :query_embedding
LIMIT :top_k;
```

Run one query per `doc_type` so you always get at least one rubric chunk, one solution chunk,
and one webassign chunk — even if they aren't the three most similar overall.

---

## 8. Context Assembly (`context_builder.py`)

This is the integration point. It produces a `GradingContext` object that the
`FallbackProvider` injects into each provider's grading call.

```python
@dataclass
class RetrievedChunk:
    doc_type: str           # 'rubric' | 'solution' | 'webassign_solution'
    question_label: str
    content_text: str
    math_latex: list[str]
    similarity: float

@dataclass
class QuestionContext:
    question_label: str
    student_work: StudentAnswerChunk
    rubric_chunks: list[RetrievedChunk]
    solution_chunks: list[RetrievedChunk]
    webassign_chunks: list[RetrievedChunk]

@dataclass
class GradingContext:
    assessment_name: str
    grading_prompt: str             # from assessment or platform default
    questions: list[QuestionContext]
    total_questions: int

    def to_prompt_block(self) -> str:
        """
        Renders the full structured context block that gets injected
        into the LLM system prompt before the student files.
        """
```

### Prompt block format

The rendered context block passed to the LLM looks like this:

```
=== GRADING REFERENCE CONTEXT ===

Assessment: Math 101 Placement Test
Total questions identified: 5

--- Question 3b ---

[RUBRIC]
Integration by parts. Award 1 pt for correct u/dv selection, 2 pts for correct
integration steps, 1 pt for correct evaluation of bounds, 1 pt for final answer.
Partial credit: deduct 1 pt per arithmetic error if method is correct.
Math: $u = x$, $dv = e^x dx$, $du = dx$, $v = e^x$

[SOLUTION]
$\int_0^1 x e^x dx = [xe^x - e^x]_0^1 = (e - e) - (0 - 1) = 1$
Step 1: Identify u and dv ...
Step 2: Apply integration by parts formula ...

[WEBASSIGN REFERENCE]
Problem 3b: Evaluate $\int_0^1 x e^x dx$ using integration by parts. [5 pts]

[STUDENT WORK]
Student wrote: let u=x, dv=e^x dx ... arrived at final answer 1. Shows all steps.
Math: $\int x e^x dx = xe^x - e^x + C$, evaluated as $[xe^x-e^x]_0^1 = 1$

--- Question 4 ---
...

=== END REFERENCE CONTEXT ===
```

This block replaces the raw PDF inline base64 for the reference documents. The student files
(handwritten + webassign PDFs) are **still passed as vision inputs** — the LLM needs to see
the actual handwriting for confidence scoring and illegibility detection.

---

## 9. Integration with FallbackProvider

The only change to `fallback.py`:

```python
# In FallbackProvider.grade() — BEFORE the provider loop
from app.autograder.llm.rag.context_builder import GradingContextBuilder

async def grade(
    self,
    student_files: StudentFiles,
    assessment: AgAssessment,
    db: AsyncSession,
) -> GradingResult:

    # Build RAG context (new)
    builder = GradingContextBuilder(db)
    grading_context = await builder.build(assessment, student_files)

    # Pass context into each provider attempt (new parameter)
    for provider in self.providers:
        try:
            result = await provider.grade(student_files, grading_context)
            ...
```

Each `LLMProvider.grade()` method gains a `grading_context: GradingContext` parameter.
The base class (`base.py`) is updated to include it in the abstract method signature.
All three providers (OpenAI, Gemini, GeminiFree) inject `grading_context.to_prompt_block()`
into their system prompt instead of passing the raw reference PDF bytes for the rubric/solution.
The student PDFs (handwritten + webassign) continue to be passed as vision inputs.

---

## 10. Math-Specific Considerations

### 10.1 Handwritten math is the hardest part

Handwritten equations are the primary failure mode. Mitigations:

| Problem | Mitigation |
|---|---|
| Student's handwriting unreadable | Flag `appears_illegible = true` in extraction; LLM is instructed to note this in `review_required` reasons |
| Student uses non-standard notation | Extraction prompt asks the model to normalise to standard LaTeX; similarity search still works because the rubric also went through the same normalisation |
| Crossed-out work included in extraction | Prompt explicitly says: "If the student crossed out work, exclude it from the extracted steps but note that a correction was made" |
| Multi-line derivation spanning page boundary | `pdf2image` renders full pages; sent as ordered image list with page numbers visible in the extraction prompt |

### 10.2 Embedding quality for math

`text-embedding-3-small` was trained on general text. Math symbols in isolation
(e.g. `∫`, `Σ`, `∂`) embed poorly. Compensate by:

1. **Always rendering math as LaTeX** (`$...$`) inside `content_text`, not as Unicode symbols.
   LaTeX strings (`\int`, `\sum`, `\partial`) embed better than their Unicode equivalents.
2. **Prepending a natural-language description** to each math-heavy chunk before embedding:
   `"Definite integral from 0 to 1 of x times e to the x"` in addition to the LaTeX.
3. **Not relying on embedding alone for numbered questions** — the exact question-number
   pre-filter (§7) handles the common case; vector search is the fallback.

If embedding quality proves insufficient for a specific domain (e.g. physics with heavy
notation), a math-aware embedding model (e.g. **Mathstral** via Mistral API, or
**MathBERT** via HuggingFace) can be swapped into `embedding.py` without changing anything
else in the pipeline.

### 10.3 Step-by-step grading alignment

Math is graded step-by-step. The retrieved solution chunk must include intermediate steps,
not just the final answer. The extraction prompt for solution PDFs explicitly requests
"all intermediate derivation steps" per question.

The grading prompt (injected as the first instruction to the LLM) must say:

```
Grade each question step-by-step against the rubric criteria:
1. Identify the student's method (correct / partially correct / incorrect)
2. Check each derivation step against the solution steps provided
3. Apply partial credit per the rubric point breakdown
4. For the final answer: accept equivalent forms (e.g. 1 and e^0 are the same)
5. If the student's answer is mathematically equivalent but in a different form,
   verify symbolically before deducting points
```

### 10.4 Equivalent-form detection

A student who writes `1` and a student who writes `e - e + 1` both answered correctly.
The LLM must be explicitly instructed to recognise symbolic equivalence. This is a prompt
engineering task, not a code task — but the grading prompt template in
`data/autograder/grading_prompt.txt` must include this instruction.

---

## 11. Fallback: RAG Unavailable

If the `ag_rag_chunks` table has no rows for an assessment (e.g. ingestion has not run yet,
or it failed), `GradingContextBuilder.build()` falls back gracefully:

```python
async def build(self, assessment, student_files) -> GradingContext:
    chunks = await self._load_chunks(assessment.id)
    if not chunks:
        # RAG not yet available; return a minimal context
        # FallbackProvider will pass reference PDFs inline (old behaviour)
        return GradingContext.no_rag(assessment)
```

`GradingContext.no_rag()` returns a context with `questions = []` and a flag
`rag_available = False`. Each provider checks this flag and, if false, falls back to
the original inline base64 approach for the reference documents. This ensures backward
compatibility while RAG is being set up.

---

## 12. File Layout (Your Work Only)

```
app/autograder/llm/rag/
├── __init__.py
│
├── ingestion.py
│   └── ingest_assessment_documents(assessment_id, rubric_bytes, solution_bytes,
│                                    webassign_bytes, db) → None
│
├── extraction.py
│   ├── extract_question_chunks(pdf_bytes, doc_type, model) → list[QuestionChunk]
│   └── extract_student_work(handwritten_bytes, webassign_bytes, model) → list[StudentAnswerChunk]
│
├── embedding.py
│   ├── embed_text(text) → list[float]
│   └── embed_batch(texts) → list[list[float]]
│
├── retrieval.py
│   └── retrieve_for_question(assessment_id, student_chunk, db,
│                              top_k_per_doc_type) → RetrievedContext
│
├── context_builder.py
│   ├── GradingContextBuilder.build(assessment, student_files) → GradingContext
│   ├── GradingContext.to_prompt_block() → str
│   └── GradingContext.no_rag(assessment) → GradingContext   [fallback]
│
└── math_utils.py
    ├── build_embed_text(chunk) → str
    └── build_retrieval_query(student_chunk) → str
```

**One-line change** in `app/autograder/llm/fallback.py` — call `GradingContextBuilder.build()`
before the provider loop and pass the result to each `provider.grade()`.

**One-signature change** in `app/autograder/llm/base.py` — add `grading_context: GradingContext`
to `LLMProvider.grade()` abstract method.

---

## 13. What You Do NOT Touch

| Area | Owner |
|---|---|
| FastAPI routes (`app/api/autograder/`) | Backend engineer |
| DB migration for `ag_rag_chunks` | Backend engineer (you provide the table spec from §4) |
| S3 upload of reference PDFs | Backend engineer |
| `FallbackProvider` retry/skip logic | Existing (do not change) |
| SSE `EventBus` | Existing (do not change) |
| `ag_assessments`, `ag_students`, `ag_submissions` ORM models | Backend engineer |
| Billing / `usage_records` | Backend engineer |
| Frontend | Frontend engineer |

---

## 14. Deliverables Checklist

- [ ] `extraction.py` — vision extraction for reference PDFs and student PDFs
- [ ] `math_utils.py` — `build_embed_text()`, `build_retrieval_query()`, LaTeX helpers
- [ ] `embedding.py` — `embed_text()`, `embed_batch()` with rate-limit handling
- [ ] `ingestion.py` — `ingest_assessment_documents()` end-to-end
- [ ] `retrieval.py` — exact + vector retrieval with per-doc-type top-k
- [ ] `context_builder.py` — `GradingContextBuilder`, `GradingContext`, `to_prompt_block()`, `no_rag()` fallback
- [ ] Update `base.py` — add `grading_context` parameter to `LLMProvider.grade()`
- [ ] Update `fallback.py` — single call to `GradingContextBuilder.build()` before provider loop
- [ ] Update `gemini.py`, `openai.py` — inject `grading_context.to_prompt_block()` into system prompt; honour `rag_available` flag for inline-PDF fallback
- [ ] Unit tests for: extraction output parsing, `build_embed_text`, `build_retrieval_query`, `to_prompt_block`, `no_rag` fallback path
- [ ] Integration test: full pipeline from raw PDF bytes → `GradingContext` → prompt block

---

## 15. Environment Variables You Need

These are already in the v2 `Settings` class. You should not add new ones unless necessary.

| Variable | Used for |
|---|---|
| `OPENAI_API_KEY` | Extraction vision calls + `text-embedding-3-small` |
| `GEMINI_PRO_API_KEY` | Extraction fallback if OpenAI vision fails |
| `OPENAI_GRADING_MODEL` (`gpt-4.1`) | Vision extraction model |
| Database connection | pgvector queries via SQLAlchemy `AsyncSession` |

If you need to swap to a math-aware embedding model, add:

```python
# app/config.py (ask backend engineer to add)
autograder_embedding_model: str = "text-embedding-3-small"   # override for testing
```
