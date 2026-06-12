# ProfSidekick — UML Implementation Diagrams

All diagrams use [Mermaid](https://mermaid.js.org/) syntax and render natively in VS Code (with the Markdown Preview Mermaid Support extension), GitHub, and most modern markdown viewers.

---

## 1. System Component Architecture

```mermaid
graph TB
    subgraph Browser["Browser (User)"]
        UI["React 19 UI"]
    end

    subgraph Cloudflare["Cloudflare"]
        CF["DNS + DDoS + SSL Proxy"]
    end

    subgraph Vercel["Vercel — Next.js 15 Frontend"]
        direction TB
        Pages["App Router Pages\n(auth), (dashboard)"]
        BFF["BFF API Routes\n/app/api/**"]
        AuthCtx["AuthContext\nJWT + localStorage"]
        Hooks["Custom Hooks\nuseBilling, useCourses,\nuseProfessorPersona, useAvatars"]
        Comps["Components\nTeachingInterface\nClassCreation\nNavigationHeader\nTranscript"]
    end

    subgraph Contabo["Contabo VPS — Ubuntu"]
        direction TB
        FastAPI["FastAPI + uvicorn\nbackend-main"]

        subgraph Services["app/services/"]
            AuthSvc["auth_service"]
            BillSvc["billing_service"]
            RAGSvc["rag_service ★"]
            MemSvc["memory_service ★"]
            OpenAISvc["openai_service"]
            FileSvc["file_processor"]
        end

        subgraph APIs["app/api/"]
            AuthAPI["auth/api.py"]
            SessionAPI["sessions/api.py"]
            BillingAPI["billing/api.py"]
            AdminAPI["admin/billing_api.py"]
            WebhookWix["webhooks/wix.py"]
            WebhookStripe["webhooks/stripe.py ★"]
            AvatarAPI["avatars/api.py ★"]
            PersonaAPI["professor/persona/api.py ★"]
            MemoryAPI["memory/api.py ★"]
        end

        PG[("PostgreSQL\n+ pgvector ★")]
        Redis[("Redis\nSession cache")]
    end

    subgraph Cloudflare["Cloudflare"]
        R2["R2 Bucket\nSlides, PDFs, PPTX\n(SSE-KMS ★)"]
        CF_CDN["Cloudflare CDN\n(optional)"]
    end

    subgraph OpenAI["OpenAI API"]
        Vision["Vision API"]
        Chat["Chat Completions"]
        Realtime["Realtime API\nWebRTC"]
        Embed["Embeddings\ntext-embedding-3-small ★"]
    end

    subgraph Wix["Wix"]
        WixStore["Wix Store"]
        WixAuto["Wix Automation\n(Velo code)"]
    end

    subgraph Stripe["Stripe ★"]
        StripeCheckout["Stripe Checkout"]
        StripeWebhook["Stripe Webhooks"]
    end

    UI --> CF --> Vercel
    Pages --> BFF
    Comps --> Hooks --> AuthCtx
    BFF -->|"HTTPS REST"| FastAPI
    FastAPI --> Services
    FastAPI --> APIs
    Services --> PG
    Services --> Redis
    Services --> R2
    Services --> OpenAI
    WixAuto -->|"POST /api/webhooks/wix-payment"| FastAPI
    StripeWebhook -->|"POST /api/webhooks/stripe ★"| FastAPI
    R2 --> CF_CDN

    classDef new fill:#d4edda,stroke:#28a745,color:#000
    classDef existing fill:#cce5ff,stroke:#004085,color:#000
    class RAGSvc,MemSvc,WebhookStripe,AvatarAPI,PersonaAPI,MemoryAPI,Embed,Stripe,StripeCheckout,StripeWebhook new
```

> **Legend:** Green = new (to be built) · Blue = existing

---

## 2. Full Database Entity-Relationship Diagram

```mermaid
erDiagram

    %% ── Existing models ──────────────────────────────────────────

    USER {
        uuid id PK
        string username
        string email
        string password_hash
        string first_name
        string last_name
        string role
        bool email_verified
        bool is_approved
        bool is_deleted
        datetime gdpr_consent_at
        bool marketing_emails_opt_in
        datetime deleted_at
        datetime created_at
    }

    COURSE {
        uuid id PK
        uuid user_id FK
        string course_id
        string name
        string code
        bool is_active
    }

    SESSION {
        uuid id PK
        uuid user_id FK
        uuid course_id FK
        string session_id
        jsonb assistant_parameters
        jsonb slides_details
        jsonb presentation_details
        datetime created_at
    }

    SESSION_RUN {
        uuid id PK
        uuid user_id FK
        uuid session_id FK
        string session_run_id
        string status
        datetime start_time
        datetime end_time
    }

    CREDIT_BALANCE {
        uuid id PK
        uuid user_id FK
        numeric balance_credits
        datetime updated_at
    }

    ACCESS_CODE {
        uuid id PK
        string code
        numeric total_credits
        numeric remaining_credits
        string issued_by
        int max_redemptions
        bool is_active
    }

    ACCESS_CODE_REDEMPTION {
        uuid id PK
        uuid user_id FK
        uuid access_code_id FK
        datetime redeemed_at
    }

    USAGE_RECORD {
        uuid id PK
        uuid user_id FK
        uuid session_run_id FK
        string operation_type
        numeric credits_charged
        string funded_by
        datetime created_at
    }

    PROCESSED_WIX_ORDER {
        uuid id PK
        string wix_order_id
        uuid user_id FK
        numeric credits_added
        datetime processed_at
    }

    %% ── Phase 1: Avatar & Persona ────────────────────────────────

    AVATAR {
        uuid id PK
        string name
        string thumbnail_url
        string voice_id
        string default_persona_hint
        bool is_active
    }

    PROFESSOR_PERSONA {
        uuid id PK
        uuid professor_id FK
        uuid avatar_id FK
        jsonb preference_selections
        text refined_prompt
        bool post_session_quiz_enabled
        datetime created_at
        datetime updated_at
    }

    %% ── Phase 1: RAG ─────────────────────────────────────────────

    SLIDE_CHUNK {
        uuid id PK
        uuid session_id FK
        int slide_number
        int chunk_index
        text content
        vector embedding
        datetime created_at
    }

    KNOWLEDGE_CHUNK {
        uuid id PK
        uuid session_id FK
        string source
        text content
        vector embedding
        datetime created_at
    }

    %% ── Phase 2: Memory & Quiz ───────────────────────────────────

    STUDENT_MEMORY {
        uuid id PK
        uuid student_id FK
        uuid session_run_id FK
        uuid course_id FK
        text summary_text
        vector embedding
        jsonb key_topics
        datetime created_at
    }

    SESSION_QUIZ_RESULT {
        uuid id PK
        uuid session_run_id FK
        uuid student_id FK
        jsonb questions
        jsonb answers
        datetime created_at
    }

    %% ── Phase 2: Feedback ────────────────────────────────────────

    SESSION_FEEDBACK {
        uuid id PK
        uuid session_run_id FK
        uuid user_id FK
        int rating
        text comment
        datetime created_at
    }

    TRANSCRIPT_FEEDBACK {
        uuid id PK
        uuid session_run_id FK
        uuid user_id FK
        int message_index
        string feedback_type
        datetime created_at
    }

    SESSION_CONFUSION_LOG {
        uuid id PK
        uuid session_run_id FK
        uuid student_id FK
        string topic
        datetime created_at
    }

    %% ── Phase 3: Stripe ──────────────────────────────────────────

    STRIPE_SUBSCRIPTION {
        uuid id PK
        uuid user_id FK
        string stripe_customer_id
        string stripe_subscription_id
        string plan
        string status
        datetime current_period_end
        bool cancel_at_period_end
        datetime created_at
    }

    STRIPE_INVOICE {
        uuid id PK
        uuid subscription_id FK
        string stripe_invoice_id
        numeric amount_paid_usd
        numeric credits_granted
        datetime created_at
    }

    %% ── Relationships ────────────────────────────────────────────

    USER ||--o{ COURSE : "creates"
    USER ||--o{ SESSION : "owns"
    USER ||--o{ SESSION_RUN : "runs"
    USER ||--|| CREDIT_BALANCE : "has"
    USER ||--o{ ACCESS_CODE_REDEMPTION : "redeems"
    USER ||--o{ USAGE_RECORD : "incurs"
    USER ||--o{ PROCESSED_WIX_ORDER : "linked to"
    USER ||--o| PROFESSOR_PERSONA : "defines"
    USER ||--o{ STUDENT_MEMORY : "accumulates"
    USER ||--o| STRIPE_SUBSCRIPTION : "subscribes"

    COURSE ||--o{ SESSION : "contains"

    SESSION ||--o{ SESSION_RUN : "spawns"
    SESSION ||--o{ SLIDE_CHUNK : "has chunks"
    SESSION ||--o{ KNOWLEDGE_CHUNK : "has knowledge"

    SESSION_RUN ||--o{ USAGE_RECORD : "generates"
    SESSION_RUN ||--o| SESSION_QUIZ_RESULT : "produces"
    SESSION_RUN ||--o| SESSION_FEEDBACK : "rated by"
    SESSION_RUN ||--o{ TRANSCRIPT_FEEDBACK : "flagged in"
    SESSION_RUN ||--o{ SESSION_CONFUSION_LOG : "logs"
    SESSION_RUN ||--o| STUDENT_MEMORY : "summarised as"

    ACCESS_CODE ||--o{ ACCESS_CODE_REDEMPTION : "redeemed via"

    AVATAR ||--o{ PROFESSOR_PERSONA : "base for"

    STRIPE_SUBSCRIPTION ||--o{ STRIPE_INVOICE : "billed as"
```

---

## 3. Frontend Component Hierarchy

```mermaid
graph TD
    subgraph Layout["app/layout.tsx — Root Providers"]
        AuthProvider["AuthProvider\n(AuthContext)"]
        TranscriptProvider["TranscriptProvider"]
        EventProvider["EventProvider"]
    end

    subgraph AuthGroup["(auth) route group"]
        Login["login/page.tsx"]
        Register["register/page.tsx"]
        VerifyEmail["verify-email/page.tsx"]
        ApproveUser["approve-user/page.tsx"]
    end

    subgraph DashGroup["(dashboard) route group"]
        Dashboard["dashboard/page.tsx"]

        subgraph CoursesFlow["courses/"]
            CourseList["[courseId]/page.tsx"]
            CourseSettings["[courseId]/settings/page.tsx"]
            CourseStudents["[courseId]/students/page.tsx"]
            SessionPage["[courseId]/sessions/[sessionId]/page.tsx"]
            RunPage["sessions/[sessionId]/run/[runId]/page.tsx"]
            KnowledgePage["sessions/[sessionId]/knowledge-capture/page.tsx ★"]
        end

        subgraph BillingFlow["billing/"]
            BillingBalance["balance"]
            BillingRedeem["redeem/page.tsx"]
            BillingUsage["usage/page.tsx"]
            BillingSubscription["subscription/page.tsx ★"]
        end

        subgraph ProfessorFlow["professor/ ★"]
            PersonaSetup["persona/page.tsx ★"]
            Analytics["analytics/page.tsx ★"]
        end

        Profile["profile/page.tsx"]
        Privacy["profile/privacy/page.tsx ★"]
    end

    subgraph SharedComponents["components/"]
        subgraph Layout2["layout/"]
            NavHeader["NavigationHeader.tsx\n(balance chip, plan badge ★)"]
            CondHeader["ConditionalHeader.tsx"]
        end

        subgraph Auth2["auth/"]
            ProtectedRoute["ProtectedRoute.tsx\n(spinner fix ★)"]
        end

        subgraph Sessions2["sessions/"]
            ClassCreation["ClassCreation.tsx\n(+ avatar picker ★)"]
            AISettings["AISettings.tsx\n(+ persona tab ★)"]
            UnifiedDash["UnifiedDashboard.tsx"]
            SessionRuns["SessionRuns.tsx\n(+ quiz results ★)"]
            SlidesPreview["SlidesPreview.tsx\n(+ cite highlight ★)"]
        end

        subgraph Teaching2["teaching/"]
            TeachingIface["TeachingInterface.tsx\n(+ quiz trigger ★)\n(+ feedback modal ★)"]
            Transcript["Transcript.tsx\n(+ flag/upvote ★)"]
            BottomToolbar["BottomToolbar.tsx"]
        end

        subgraph PersonaComps["professor/ ★"]
            AvatarPicker["AvatarPicker.tsx ★"]
            PreferencesForm["PreferencesForm.tsx ★"]
            RefinedPromptEditor["RefinedPromptEditor.tsx ★"]
        end
    end

    subgraph Hooks2["hooks/"]
        useAuth["useAuth (AuthContext)"]
        useBilling["useBilling.ts"]
        useCourses["useCourses.ts"]
        useAvatars["useAvatars.ts ★"]
        usePersona["useProfessorPersona.ts ★"]
        useMemory["useStudentMemory.ts ★"]
        useHandleEvent["useHandleServerEvent.ts\n(+ searchKnowledge ★)\n(+ citeSlide ★)\n(+ flagForReview ★)"]
    end

    subgraph BFF["app/api/ (BFF Route Handlers)"]
        AuthRoutes["auth/\n  login/ ★\n  logout/ ★\n  verify/ ★\n  refresh/ ★"]
        SessionRoutes["sessions/[id]/\n  run/start/\n  run/[id]/stop/\n  search-knowledge/ ★"]
        AvatarRoutes["avatars/ ★"]
        PersonaRoutes["professor/persona/ ★"]
        BillingRoutes["billing/\n  balance\n  redeem\n  usage\n  subscription/ ★"]
    end

    Layout --> AuthGroup
    Layout --> DashGroup
    DashGroup --> SharedComponents
    DashGroup --> Hooks2
    Hooks2 --> BFF
    SharedComponents --> Hooks2

    classDef new fill:#d4edda,stroke:#28a745,color:#000
    class KnowledgePage,BillingSubscription,ProfessorFlow,PersonaSetup,Analytics,Privacy,PersonaComps,AvatarPicker,PreferencesForm,RefinedPromptEditor,useAvatars,usePersona,useMemory,AuthRoutes,AvatarRoutes,PersonaRoutes new
```

---

## 4. Sequence: Authentication Flow (Fixed — BFF Pattern)

```mermaid
sequenceDiagram
    actor User
    participant Browser as Browser (React)
    participant BFF as Next.js BFF\n/app/api/auth/login
    participant Backend as FastAPI Backend
    participant DB as PostgreSQL

    User->>Browser: Enter username + password
    Browser->>BFF: POST /api/auth/login\n{ username, password }
    Note over BFF: Server-side only — no CORS exposure
    BFF->>Backend: POST /api/auth/login\n(forwards credentials)
    Backend->>DB: SELECT user WHERE username=?
    DB-->>Backend: User row
    Backend->>Backend: bcrypt.checkpw(password, hash)
    Backend-->>BFF: { token, user, expires_at }
    BFF-->>Browser: { token, user, expires_at }
    Browser->>Browser: localStorage.setItem(token, user, expires_at)
    Browser->>User: Redirect to /dashboard

    Note over Browser: On every page load — checkAuth()
    Browser->>BFF: GET /api/auth/verify\n(Authorization: Bearer token)
    BFF->>Backend: GET /api/auth/verify-token
    Backend->>Backend: jwt.decode(token, secret)
    alt Token valid
        Backend-->>BFF: { user }
        BFF-->>Browser: { user }
        Browser->>Browser: setUser(userData)
    else Token expired (within 30 min of expiry)
        Browser->>BFF: POST /api/auth/refresh
        BFF->>Backend: POST /api/auth/refresh
        Backend-->>BFF: { token: newToken, expires_at }
        BFF-->>Browser: { token: newToken, expires_at }
        Browser->>Browser: Update localStorage
    else Token invalid
        Backend-->>BFF: 401 Unauthorized
        BFF-->>Browser: 401
        Browser->>Browser: clearAuth(), redirect /login
    end
```

---

## 5. Sequence: RAG Ingestion Pipeline (File Upload)

```mermaid
sequenceDiagram
    actor Professor
    participant Frontend as Frontend
    participant BFF as Next.js BFF
    participant Backend as FastAPI
    participant FileSvc as file_processor.py
    participant RAGSvc as rag_service.py
    participant OpenAI as OpenAI API
    participant PG as PostgreSQL\n+ pgvector

    Professor->>Frontend: Upload PPTX/PDF
    Frontend->>BFF: POST /api/sessions/[id]/upload
    BFF->>Backend: POST /api/sessions/[id]/upload
    Backend->>FileSvc: validate_file(file)
    FileSvc->>FileSvc: Convert slides → images (pdf2image)
    FileSvc->>OpenAI: Vision API — extract text per slide image
    OpenAI-->>FileSvc: Structured slide text
    FileSvc->>PG: Update Session.slides_details (JSONB)
    FileSvc->>RAGSvc: ingest_session_document(session_id, slide_texts)

    loop For each slide
        RAGSvc->>RAGSvc: LangChain TextSplitter\nchunk_size=400, overlap=50
        RAGSvc->>OpenAI: POST /embeddings\ntext-embedding-3-small
        OpenAI-->>RAGSvc: vector[1536]
        RAGSvc->>PG: INSERT slide_chunks\n(content, embedding, slide_number)
    end

    RAGSvc-->>Backend: ingestion complete
    Backend-->>BFF: { status: "processed", slide_count: N }
    BFF-->>Frontend: success
    Frontend->>Professor: "Slides processed — ready to configure session"
```

---

## 6. Sequence: Live Session (Student Experience with RAG + Memory)

```mermaid
sequenceDiagram
    actor Student
    participant Frontend as Frontend\nTeachingInterface
    participant BFF as Next.js BFF
    participant Backend as FastAPI
    participant MemSvc as memory_service.py
    participant RAGSvc as rag_service.py
    participant OpenAI as OpenAI Realtime API
    participant PG as PostgreSQL

    Student->>Frontend: Join session
    Frontend->>BFF: GET /api/session/ephemeral?session_id=X
    BFF->>Backend: GET /api/session/ephemeral

    Backend->>MemSvc: build_student_preamble(student_id, session_id)
    MemSvc->>PG: cosine_search(student_memories, session_topic_embedding, top_k=3)
    PG-->>MemSvc: 3 past session summaries (~200 tokens)
    MemSvc-->>Backend: "Student context: In Networking session..."

    Backend->>Backend: _build_grounded_system_prompt(\n  persona=professor_persona.refined_prompt,\n  policy=GROUNDING_RULE,\n  student_preamble=memory_preamble,\n  quiz_enabled=True\n)
    Backend->>OpenAI: POST /realtime/sessions\n{ model, voice, instructions, tools:[searchKnowledge, citeSlide, flagForReview] }
    OpenAI-->>Backend: { client_secret }
    Backend-->>BFF: { client_secret }
    BFF-->>Frontend: { client_secret }

    Frontend->>OpenAI: WebRTC connect(client_secret)
    Note over Frontend,OpenAI: Voice session active

    Student->>OpenAI: "What is subnetting?"
    OpenAI->>BFF: Tool call: searchKnowledge\n{ query: "subnetting CIDR" }
    BFF->>Backend: POST /api/sessions/X/search-knowledge\n{ query: "subnetting CIDR" }
    Backend->>RAGSvc: retrieve_context(session_id, query, top_k=5)
    RAGSvc->>PG: cosine_search(slide_chunks, query_embedding, top_k=5)
    PG-->>RAGSvc: Top 5 relevant chunks
    RAGSvc-->>Backend: grounded_context_text
    Backend-->>BFF: { context: "Slide 7: Subnetting divides..." }
    BFF-->>OpenAI: Tool result: grounded context
    OpenAI->>Student: Voice response anchored to retrieved chunks
    OpenAI->>Frontend: Tool call: citeSlide({ slideNumber: 7 })
    Frontend->>Frontend: Highlight slide 7 in SlidesPreview

    Note over OpenAI,Frontend: Session ends — quiz triggered if enabled
    OpenAI->>Student: "Before we wrap up, quick check: What does /24 mean in CIDR?"
    Student->>OpenAI: Voice answer
    OpenAI->>Backend: Store quiz result via tool call
    Backend->>PG: INSERT session_quiz_results

    Note over Backend,PG: Async — Celery worker
    Backend->>MemSvc: generate_session_summary(session_run_id, transcript)
    MemSvc->>OpenAI: GPT-4o-mini summarise transcript (≈500 tokens)
    OpenAI-->>MemSvc: 3-sentence summary
    MemSvc->>PG: INSERT student_memories (summary + embedding)
```

---

## 7. Sequence: Professor Persona Setup

```mermaid
sequenceDiagram
    actor Professor
    participant Frontend as Frontend\nPersona Wizard
    participant BFF as Next.js BFF
    participant Backend as FastAPI
    participant OpenAI as OpenAI GPT-4o
    participant PG as PostgreSQL

    Professor->>Frontend: Open Persona Setup
    Frontend->>BFF: GET /api/avatars
    BFF->>Backend: GET /api/avatars
    Backend->>PG: SELECT avatars WHERE is_active=true
    PG-->>Backend: Avatar list
    Backend-->>Frontend: [{ id, name, thumbnail_url, voice_id }]
    Frontend->>Professor: Show avatar grid

    Professor->>Frontend: Select "Dr. Rivera"\nSet preferences:\n  pacing=thorough\n  style=socratic\n  quiz=enabled
    Frontend->>Professor: Show preferences summary

    Professor->>Frontend: Click "Refine with AI"
    Frontend->>BFF: POST /api/professor/persona/refine\n{ avatar_id, preference_selections }
    BFF->>Backend: POST /api/professor/persona/refine
    Backend->>OpenAI: Chat Completion\n"Given preferences {json},\ngenerate a 150-word AI persona prompt..."
    OpenAI-->>Backend: "You are Dr. Rivera, a calm and\nmeticulously evidence-based medical\neducator who uses the Socratic method..."
    Backend-->>Frontend: { refined_prompt }
    Frontend->>Professor: Show editable prompt textarea

    Professor->>Frontend: Edit prompt, click Save
    Frontend->>BFF: POST /api/professor/persona\n{ avatar_id, preferences, refined_prompt, quiz_enabled: true }
    BFF->>Backend: POST /api/professor/persona
    Backend->>PG: UPSERT professor_personas
    PG-->>Backend: saved
    Backend-->>Frontend: { persona_id, status: "saved" }
    Frontend->>Professor: "Persona saved — active for all sessions"
```

---

## 8. Sequence: Student Feedback Loop → Persona Refinement

```mermaid
sequenceDiagram
    actor Student
    actor Professor
    participant Frontend as Frontend
    participant BFF as Next.js BFF
    participant Backend as FastAPI
    participant OpenAI as OpenAI GPT-4o
    participant PG as PostgreSQL

    Note over Student,PG: During / after session
    Student->>Frontend: Rate session 3/5
    Frontend->>BFF: POST /api/sessions/X/runs/Y/feedback\n{ rating: 3, comment: "subnetting unclear" }
    BFF->>Backend: Store feedback
    Backend->>PG: INSERT session_feedback

    Student->>Frontend: Flag AI message as incorrect
    Frontend->>BFF: POST .../transcript-feedback\n{ message_index: 12, type: "incorrect" }
    BFF->>Backend: Store flag
    Backend->>PG: INSERT transcript_feedback

    Note over Professor,PG: Professor opens Analytics
    Professor->>Frontend: View /professor/analytics
    Frontend->>BFF: GET /api/professor/feedback-summary
    BFF->>Backend: Aggregate across all sessions
    Backend->>PG: SELECT AVG(rating), COUNT(flags) GROUP BY topic
    PG-->>Backend: { avg_rating: 3.2, top_flagged: ["subnetting","CIDR"], top_helpful: ["TCP/IP"] }
    Backend-->>Frontend: Feedback summary
    Frontend->>Professor: Dashboard:\n"Avg rating 3.2 · Subnetting flagged 8x\nSlide 7 most flagged"

    Professor->>Frontend: Click "Refine Persona from Feedback"
    Frontend->>BFF: POST /api/professor/persona/refine-from-feedback
    BFF->>Backend: Load current persona + feedback summary
    Backend->>OpenAI: "Current persona: {...}\nFeedback: students flag subnetting explanations.\nSuggest 2 specific changes to the persona prompt."
    OpenAI-->>Backend: "1. Add: explain subnetting with\nbinary notation before CIDR.\n2. Slow pacing on slide 7 material."
    Backend-->>Frontend: { suggestions: [...], preview_prompt }
    Frontend->>Professor: Show diff: current vs suggested prompt

    Professor->>Frontend: Accept suggestion 1, reject 2, save
    Frontend->>BFF: POST /api/professor/persona\n{ refined_prompt: updated }
    BFF->>Backend: UPSERT professor_personas
    Backend-->>Frontend: saved
    Frontend->>Professor: "Updated — active from next session"
```

---

## 9. Sequence: Stripe Subscription Checkout

```mermaid
sequenceDiagram
    actor User
    participant Frontend as Frontend
    participant BFF as Next.js BFF
    participant Backend as FastAPI
    participant Stripe as Stripe API
    participant PG as PostgreSQL

    User->>Frontend: Click "Upgrade to Educator ($15/mo)"
    Frontend->>BFF: POST /api/billing/subscription/create-checkout\n{ plan: "educator" }
    BFF->>Backend: POST /api/billing/subscription/create-checkout
    Backend->>Stripe: Create Checkout Session\n{ price_id: STRIPE_PRICE_ID_EDUCATOR,\n  customer_email: user.email,\n  success_url, cancel_url }
    Stripe-->>Backend: { checkout_url }
    Backend-->>Frontend: { checkout_url }
    Frontend->>User: Redirect → Stripe Checkout page

    User->>Stripe: Enter card, confirm
    Stripe->>User: Redirect → success_url

    Note over Stripe,PG: Stripe fires webhook
    Stripe->>Backend: POST /api/webhooks/stripe\nevent: invoice.paid
    Backend->>Backend: stripe.verify_webhook_signature()
    Backend->>PG: UPSERT stripe_subscriptions\n{ plan: "educator", status: "active" }
    Backend->>PG: INSERT stripe_invoices
    Backend->>PG: UPDATE credit_balances\n+= 5000 credits (Educator monthly)
    Backend-->>Stripe: 200 OK

    User->>Frontend: Return to /billing/subscription
    Frontend->>BFF: GET /api/billing/subscription/status
    BFF->>Backend: Fetch subscription
    Backend->>PG: SELECT stripe_subscriptions
    Backend-->>Frontend: { plan: "educator", status: "active", next_renewal: "..." }
    Frontend->>User: "Educator plan active · 5,000 credits added"
```

---

## 10. Backend Service Dependency Map

```mermaid
graph LR
    subgraph Routes["API Routes (app/api/)"]
        R_Auth["auth/api.py"]
        R_Session["sessions/api.py"]
        R_Billing["billing/api.py"]
        R_Admin["admin/billing_api.py"]
        R_Avatar["avatars/api.py ★"]
        R_Persona["professor/persona/api.py ★"]
        R_Memory["memory/api.py ★"]
        R_WixHook["webhooks/wix.py"]
        R_StripeHook["webhooks/stripe.py ★"]
    end

    subgraph Svc["Services (app/services/)"]
        AuthSvc["auth_service"]
        BillSvc["billing_service"]
        OpenAISvc["openai_service"]
        FileSvc["file_processor"]
        RAGSvc["rag_service ★"]
        MemSvc["memory_service ★"]
        EmailSvc["email_service"]
        CourseSvc["course_service"]
        StoreSvc["cloud_storage_service"]
    end

    subgraph Infra["Infrastructure"]
        PG[("PostgreSQL\n+ pgvector")]
        Redis[("Redis")]
        R2[("Cloudflare R2")]
        OpenAI_API["OpenAI API"]
        Stripe_API["Stripe API ★"]
    end

    R_Auth --> AuthSvc
    R_Session --> OpenAISvc
    R_Session --> FileSvc
    R_Session --> RAGSvc
    R_Session --> MemSvc
    R_Billing --> BillSvc
    R_Admin --> BillSvc
    R_Avatar --> PG
    R_Persona --> OpenAISvc
    R_Persona --> PG
    R_Memory --> MemSvc
    R_WixHook --> BillSvc
    R_StripeHook --> BillSvc
    R_StripeHook --> Stripe_API

    AuthSvc --> PG
    AuthSvc --> EmailSvc
    BillSvc --> PG
    OpenAISvc --> OpenAI_API
    OpenAISvc --> PG
    OpenAISvc --> RAGSvc
    OpenAISvc --> MemSvc
    FileSvc --> R2
    FileSvc --> PG
    FileSvc --> RAGSvc
    RAGSvc --> OpenAI_API
    RAGSvc --> PG
    MemSvc --> OpenAI_API
    MemSvc --> PG
    CourseSvc --> PG
    StoreSvc --> R2

    classDef new fill:#d4edda,stroke:#28a745,color:#000
    class R_Avatar,R_Persona,R_Memory,R_StripeHook,RAGSvc,MemSvc,Stripe_API new
```

---

## 11. GDPR Data Flow

```mermaid
flowchart TD
    Register["User Registers\n(consent checkbox ✓)"]
    Consent["User.gdpr_consent_at = now()"]
    PII["PII Stored\nemail, name, transcripts,\nmemories, quiz results"]

    subgraph Encrypted["Encrypted at rest (AES-256-GCM)"]
        MemText["StudentMemory.summary_text"]
        QuizAnswers["SessionQuizResult.answers"]
        TransText["TranscriptFeedback content"]
    end

    subgraph R2Enc["R2 (encrypted at rest)"]
        Files["PPTX, PDFs, Slide images"]
    end

    subgraph Retain7yr["Retained 7 years (financial law)"]
        BillingRec["StripeInvoice\nProcessedWixOrder\nUsageRecord (anonymised)"]
    end

    Erase["User requests erasure\nDELETE /api/users/me"]
    Anonymise["User row anonymised\nemail → uuid@deleted.invalid\nname → [deleted]"]
    Delete["Delete:\nStudentMemory\nSessionFeedback\nTranscriptFeedback\nSessionQuizResult\nR2 files"]
    NullFK["Null user_id FK on\nfinancial records"]
    EmailConfirm["Erasure confirmation\nemail sent"]

    Export["User requests export\nGET /api/users/me/export"]
    ZipFile["ZIP: profile.json\nsessions.json\ntranscripts/\nquiz_results.json\nbilling.json"]
    AES_Export["Encrypted with\nuser's password (AES-256)"]
    R2Link["Temp R2 presigned link\n(48hr TTL)"]
    EmailExport["Download link emailed"]

    Register --> Consent --> PII
    PII --> Encrypted
    PII --> R2Enc

    Erase --> Anonymise
    Erase --> Delete
    Erase --> NullFK
    NullFK --> Retain7yr
    Erase --> EmailConfirm

    Export --> ZipFile --> AES_Export --> R2Link --> EmailExport
```

---

## 12. Phase Delivery Summary

```mermaid
gantt
    title ProfSidekick — Implementation Phases
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section Immediate Fixes
    Auth BFF routes (4 files)         :crit, fix1, 2026-05-25, 1d
    AuthContext verify URL fix         :crit, fix2, 2026-05-25, 1h
    get_optional_user fix              :fix3, 2026-05-25, 1h
    401 interceptor + expires_at       :fix4, 2026-05-26, 1d
    ProtectedRoute blank flash         :fix5, 2026-05-26, 2h

    section Phase 1 — Foundation
    RAG pipeline (pgvector + LangChain):p1a, 2026-06-01, 14d
    Avatar library + DB seed           :p1b, 2026-06-01, 7d
    Persona builder UI + LLM refine    :p1c, 2026-06-08, 10d
    searchKnowledge + citeSlide tools  :p1d, 2026-06-15, 7d
    Constrained answer policy          :p1e, 2026-06-15, 3d

    section Phase 2 — Intelligence
    Student memory service             :p2a, 2026-07-13, 10d
    Cross-session preamble injection   :p2b, 2026-07-20, 5d
    Post-session quiz (1c)             :p2c, 2026-07-25, 7d
    Feedback loop + analytics          :p2d, 2026-08-01, 14d
    Feedback → persona refinement      :p2e, 2026-08-10, 7d
    GDPR: field encrypt + erasure      :p2f, 2026-08-17, 10d

    section Phase 3 — Business Model
    Stripe subscriptions               :p3a, 2026-09-14, 14d
    Tier enforcement middleware        :p3b, 2026-09-21, 7d
    Pricing page + subscription UI     :p3c, 2026-09-28, 7d
    Institution tier + SSO             :p3d, 2026-10-12, 21d
```
