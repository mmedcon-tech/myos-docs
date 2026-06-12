# ProfSidekick — Operational Cost Breakdown

**Prepared:** 2026-06-07  
**Scope:** All third-party costs to run the platform at production. Does not include development time or profit margins. HeyGen pricing is based on Avatar III (Standard) unless noted.

---

## 1. Fixed Monthly Infrastructure

| Service | Plan | Cost/month | Notes |
|---|---|---|---|
| Contabo VPS | Cloud VPS 1 | **$8.00** | Hosts FastAPI, PostgreSQL + pgvector, Redis |
| Vercel | Pro | **$20.00** | Next.js 15 frontend hosting, serverless BFF routes |
| Cloudflare | Free | **$0.00** | DNS, DDoS protection, SSL termination, subdomain proxy |
| Domain (annual) | — | **~$1.00** | ~$12/year amortised |
| **Fixed total** | | **~$29/month** | |

---

## 2. Storage — Cloudflare R2

R2 free tier covers **10 GB storage, 1M Class A, 10M Class B** operations per month. Costs below apply beyond those limits.

| Item | Rate | Free tier |
|---|---|---|
| Storage | $0.015 / GB / month | First 10 GB free |
| Class A operations (writes: upload, PUT) | $4.50 / million | First 1M free |
| Class B operations (reads: GET, HEAD) | $0.36 / million | First 10M free |
| Egress (downloads to users) | **$0.00** | Always free |

**Estimate at low scale (< 500 slide uploads/month):** stays within free tier → **$0/month**  
**Estimate at 2,000 slide uploads + active serving:** ~$2–5/month

---

## 3. OpenAI API

All token rates are per 1 million tokens unless noted.

| Use case | Model | Input rate | Output rate | Estimated cost/session |
|---|---|---|---|---|
| Slide extraction (Vision) | gpt-4o | $2.50 / 1M | $10.00 / 1M | ~$0.02–0.05 per slide |
| Persona refinement (LLM) | gpt-4o | $2.50 / 1M | $10.00 / 1M | ~$0.01 per refinement call |
| Session summaries (memory) | gpt-4o-mini | $0.15 / 1M | $0.60 / 1M | ~$0.001 per session |
| Feedback summary / quiz gen | gpt-4o-mini | $0.15 / 1M | $0.60 / 1M | ~$0.002 per run |
| RAG embeddings (ingestion + retrieval) | text-embedding-3-small | $0.02 / 1M | — | ~$0.001 per session |
| **Realtime API — audio input** (student speaking) | gpt-4o-realtime | **$0.06 / min** | — | ~$1.20 per 20-min session |
| **Realtime API — audio output** (AI speaking) | gpt-4o-realtime | — | **$0.24 / min** | ~$4.80 per 20-min session |
| Realtime API — text (system prompt, RAG context) | gpt-4o-realtime | $5.00 / 1M | $20.00 / 1M | ~$0.01 per session |

**OpenAI cost per 20-minute live session (voice only, no HeyGen): ~$6.00**

---

## 4. HeyGen API

| Feature | Cost / minute | Cost / second | Notes |
|---|---|---|---|
| Avatar III — Standard | **$1.00** | $0.0167 | Photo Avatar, Digital Twin, Studio Avatar |
| Avatar IV — Advanced | **$3.00–$4.00** | $0.05–$0.0667 | Higher motion quality; 4K output at higher end |
| Video Translation | **$2.00–$4.00** | $0.0333–$0.0667 | Speed vs. Precision lip-sync modes |
| Video Agent | **$2.00** | $0.0333 | Prompt-to-video generation |
| TTS (Text-to-Speech) | **$0.04 / call** | — | Flat rate per generation |

**HeyGen cost per 20-minute live session:**

| Avatar tier | Cost |
|---|---|
| Standard (III) | $20.00 |
| Advanced (IV) | $60.00–$80.00 |

> **Note:** HeyGen is the dominant cost driver. A 20-minute session with Standard streaming avatar costs ~$20 in HeyGen alone, versus ~$6 for OpenAI voice. Avatar IV sessions cost 3–4× more.

---

## 5. Full Per-Session Cost Estimate (20-minute session)

| Component | Standard avatar (III) | Advanced avatar (IV) |
|---|---|---|
| OpenAI Realtime (voice) | $6.00 | $6.00 |
| HeyGen streaming avatar | $20.00 | $60.00–$80.00 |
| RAG queries + embeddings | $0.01 | $0.01 |
| Session summary (memory) | $0.002 | $0.002 |
| **Total per session** | **~$26.01** | **~$66–86** |

**Voice-only session (no HeyGen):** ~$6.01 per 20-minute session.

---

## 6. Ancillary Services

| Service | Purpose | Cost |
|---|---|---|
| Transactional email (e.g. Resend / SendGrid) | Email verification, GDPR erasure confirmation, auto top-up notifications | Free tier: 3,000/month; paid: ~$20/month |
| Stripe (when integrated, Phase 3) | Subscription billing | 2.9% + $0.30 per successful transaction |
| Wix (current payment flow) | Credit purchase webhooks | Included in Wix plan; no API fee |

---

## 7. Monthly Estimate by Scale

These figures assume 20-minute sessions and Standard avatar (III). HeyGen cost will be the largest variable.

| Active sessions/month | OpenAI (voice) | HeyGen (Standard) | Storage + infra | Est. total/month |
|---|---|---|---|---|
| 50 | $300 | $1,000 | $29 | **~$1,329** |
| 200 | $1,200 | $4,000 | $35 | **~$5,235** |
| 500 | $3,000 | $10,000 | $50 | **~$13,050** |
| 1,000 | $6,000 | $20,000 | $80 | **~$26,080** |

---

## 8. Cost Reduction Levers

| Lever | Potential saving |
|---|---|
| Cap HeyGen session length (e.g. 15 min max before renewal prompt) | Proportional to cap |
| Use voice-only mode (no HeyGen) for Free tier | Removes $1/min HeyGen cost |
| Use gpt-4o-mini for low-stakes Chat Completions (summaries, quiz gen) | ~85% cheaper than gpt-4o |
| Enable OpenAI prompt caching (5-min TTL) for repeated system prompts | Up to 50% reduction on cached tokens |
| Batch slide ingestion (embed off peak) | Negligible; embedding is already cheap |
| Enforce session credit cost in billing | Passes real API cost to user via credits |
