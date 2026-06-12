# ProfSidekick — Billing Admin Journey

## Overview

The admin controls:
- **Access codes** — create batch codes to hand out to cohorts of users
- **Pricing** — set the credit cost per operation type (vision, chat, realtime_token, transcription)

All admin billing endpoints require the `X-Admin-Secret` header.  
Set `ADMIN_SECRET=<strong-value>` in the backend `.env` file.

> **Security:** Never expose `ADMIN_SECRET` to the frontend. All admin calls must be made server-side, via curl, Postman, or a private admin tool.

---

## Setup Checklist (One-Time)

```
1. Set ADMIN_SECRET in backend .env
   ADMIN_SECRET=my-very-strong-secret-here

2. Deploy / restart the backend

3. Confirm pricing configs exist (seeded by migration b1111111111b):
   GET /api/admin/billing/pricing/vision
   GET /api/admin/billing/pricing/chat
   GET /api/admin/billing/pricing/realtime_token
   GET /api/admin/billing/pricing/transcription
   (all require X-Admin-Secret header)
```

---

## Journey 1 — Issuing Access Codes for a Cohort

**Scenario:** A university course of 30 students needs access for one semester.

### Step 1 — Decide the credit budget

Each student will:
- Upload 1–3 sessions (10–30 slides each) → vision + chat costs
- Run 10–20 realtime sessions → 0.50 cr each

Rough estimate per student: ~50–100 credits is enough for a semester.

### Step 2 — Create an access code

```http
POST /api/admin/billing/access-codes
X-Admin-Secret: my-very-strong-secret-here
Content-Type: application/json

{
  "issued_by": "Dr. Smith — CS101 Fall 2026",
  "total_credits": 100.0,
  "max_redemptions": 30,
  "expires_at": "2027-01-15T00:00:00Z",
  "code": "CS101-FALL-2026"
}
```

**Response:**
```json
{
  "id": "uuid...",
  "code": "CS101-FALL-2026",
  "total_credits": 100.0,
  "remaining_credits": 100.0,
  "issued_by": "Dr. Smith — CS101 Fall 2026",
  "max_redemptions": 30,
  "redemptions_used": 0,
  "expires_at": "2027-01-15T00:00:00",
  "is_active": true,
  "created_at": "..."
}
```

**Key fields:**
| Field | Meaning |
|---|---|
| `total_credits` | Pool of credits shared across all redemptions |
| `max_redemptions` | How many different users can redeem this code |
| `expires_at` | After this date, code cannot be redeemed (null = never expires) |
| `code` | Omit this field to auto-generate a random code (XXXX-XXXX-XXXX format) |

> **Important:** `total_credits` is the **shared pool**, not per-user. 30 students × 100 cr/student = 3000 total credits. Adjust accordingly.

### Step 3 — Distribute the code

Send students/professors the code string (e.g. `CS101-FALL-2026`) via email, LMS, or Wix. They redeem it at `/billing/redeem`.

---

## Journey 2 — Monitoring Active Codes

```http
GET /api/admin/billing/access-codes
X-Admin-Secret: my-very-strong-secret-here
```

**Response:** List of all codes ordered by creation date, showing `remaining_credits` and `redemptions_used`.

Use this to:
- See how fast a pool is being depleted
- Identify codes that are nearly empty and need replenishment (create a new code)
- Identify unused codes that can be deactivated

---

## Journey 3 — Deactivating a Code

**Scenario:** A course ends early, or a code is compromised.

```http
PATCH /api/admin/billing/access-codes/{code_id}/deactivate
X-Admin-Secret: my-very-strong-secret-here
```

- Sets `is_active = false`
- Any user who already redeemed it **keeps their remaining balance** (the code's `remaining_credits` are not refunded, but no new redemptions can occur)
- New users cannot redeem the code

---

## Journey 4 — Adjusting Pricing

### View current pricing for an operation

```http
GET /api/admin/billing/pricing/vision
X-Admin-Secret: my-very-strong-secret-here
```

```json
{
  "id": "uuid...",
  "operation_type": "vision",
  "cost_per_1k_input_tokens": "0.002500",
  "cost_per_1k_output_tokens": "0.010000",
  "platform_fee_multiplier": "1.2000",
  "minimum_charge_credits": "0.010000",
  "updated_at": "..."
}
```

### Understanding pricing fields

| Field | Meaning |
|---|---|
| `cost_per_1k_input_tokens` | Raw OpenAI cost per 1000 input tokens in USD |
| `cost_per_1k_output_tokens` | Raw OpenAI cost per 1000 output tokens in USD |
| `platform_fee_multiplier` | Must be ≥ 1.0. `1.2` = 20% margin above raw cost |
| `minimum_charge_credits` | Floor: never charge less than this, even for tiny operations |

**Formula:**
```
raw_cost = (input_tokens / 1000 * cost_per_1k_input) + (output_tokens / 1000 * cost_per_1k_output)
total_cost = raw_cost * platform_fee_multiplier
credits_charged = max(total_cost * 100, minimum_charge_credits)
```

### Update pricing

```http
PATCH /api/admin/billing/pricing/vision
X-Admin-Secret: my-very-strong-secret-here
Content-Type: application/json

{
  "platform_fee_multiplier": "1.35",
  "minimum_charge_credits": "0.05"
}
```

Only provide the fields you want to change. The backend rejects `platform_fee_multiplier < 1.0` (can never price below raw cost).

---

## Default Pricing (Seeded by Migration)

| Operation | Input cost/1k | Output cost/1k | Multiplier | Minimum |
|---|---|---|---|---|
| `vision` | $0.0025 | $0.0100 | 1.20× | 0.01 cr |
| `chat` | $0.00015 | $0.00060 | 1.20× | 0.001 cr |
| `realtime_token` | $0 | $0 | 1.00× | **0.50 cr** |
| `transcription` | $0 | $0 | 1.00× | 0.01 cr |

> **realtime_token** uses the minimum as a flat fee — the token itself costs nothing in tokens, so the minimum is the entire charge. Adjust this to reflect your OpenAI Realtime API usage costs.

---

## Journey 5 — Pricing Update Workflow (When OpenAI Changes Prices)

```
1. OpenAI announces new pricing

2. Calculate new cost_per_1k values from OpenAI's pricing page

3. Update each affected operation:
   PATCH /api/admin/billing/pricing/vision   { "cost_per_1k_input_tokens": "0.003" }
   PATCH /api/admin/billing/pricing/chat     { "cost_per_1k_input_tokens": "0.000200" }

4. Consider increasing minimum_charge_credits if flat-fee operations become more expensive

5. If access codes were issued at old pricing, existing balances are unaffected —
   only new charges use the updated pricing
```

---

## Admin Endpoint Reference

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/admin/billing/access-codes` | Create a new access code |
| `GET` | `/api/admin/billing/access-codes` | List all access codes |
| `PATCH` | `/api/admin/billing/access-codes/{id}/deactivate` | Deactivate a code |
| `GET` | `/api/admin/billing/pricing/{operation_type}` | View pricing for one operation |
| `PATCH` | `/api/admin/billing/pricing/{operation_type}` | Update pricing for one operation |

All requests require: `X-Admin-Secret: <ADMIN_SECRET value>`

**Operation types:** `vision`, `chat`, `realtime_token`, `transcription`
