# ProfSidekick — Wix Payment Integration Guide

## The Core Idea

ProfSidekick's backend already has the plumbing to add credits to any user account. The `add_credits(user_id, amount_usd, db)` function in `billing_service.py` is all that needs to be called after a verified payment.

Wix can be the payment front-end. ProfSidekick stays the application back-end. The bridge is either a **webhook** (automated) or an **access-code workflow** (manual, zero-code).

---

## Option A — Manual Workflow (Zero Code, Works Today)

This requires no new code and can be running in minutes.

```
User pays on Wix store (e.g. "50 credits — $0.50")
         │
         ▼
Wix sends order confirmation email to user AND to admin
         │
         ▼
Admin receives notification, creates an access code:
  POST /api/admin/billing/access-codes
  { "total_credits": 50, "max_redemptions": 1, "issued_by": "Wix Order #12345" }
         │
         ▼
Admin emails the generated code to the user
         │
         ▼
User redeems code at profsidekick.com/billing/redeem
```

**Pros:** No code. Works today. Admin has full oversight.  
**Cons:** Manual step — hours of delay. Doesn't scale past ~20 orders/day.

---

## Option B — Wix Webhook → Auto-Credit (Recommended)

Wix fires a webhook on each completed payment. ProfSidekick adds a webhook handler endpoint that verifies the payment and calls `add_credits`.

### What needs to be built on ProfSidekick

**New backend file:** `app/api/webhooks/wix.py`

```python
from fastapi import APIRouter, Request, HTTPException, Header
import hmac, hashlib, json
from app.database.connection import get_db
from app.database.models import User
from app.services.billing_service import add_credits
from app.config import settings

router = APIRouter(prefix="/api/webhooks", tags=["webhooks"])

CREDITS_PER_DOLLAR = 100  # or read from settings

# Map Wix product IDs to credit amounts
PRODUCT_CREDIT_MAP = {
    "wix-product-id-for-500-credits":  500,
    "wix-product-id-for-1000-credits": 1000,
    "wix-product-id-for-5000-credits": 5000,
}

@router.post("/wix-payment")
async def wix_payment_webhook(
    request: Request,
    x_wix_signature: str = Header(None),
):
    body = await request.body()

    # 1. Verify Wix HMAC signature
    expected = hmac.new(
        settings.wix_webhook_secret.encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, x_wix_signature or ""):
        raise HTTPException(status_code=401, detail="Invalid webhook signature")

    payload = json.loads(body)

    # 2. Only process completed orders
    if payload.get("data", {}).get("paymentStatus") != "PAID":
        return {"received": True}

    # 3. Extract buyer email and product
    buyer_email = payload["data"]["buyerInfo"]["email"]
    line_items = payload["data"]["lineItems"]

    db = next(get_db())
    try:
        user = db.query(User).filter(User.email == buyer_email).first()
        if not user:
            # User hasn't registered yet — store pending credit for when they do
            # (out of scope; for now just log)
            return {"received": True, "warning": "user not found"}

        for item in line_items:
            product_id = item.get("productId")
            quantity = item.get("quantity", 1)
            credits = PRODUCT_CREDIT_MAP.get(product_id, 0) * quantity
            if credits > 0:
                from decimal import Decimal
                add_credits(user.id, Decimal(str(credits / CREDITS_PER_DOLLAR)), db)

    finally:
        db.close()

    return {"received": True}
```

> **Note:** This is a template. You'll need to verify Wix's exact webhook payload shape (see Wix docs for `ecom/v1/orders/paid` event) and adjust field paths accordingly.

### Wix side setup

1. In Wix dashboard → **Automations** → **New Automation**
2. Trigger: **Order is paid** (eCommerce)
3. Action: **Send a webhook** → your backend URL: `https://your-backend.railway.app/api/webhooks/wix-payment`
4. Copy the Wix webhook secret and add it to your `.env` as `WIX_WEBHOOK_SECRET`

### ProfSidekick `.env` additions needed

```env
WIX_WEBHOOK_SECRET=your-wix-webhook-signing-secret
```

### Product setup in Wix store

Create products like:
- "500 AI Credits — $5.00" → tag with product ID in `PRODUCT_CREDIT_MAP`
- "1000 AI Credits — $9.00"
- "5000 AI Credits — $40.00"

The product IDs in Wix's catalog become the keys in `PRODUCT_CREDIT_MAP`.

**Pros:** Fully automated. Credits appear within seconds of payment.  
**Cons:** ~1 day of backend work. Requires Wix Business plan for webhooks.

---

## Option C — Wix as Login / Identity Provider (Advanced)

If you want Wix to be the single source of truth for user accounts (login on Wix, use ProfSidekick), you can implement SSO using a **Wix Members token** passed to ProfSidekick.

```
User logs in on Wix (wix.com/your-site)
         │
         ▼
Wix issues a member token (JWT or session)
         │
         ▼
User clicks "Go to ProfSidekick" button on Wix
  → URL: profsidekick.com/auth/wix-sso?token=<wix-jwt>
         │
         ▼
ProfSidekick backend verifies token against Wix's public key
Creates or upserts the ProfSidekick User record
Issues its own JWT for the session
         │
         ▼
User is logged into ProfSidekick transparently
```

This is a significant integration (2–4 days of work) and requires Wix Velo (developer mode) on the Wix side. It's best suited if Wix is your primary marketing/billing site and ProfSidekick is the app.

---

## Recommended Architecture: Option A now, Option B when volume grows

```
Phase 1 (now, zero code)
  Wix store → Order email → Admin creates code → User redeems
  Good for: pilots, small cohorts, testing pricing

Phase 2 (when > 20 orders/week)
  Wix store → Webhook → /api/webhooks/wix-payment → add_credits() auto-called
  Good for: self-serve, scalable, instant credit delivery

Phase 3 (optional, if Wix is primary identity)
  Wix SSO → ProfSidekick auto-login
  Good for: unified brand, single account for billing + app access
```

---

## Data Flow Diagram

```
                        WIX
                ┌──────────────────┐
                │  Store product   │
                │  "500 credits"   │
                │  $5.00           │
                └────────┬─────────┘
                         │ User pays
                         │
              ┌──────────▼──────────┐
              │   Wix Automation    │
              │   "Order is paid"   │
              │   → POST webhook    │
              └──────────┬──────────┘
                         │ HTTPS POST
                         │ X-Wix-Signature: ...
                         │
              ┌──────────▼──────────────────────────┐
              │  PROFSIDEKICK BACKEND                │
              │                                      │
              │  POST /api/webhooks/wix-payment      │
              │  1. Verify HMAC signature            │
              │  2. Look up user by buyer email      │
              │  3. billing_service.add_credits()    │
              │  4. CreditBalance updated in DB      │
              └──────────┬──────────────────────────┘
                         │
              ┌──────────▼──────────────────────────┐
              │  PROFSIDEKICK FRONTEND               │
              │                                      │
              │  /billing/usage                      │
              │  Balance chip in nav                 │
              │  → User sees new credits available   │
              └─────────────────────────────────────┘
```

---

## Security Checklist for Webhook Endpoint

- [ ] HMAC signature verified on every request (reject without checking if missing)
- [ ] Use `hmac.compare_digest` to prevent timing attacks
- [ ] Endpoint is HTTPS only (Railway/Vercel enforce this)
- [ ] Return 200 quickly (Wix retries on timeout — do heavy work async if needed)
- [ ] Idempotency: store `wix_order_id` in a table to skip duplicate webhooks
- [ ] `WIX_WEBHOOK_SECRET` is in `.env`, never committed to git

---

## Minimal Code Needed (Summary)

| File | Change |
|---|---|
| `app/config.py` | Add `wix_webhook_secret: str = Field("", env="WIX_WEBHOOK_SECRET")` |
| `app/api/webhooks/__init__.py` | Empty |
| `app/api/webhooks/wix.py` | Webhook handler (template above) |
| `app/main.py` | `app.include_router(wix_router)` |
| `.env` | `WIX_WEBHOOK_SECRET=<from Wix dashboard>` |
| Wix dashboard | Automation: Order paid → webhook URL |
| Wix products | Create credit packs with known product IDs |
