# ProfSidekick — Billing User Journey (Professor / Student)

## Overview

ProfSidekick uses a **credit-based system**. Every AI operation (processing slides, generating realtime voice sessions) costs credits. You must have a positive balance before using any AI-powered feature.

> 1 credit = $0.01 USD (100 credits per dollar)

Credits can be loaded in two ways:
- **Access Code** — a code issued by your institution or admin (e.g. `UNIV-2024-XKQT`)
- **Direct top-up** — purchase credits directly on the platform (stub currently; see §5 for Wix integration)

---

## Journey 1 — First-Time User (Institution-Issued Code)

```
Register
  │
  ▼
Email verified + Professor approved
  │
  ▼
Log in → Dashboard
  │
  ◄── Balance chip in nav bar shows "Add credits" (red) — no balance yet
  │
  ▼
Click "Add credits" chip  OR  open user menu → "Credits & Usage"
  │
  ▼
/billing/redeem
  ├─ Paste code received from institution (e.g. UNIV-2024-XKQT)
  └─ Click "Redeem Code"
         │
         ▼
     HTTP POST /api/billing/redeem
         │
         ├─ 200 OK → success banner: "Access code redeemed successfully."
         │            balance chip turns blue and shows credit amount
         │
         └─ 400 / 404 → error banner (invalid, expired, already redeemed, limit reached)
```

**After successful redeem:**
- Balance chip shows e.g. `50.00 cr` in blue
- User can now create sessions, process slides, start realtime sessions
- Credits are deducted automatically — user never sees a per-action prompt

---

## Journey 2 — Creating a Session (Credits Deducted Automatically)

```
Dashboard → Course → "New Session"
  │
  ▼
Upload presentation (PDF or PPTX)
  │
  ▼
Backend: process_slides_with_vision()
  ├─ PRE-CHECK: charge_usage("vision", ...) per slide
  │    └─ If balance < cost → HTTP 402 returned immediately
  │         Frontend should redirect to /billing/redeem
  │
  └─ Vision API called → slide content + title extracted
       charge_usage("chat", ...) for title extraction
```

**What costs credits:**

| Operation | Trigger | Approximate cost |
|---|---|---|
| `vision` | Each slide processed with GPT-4o | ~0.03–0.15 cr per slide |
| `chat` | Title extraction per slide (GPT-4o-mini) | ~0.001 cr per slide |
| `realtime_token` | Each "Start Session" that generates an ephemeral token | 0.50 cr flat fee |
| `transcription` | (Reserved — not yet wired to a call site) | 0.01 cr minimum |

> Exact costs depend on slide content length and are configurable by the admin (see Admin Journey).

---

## Journey 3 — Running Out of Credits Mid-Use

```
User clicks "Start Session" (generates realtime token)
  │
  ▼
Backend: charge_usage("realtime_token", ...)
  │
  ├─ Balance >= 0.50 cr → token generated, session starts normally
  │
  └─ Balance < 0.50 cr → HTTP 402 Insufficient Credits
         │
         ▼
     Frontend shows error:
     "Insufficient credits. Redeem an access code or add credits to continue."
         │
         ▼
     User goes to /billing/redeem or /billing/add-credits
```

---

## Journey 4 — Checking Balance and Usage History

```
Nav bar → user menu → "Credits & Usage"
  │
  ▼
/billing/usage
  ├─ Current balance shown at top
  ├─ Table of all usage records:
  │    operation_type | tokens in | tokens out | credits charged | funded by | date
  └─ Pagination: 20 records per page
```

**Balance info also shows:**
- `source: "access_code"` — credits funded by an institution code
- `source: "purchased"` — credits you bought directly
- `source: "none"` — no credits left

---

## Journey 5 — Buying Credits Directly (add-credits stub)

```
/billing/add-credits
  ├─ Choose preset: $5 / $10 / $25 / $50  OR  type custom amount
  ├─ Preview: "$10 = 1000 credits"
  └─ Click "Add 1000 credits"
         │
         ▼
     POST /api/billing/add-credits  { amount_usd: "10.00" }
         │
         ▼
     Credits added immediately (no payment verification in this stub)
     → success: "Added credits equivalent to $10.00 USD."
```

> **Note:** The add-credits endpoint is currently a stub — it adds credits without charging a payment method. For real payment processing, see the Wix Integration Guide (`docs/wix-integration.md`).

---

## Balance Priority Rules

When credits are deducted, the system checks in this order:

1. **Access code balance** (if a valid, non-expired, non-depleted code exists)
2. **Purchased credits balance** (CreditBalance table)
3. If both are zero → **HTTP 402** is raised

If you have both an access code and purchased credits, **the access code is always spent first**.

---

## Quick Reference — Billing Pages

| URL | Purpose |
|---|---|
| `/billing/redeem` | Redeem an institution access code |
| `/billing/usage` | View usage history + current balance |
| `/billing/add-credits` | Top up with purchased credits |
