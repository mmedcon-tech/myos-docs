# Wix → ProfSidekick: Step-by-Step Setup Guide

## What you will end up with

Every time a customer buys a credit pack on your Wix store, Wix automatically sends the order details to ProfSidekick. ProfSidekick verifies the request, finds the buyer's account by email, and adds the correct number of credits — with no manual work.

---

## Prerequisites

- Wix site with **Wix Stores** installed (eCommerce plan)
- ProfSidekick backend deployed and reachable from the internet (e.g. Railway)
- Access to your ProfSidekick backend `.env` file

---

## PART 1 — Backend Setup (do this first)

### Step 1 — Generate a webhook secret

This is a random password only you and your server know. It proves that the webhook came from Wix and not someone else.

Open a terminal and generate one:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Example output: `xK9mP2nQ8vR5tL3wY7aB4cD6eF1gH0iJ`

Copy this value. You will use it in **both** Wix and your `.env`.

### Step 2 — Add environment variables to ProfSidekick backend

Open your backend `.env` file and add these lines:

```env
# Wix webhook shared secret (must match what you paste into Wix)
WIX_WEBHOOK_SECRET=xK9mP2nQ8vR5tL3wY7aB4cD6eF1gH0iJ

# Map Wix product IDs to credit amounts
# Fill this in after Step 5 (Product Setup) below
# Format: {"wix-product-id-here": credits_amount}
WIX_PRODUCT_CREDIT_MAP={}
```

> **Note:** Leave `WIX_PRODUCT_CREDIT_MAP` empty for now. You will fill it in after creating your Wix products in Step 5.

### Step 3 — Run the new database migration

```bash
alembic upgrade head
```

This creates the `processed_wix_orders` table that prevents duplicate credits on retries.

### Step 4 — Redeploy your backend

Push the new code and `.env` to Railway (or your hosting). Confirm the new endpoint is live:

```
GET https://your-backend.railway.app/docs
```

You should see `/api/webhooks/wix-payment` listed under the **webhooks** section.

---

## PART 2 — Wix Store Products Setup

### Step 5 — Create credit pack products in Wix

1. In your Wix dashboard, go to **Store > Products**
2. Click **+ New Product**
3. Create the following products (or whatever pricing you want):

| Product Name | Price | Credits |
|---|---|---|
| Starter Pack | $5.00 | 500 credits |
| Standard Pack | $10.00 | 1,000 credits |
| Pro Pack | $40.00 | 5,000 credits |

For each product:
- Set it as a **Physical product** type is fine, but turn off shipping
- Or use **Digital product** if available on your plan
- Set the price
- **Publish** each product

### Step 6 — Find each product's Wix Product ID

After creating the products, you need the internal Wix product ID for each one. The easiest way:

1. In your Wix dashboard, go to **Store > Products**
2. Click on a product to open it
3. Look at the browser URL bar. It will look like:
   ```
   https://manage.wix.com/premium-purchase-plan/dynamo/store/product/abc12345-def6-7890-ghij-klmnopqrstuv/edit
   ```
4. The UUID in the URL (e.g. `abc12345-def6-7890-ghij-klmnopqrstuv`) is the **product ID**
5. Write down the product ID for each credit pack

### Step 7 — Update WIX_PRODUCT_CREDIT_MAP in your .env

Now fill in the mapping you left empty in Step 2:

```env
WIX_PRODUCT_CREDIT_MAP={"abc12345-def6-7890-ghij-klmnopqrstuv": 500, "def67890-abc1-2345-mnop-qrstuvwxyz12": 1000, "ghi11111-jkl2-3456-stuv-wxyzabcdef34": 5000}
```

> **Format:** `{"product-id": credits_as_integer}` — no spaces around colons, valid JSON.

Redeploy after saving this.

---

## PART 3 — Wix Automation Setup

> **Important:** Wix's standard "Send HTTP Request" action does **not** support custom headers in the dashboard UI. You must use the **"Run Velo Code"** action (recommended) or fall back to the URL query parameter method. Both are covered below.

### Step 8 — Enable Wix Developer Mode (Velo)

Velo is Wix's built-in developer platform. You need it to write the custom HTTP request code.

1. From your Wix Editor, click **Dev Mode** in the top bar
2. Click **Turn on Dev Mode**
3. Wix will reload the editor with Velo enabled
4. You do **not** need to write any site code — you only need Velo to unlock the "Run Velo Code" action in Automations

### Step 9 — Open Automations

1. In your Wix site dashboard (manage.wix.com), click **Automations** in the left sidebar
2. Click **+ Create Automation** in the top right corner
3. Choose **Start from Scratch**

### Step 10 — Name your automation

Click the title at the top (it probably says "New Automation" or similar).
Type: `ProfSidekick — Credit Purchase`
Press Enter to save the name.

### Step 11 — Set the trigger

1. In the **trigger selection panel** that appears, look for the **Wix Stores** category
2. Inside Wix Stores, select the trigger for a completed payment. It will be named one of:
   - **"Order placed"** ← choose this if you see it (Wix marks it paid at placement for instant payments)
   - **"Order payment status changed"** ← choose this if "Order placed" includes unpaid orders
   - **"Payment received"**

   > **Tip:** If you choose "Order placed", add a **Condition** step (see below) to check that `paymentStatus = PAID` so you only credit confirmed payments.

3. After selecting the trigger, you will see trigger settings. Leave defaults unless you want to restrict to specific products.

4. **Do not** enable "Trigger once per person" — students may buy multiple packs.

#### Optional: Add a Condition step to filter only PAID orders

If you used "Order placed" (which fires for all orders regardless of payment):

1. Click the **Add Step** icon (the `+` button between trigger and action)
2. Click **Condition**
3. Set the condition to:
   - Field: `Order > Payment Status` (use the property picker to find it)
   - Operator: `equals`
   - Value: `PAID`
4. In the **THEN** path, continue with the next step
5. In the **ELSE** path, leave it empty (do nothing for unpaid orders)

### Step 12 — Add the "Run Velo Code" action

1. Click the **Add Step** icon (the `+` below the trigger, or below the condition if you added one)
2. Click **Action**
3. In the action selection panel, look for **"Run Velo code"**
   - It may appear under **"Code"**, **"Developer tools"**, or **"Custom"**
4. Click it to select it

### Step 13 — Write the Velo code

A code editor will open. **Replace all existing code** with the following:

```javascript
import { fetch } from 'wix-fetch';

export function invoke(payload) {
    return fetch("https://your-backend.railway.app/api/webhooks/wix-payment", {
        method: "post",
        headers: {
            "Content-Type": "application/json",
            "X-Webhook-Secret": "xK9mP2nQ8vR5tL3wY7aB4cD6eF1gH0iJ"
        },
        body: JSON.stringify(payload)
    });
}
```

**Before saving, make two substitutions:**

1. Replace `your-backend.railway.app` with your actual backend domain
2. Replace `xK9mP2nQ8vR5tL3wY7aB4cD6eF1gH0iJ` with your actual secret from Step 1

> **How this works:** Wix passes the full order payload as `payload` to your `invoke` function. The code forwards it to ProfSidekick with your secret in the `X-Webhook-Secret` header. ProfSidekick extracts the buyer email, order ID, and product IDs automatically.

Click **Done** or **Save** in the code editor.

---

### Alternative: URL Query Parameter (no Velo required)

If you cannot enable Velo or prefer to use the standard "Send HTTP Request" action, use the URL query parameter method instead of the Velo code method.

**In Step 12**, select **"Send HTTP request"** instead of "Run Velo code", then configure it:

- **Method:** `POST`
- **URL:**
  ```
  https://your-backend.railway.app/api/webhooks/wix-payment?secret=xK9mP2nQ8vR5tL3wY7aB4cD6eF1gH0iJ
  ```
  *(embed your secret directly in the URL as the `?secret=` query parameter)*

- **Headers:** Add only:
  - `Content-Type`: `application/json`

- **Body:** Select **"Entire payload"**

> **Security note:** The `?secret=` parameter will appear in your server access logs. This is less ideal than the Velo header approach but is functionally equivalent for protecting the endpoint.

---

### Step 14 — Activate the automation

1. Click **Save** first to save as a draft
2. Review the automation — it should show:
   - Trigger: [Wix Stores payment trigger]
   - (Optional) Condition: paymentStatus = PAID
   - Action: Run Velo code → forwards payload to ProfSidekick
3. Click **Activate** in the top right corner

The automation is now live.

---

## PART 4 — Test It End to End

### Step 15 — Place a test order

1. In Wix, go to **Store > Products**
2. Open any credit pack product
3. Click **Preview** to open your store
4. Add the product to cart and go through checkout
5. Use a test payment method (Wix Sandbox / test card if available on your plan)
6. Complete the order

### Step 16 — Verify credits were added

1. Log into ProfSidekick with the same email address you used at checkout
2. Open the nav menu and click **Credits & Usage**
3. You should see the new credits reflected in your balance
4. The usage history will show a new line item (though credit top-ups don't appear in usage history — check your balance on the `/billing/usage` page)

### Step 17 — Check backend logs if credits didn't appear

SSH into your Railway deployment (or check Railway's log viewer) and look for lines containing `Wix webhook`. The handler logs at each step:

```
INFO: Wix webhook: order abc123 — product def456 qty 1 → 500 credits ($5.00 USD)
INFO: Wix webhook: credited 500.0000 credits to user [uuid] (order abc123)
```

**Common problems:**

| Log message | Fix |
|---|---|
| `Invalid or missing webhook secret` | Secret in Velo code (or `?secret=`) doesn't match `WIX_WEBHOOK_SECRET` |
| `could not extract order_id` | Payload structure changed — enable DEBUG and log full payload |
| `no ProfSidekick account for email` | Buyer email doesn't match any registered user — user needs to register first |
| `no recognised products in order` | Product ID not in `WIX_PRODUCT_CREDIT_MAP` — add it |
| `already processed` | Duplicate delivery — safely ignored |
| Velo code not executing | Check Dev Mode is still enabled; confirm the action shows "Run Velo code" not "Send HTTP request" |

---

## PART 5 — Ongoing Maintenance

### Adding new credit pack products

1. Create the product in Wix Store
2. Get its product ID from the URL
3. Add it to `WIX_PRODUCT_CREDIT_MAP` in `.env`
4. Redeploy the backend

### Changing credit amounts

Edit `WIX_PRODUCT_CREDIT_MAP` values and redeploy. Existing processed orders are unaffected.

### Buyer registered after purchase

If a user paid on Wix but hadn't registered on ProfSidekick yet, the webhook logged a warning and no credits were added (the order is marked as processed). Manual remedy:

```bash
# On backend, run once:
POST /api/admin/billing/access-codes
{
  "issued_by": "Wix Order #12345 — manual recovery",
  "total_credits": 500,
  "max_redemptions": 1,
  "code": "RECOVERY-ORD-12345"
}
```

Then email the user their one-time recovery code.

---

## Summary Checklist

- [ ] Generated `WIX_WEBHOOK_SECRET` and added to `.env`
- [ ] Added `WIX_PRODUCT_CREDIT_MAP` to `.env` with all product IDs
- [ ] Ran `alembic upgrade head` on backend
- [ ] Redeployed backend — `/api/webhooks/wix-payment` visible in `/docs`
- [ ] Created credit pack products in Wix Store
- [ ] Enabled Wix Developer Mode (Velo)
- [ ] Created Wix Automation:
  - [ ] Trigger: Wix Stores order/payment trigger
  - [ ] (Optional) Condition: paymentStatus = PAID
  - [ ] Action: **Run Velo code** with secret in `X-Webhook-Secret` header
  - [ ] *(Alternative)* Action: Send HTTP request with `?secret=` in URL
- [ ] Automation is **Activated**
- [ ] Placed a test order and confirmed credits appeared in ProfSidekick
