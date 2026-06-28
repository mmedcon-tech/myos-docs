# Adding 3D Avatar Models

ProfSidekick v2 uses a database-driven catalog for 3D Avatar Models. This allows the system administrator to manage the available visual appearances without touching code, and gives Publishers the power to select from this catalog when configuring their sessions.

Here is the workflow for adding new 3D `.glb` models:

## Current Local Workflow (File System)

Since you are currently storing models within the project, follow these steps:

1. **Place the GLB File**: Copy your `.glb` 3D model into the frontend public directory:
   `profsidekick-frontend-main/public/avatars/your-new-model.glb`
2. **Place a Thumbnail (Optional)**: If you have a preview image, place it in the public images folder:
   `profsidekick-frontend-main/public/images/your-thumbnail.png`
3. **Add via Admin UI**:
   - Log in to the application as an Administrator.
   - Navigate to the **Admin > Models** section (`/admin/models`).
   - Click the **Add Model** button.
   - Fill out the form:
     - **Name**: A display name for the model (e.g. `Salama` or `Emirati Female 001`)
     - **Model Type**: Select `Three.js`
     - **Gender**: Select appropriately (`Female`, `Male`, or `Neutral`)
     - **Model URL or ID**: Enter the local path starting with a forward slash (e.g., `/avatars/your-new-model.glb`)
     - **Thumbnail URL**: Enter the thumbnail path (e.g., `/images/your-thumbnail.png`)
     - **Supported Languages**: Comma-separated ISO language codes (e.g., `en` or `en, ar`)
   - Save the model.

> [!NOTE]
> Once added, the model immediately becomes available to all Publishers in their Avatar Configuration screen!

## Future Workflow (Object Storage / AWS S3)

When you are ready to switch to object storage, the workflow becomes even simpler:

1. **Upload to S3**: Upload your `.glb` file to your AWS S3 bucket (or any CDN) and ensure the file is publicly readable.
2. **Get the URL**: Copy the full `https://` URL of the uploaded model.
3. **Add via Admin UI**:
   - Go to **Admin > Models**.
   - Click **Add Model**.
   - **Model Type**: Select `Three.js`
   - **Model URL or ID**: Paste the full S3 URL (e.g., `https://your-bucket.s3.amazonaws.com/your-new-model.glb`).
   
The frontend is already configured to accept both relative local paths (`/avatars/...`) and absolute URLs (`https://...`), so the transition to cloud storage requires **zero code changes**.

---

### Seeding the Initial Models

If you need to automatically populate the database with the initial 3 models (`avatar-1.glb`, `avatar-2.glb`, `avatar-3.glb`), a seed script has been created in the backend.

**In Docker (recommended):**
```bash
docker compose exec api python -m scripts.seed_3d_models
```

**Locally (from the `backend-main` directory):**
```bash
# Windows
.\.venv\Scripts\python.exe .\scripts\seed_3d_models.py

# macOS / Linux
.venv/bin/python scripts/seed_3d_models.py
```

*(Note: Ensure your PostgreSQL database is running before executing this script.)*

> [!NOTE]
> The seed script populates `file_path` and `preview_image_path` only. After seeding, open **Admin > Models** and edit each entry to set the **Model Type**, **Gender**, and **Supported Languages** fields so they display correctly in the publisher catalog.
