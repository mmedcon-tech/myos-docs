# Brightspace Integration

**Created:** 2026-06-24
**API reference:** https://docs.valence.desire2learn.com/reference.html

## Overview

Publishers can link their institution's Brightspace LMS account so they can pick documents from it instead of uploading files manually — the same experience as picking from Google Drive.

**OAuth mechanism:** Brightspace Authorization Code Grant  
**Auth server:** `https://auth.brightspace.com/core/connect/authorize`  
**Token server:** `https://auth.brightspace.com/core/connect/token`  
**Scopes required:** `content:topics:readonly content:modules:readonly content:file:read enrollments:orgunit:readonly`

**Multi-tenant note:** Each institution hosts its own Brightspace instance (e.g. `nyu.brightspace.com`). The publisher enters their institution's base URL when connecting. This URL is stored alongside the token and used for all subsequent API calls.

---

## Upload points that get the Brightspace picker

| Page | File | Accepted types |
|---|---|---|
| Knowledge documents | `publisher/avatars/[id]/knowledge/page.tsx` | PDF, PPTX, DOCX, TXT, MD |
| Reference solutions | `publisher/avatars/[id]/references/page.tsx` | PDF, DOC, DOCX, TXT, MD |
| Course materials | `components/courses/CourseMaterials.tsx` | PDF, DOCX, etc. |
| Class/session creation | `components/sessions/ClassCreation.tsx` | PDF, PPT, PPTX, DOCX |

---

## Phase 1 — Backend: OAuth & Token Storage ✅

### Env vars (add to `.env` and production secrets)

```
BRIGHTSPACE_CLIENT_ID=
BRIGHTSPACE_CLIENT_SECRET=
BRIGHTSPACE_REDIRECT_URI=https://yourapi.com/api/brightspace/callback
```

### DB model

`app/database/models/integrations.py` → `BrightspaceToken`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → users | unique; one token per publisher |
| `brightspace_base_url` | String(500) | e.g. `https://nyu.brightspace.com` |
| `access_token` | Text | encrypted at rest (future: use KMS) |
| `refresh_token` | Text nullable | |
| `expires_at` | DateTime nullable | |
| `created_at` / `updated_at` | DateTime | |

### Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/api/brightspace/auth?brightspace_url=` | JWT (publisher) | Redirects to Brightspace OAuth consent page |
| `GET` | `/api/brightspace/callback?code=&state=` | none (browser redirect) | Exchanges code for token, saves to DB, redirects to frontend |
| `GET` | `/api/brightspace/status` | JWT | Returns `{ connected, brightspace_url, expires_at }` |
| `DELETE` | `/api/brightspace/disconnect` | JWT | Deletes stored token |

**CSRF protection:** `state` is a `secrets.token_urlsafe(32)` stored in Redis with 5-minute TTL, keyed `bs_oauth_state:{state}`. Deleted on use.

---

## Phase 2 — Backend: Browse & Import APIs ✅

### Endpoints

| Method | Path | Brightspace call | Purpose |
|---|---|---|---|
| `GET` | `/api/brightspace/courses` | `GET /d2l/api/lp/1.49/enrollments/myenrollments/` | List publisher's enrolled org units |
| `GET` | `/api/brightspace/courses/{orgUnitId}/content` | `GET /d2l/api/le/1.82/{orgUnitId}/content/root/` | List root modules for a course |
| `GET` | `/api/brightspace/modules/{orgUnitId}/{moduleId}` | `GET /d2l/api/le/1.82/{orgUnitId}/content/modules/{moduleId}/structure/` | Walk module tree (returns modules + file/link topics) |
| `GET` | `/api/brightspace/topics/{orgUnitId}/{topicId}/file` | `GET /d2l/api/le/1.82/{orgUnitId}/content/topics/{topicId}/file` | Proxy/stream file bytes to browser |

**Token refresh helper (`_get_valid_token`):** Before every proxied call, checks `expires_at`. If within 60 seconds, exchanges `refresh_token` via `grant_type=refresh_token` and updates DB. Raises 401 if refresh fails.

**File proxy pattern:** `GET /topics/.../file` streams the Brightspace file directly to the browser with proper `Content-Disposition` and content-type headers. The frontend (Phase 3) receives this as a `Blob`, wraps it in a `File` object, and submits it to the existing upload endpoint — zero changes to existing upload endpoints required.

**Topic type filtering:** Topics with `topicType=1` are files (importable); `topicType=3` are external links (shown but not importable). The `isFile: bool` field in the module structure response makes this explicit for the frontend.

---

## Phase 3 — Frontend: Shared Picker Component

### Files

- `src/components/brightspace/BrightspacePicker.tsx` — modal with course → module → file tree
- `src/hooks/useBrightspaceConnection.ts` — checks `/api/brightspace/status`, drives connect/disconnect
- `src/app/api/brightspace/` — BFF proxy routes that forward to FastAPI

### BrightspacePicker props

```typescript
interface BrightspacePickerProps {
  acceptedTypes: string[];           // file extensions to show, e.g. ['pdf','docx']
  onFileImported: (file: {
    name: string;
    size: number;
    importId: string;               // opaque ID returned by /api/brightspace/import
  }) => void;
  onClose: () => void;
}
```

### UX flow

1. If not connected → show "Connect Brightspace" button + institution URL input
2. OAuth popup/redirect → on return, show course list
3. Course → module tree → file list (filtered by `acceptedTypes`)
4. Select file → spinner → `POST /api/brightspace/import` → calls `onFileImported`

---

## Phase 4 — Wire picker into upload points

For each of the 4 upload pages/components:

1. Import `BrightspacePicker` and `useBrightspaceConnection`
2. Add `brightspacePickerOpen` state
3. Render "Import from Brightspace" button alongside existing upload button
4. On import callback, feed result into existing file state (same as a normal file selection)

No changes needed to the upload POST handler or AI pipeline — the import endpoint returns a file reference that the existing upload flow already understands.

---

## Alembic migration checklist

- [ ] Phase 1: `alembic revision --autogenerate -m "add brightspace_tokens table"`
- [ ] Run `alembic upgrade head` before deploying Phase 2+

## Registration checklist (admin, one-time)

- [ ] Register app in Brightspace _Manage Extensibility_ tool
- [ ] Set redirect URI to `BRIGHTSPACE_REDIRECT_URI`
- [ ] Request scopes: `content:topics:readonly content:modules:readonly content:file:read enrollments:orgunit:readonly`
- [ ] Copy client_id and client_secret to prod secrets
