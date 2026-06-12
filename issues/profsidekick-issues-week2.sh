# #!/usr/bin/env bash
# set -euo pipefail

# # ProfSidekick — Issue bootstrap (Platform System Design)
# # Collaborators: Seidu (ss20675-beep), Eleni, Job (jobsenn), Chen
# # Run: bash create-profsidekick-platform-issues.sh

# LEAD="ignatiusratemo26"
# API_REPO="mmedcon-tech/profsidekick-api"
# FE_REPO="mmedcon-tech/profsidekick-frontend"

# sleep_between_creates_seconds=2

# create_issue () {
#   local repo="$1"
#   local title="$2"
#   local assignee="$3"
#   local labels_csv="$4"
#   local body="$5"

#   echo "Creating: [$repo] $title (assignee=$assignee)"
#   if [[ -n "$labels_csv" ]]; then
#     gh issue create -R "$repo" --title "$title" --assignee "$assignee" --label "$labels_csv" --body "$body"
#   else
#     gh issue create -R "$repo" --title "$title" --assignee "$assignee" --body "$body"
#   fi
#   sleep "$sleep_between_creates_seconds"
# }

# echo "=========================================="
# echo "Creating API Repo Issues"
# echo "=========================================="

# # ============================================
# # ELENI — Courses, Sessions, Subscriptions (API)
# # ============================================

# create_issue "$API_REPO" \
# "ELENI-1: Course management endpoints (CRUD + filtering)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:courses, dev:eleni\n\nGoal:\nBuild complete course management API for publishers.\n\nEndpoints:\n- POST /api/courses (create)\n- GET /api/courses (list with filters: is_public, user_id)\n- GET /api/courses/{id}\n- PATCH /api/courses/{id} (update is_public, description, etc.)\n- DELETE /api/courses/{id}\n\nImplementation:\n- app/api/courses/api.py\n- app/services/course_service.py\n- Filters must respect publisher isolation (course.user_id == current_user.id)\n- Tests: pytest with auth fixtures\n\nDefinition of done:\n- [ ] All 5 endpoints created + registered.\n- [ ] Publisher isolation enforced (service filters by user_id).\n- [ ] Integration tests for CRUD + access control.\n- [ ] AGENTS.md §5 updated with endpoints.\n'

# create_issue "$API_REPO" \
# "ELENI-2: Session creation, lifecycle, and mode switching (teaching vs examination)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:sessions, dev:eleni\n\nGoal:\nImplement session lifecycle management.\n\nEndpoints:\n- POST /api/sessions (create session from uploaded slides)\n  └── includes session_mode (teaching/examination) + selected_role_id\n- GET /api/sessions/{id}\n- PATCH /api/sessions/{id}/mode (switch between teaching and examination)\n- PATCH /api/sessions/{id}/role (switch avatar persona — see §7)\n- POST /api/sessions/{id}/run/start (initiate a session run)\n- POST /api/sessions/{id}/run/stop (end a session run)\n\nImplementation:\n- app/api/sessions/api.py\n- app/services/session_service.py\n- session_runs table for tracking active conversations\n- Tests: mode transitions, role isolation\n\nDefinition of done:\n- [ ] All endpoints implemented + tested.\n- [ ] Mode/role transitions validated (no invalid state combos).\n- [ ] Publisher owns session; subscribers cannot modify.\n- [ ] AGENTS.md §5 updated.\n'

# create_issue "$API_REPO" \
# "ELENI-3: Avatar subscriptions + subscription validation at session start" \
# "eleni" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:critical, area:subscriptions, dev:eleni\n\nGoal:\nImplement avatar subscription model and validation gates (§8.3).\n\nEndpoints:\n- POST /api/avatars/{id}/subscribe (subscriber subscribes to avatar)\n- GET /api/avatars/{id}/subscription (check current subscription status)\n- DELETE /api/avatars/{id}/subscription (unsubscribe)\n\nValidation logic (called before session ephemeral token is issued):\n1. user.role == subscriber\n2. avatar_subscriptions record exists + is_active\n3. subscription not expired (if expires_at set)\n4. course_students enrollment exists\n5. session.is_active == true\n6. Content privacy check (is_public OR has authorization)\n\nIf any check fails: 403 Forbidden (generic message — never leak which check failed).\n\nImplementation:\n- app/services/subscription_service.py\n- Validation gateway in openai_service.get_ephemeral_token()\n- Tests: all 5 checkpoints, edge cases (expired subscription, missing enrollment)\n\nDefinition of done:\n- [ ] Subscription CRUD works.\n- [ ] All 5 validation checkpoints enforced before token issuance.\n- [ ] 403 error messages generic (don\'t leak info).\n- [ ] Integration tests covering all paths.\n'

# create_issue "$API_REPO" \
# "ELENI-4: Course enrollment + bulk enrollment (government use case)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:courses, dev:eleni\n\nGoal:\nManage subscriber enrollment in courses.\n\nEndpoints:\n- POST /api/courses/{id}/enroll (single enrollment)\n- POST /api/courses/{id}/enroll-bulk (bulk CSV/JSON enrollment)\n- GET /api/courses/{id}/students (list enrolled students)\n- DELETE /api/courses/{id}/students/{user_id} (unenroll)\n\nImplementation:\n- app/api/courses/enrollments_api.py\n- app/services/enrollment_service.py\n- Bulk enrollment validates email format, handles duplicates, creates course_students records\n- Tests: single + bulk, duplicate handling, publisher isolation\n\nDefinition of done:\n- [ ] All endpoints working.\n- [ ] Bulk enrollment handles 500+ users without N+1 queries.\n- [ ] Duplicate prevention.\n- [ ] Tests cover happy path + error cases.\n'

# create_issue "$API_REPO" \
# "ELENI-5: Course privacy + public/private visibility filtering" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:courses, dev:eleni\n\nGoal:\nImplement privacy model (§9).\n\nLogic:\n- Subscriber sees only: is_public=true courses OR courses they are enrolled in\n- Publisher sees only: their own courses (user_id match)\n- Admin sees all\n\nImplementation:\n- Modify course_service.get_courses() to filter based on user role\n- Add is_public filter to GET /api/courses\n- Tests: verify subscriber, publisher, admin see correct lists\n\nDefinition of done:\n- [ ] Subscriber cannot see private courses (403 if trying to access directly).\n- [ ] GET /api/courses returns only authorized courses.\n- [ ] No data leakage in error messages.\n- [ ] Integration tests for all three roles.\n'

# # ============================================
# # SEIDU — Avatar + HeyGen Integration
# # ============================================

# create_issue "$API_REPO" \
# "SEIDU-1: Avatar template roles with HeyGen avatar_id + heygen_voice_id" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:avatar, dev:ss20675-beep\n\nGoal:\nExtend avatar_template_roles schema to support HeyGen (§6, §13.1).\n\nSchema changes in app/database/models.py:\n- avatar_template_roles.heygen_avatar_id (VARCHAR, nullable)\n- avatar_template_roles.heygen_voice_id (VARCHAR, nullable)\n- avatar_template_roles.default_language (VARCHAR, default en)\n\nAlembic migration:\n- alembic revision --autogenerate -m "add_heygen_fields_to_roles"\n\nSeed data:\n- Create two default roles: "Emirati Lady", "Emirati Gentleman"\n- Placeholder heygen_avatar_ids (e.g., "heygen_emirati_female_001")\n\nDefinition of done:\n- [ ] Schema changes applied locally.\n- [ ] Migration includes default language.\n- [ ] Seed script populates default roles.\n- [ ] Tests verify fields are set correctly.\n'

# create_issue "$API_REPO" \
# "SEIDU-2: Session language preference + ephemeral token includes heygen_avatar_id" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:rag, dev:ss20675-beep\n\nGoal:\nExtend sessions table + ephemeral token response (§6.3, §13.2).\n\nSchema changes:\n- sessions.preferred_language (VARCHAR, default en)\n- sessions.selected_role_id (FK to avatar_template_roles, used to look up heygen_avatar_id)\n\nAlembic migration:\n- alembic revision --autogenerate -m "add_language_and_role_to_sessions"\n\nModify openai_service.get_ephemeral_token():\n- Look up selected_role_id → avatar_template_roles → heygen_avatar_id\n- Return in response:\n  {\n    "openai_token": "...",\n    "heygen_avatar_id": "emirati_lady_001",\n    "heygen_quality": "high",\n    "session_language": "ar",\n    "session_mode": "teaching"\n  }\n\nDefinition of done:\n- [ ] Schema applied.\n- [ ] Token response includes heygen fields.\n- [ ] Integration test: GET /api/session/ephemeral returns expected heygen_avatar_id.\n'

# create_issue "$API_REPO" \
# "SEIDU-3: Avatar persona switch endpoint (PATCH /api/sessions/{id}/role)" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:avatar, dev:ss20675-beep\n\nGoal:\nImplement mid-session persona switching (§7.4).\n\nEndpoint:\n- PATCH /api/sessions/{id}/role { "role_id": "<uuid>" }\n\nValidation:\n- Publisher owns the session (not subscriber)\n- role_id exists on the avatar template\n- session is_active\n\nBehavior:\n- Update sessions.selected_role_id\n- Return new heygen_avatar_id + heygen_quality for frontend to reinitialize\n- Create audit log in session_persona_switches (§13.7)\n\nImplementation:\n- app/api/sessions/api.py (new PATCH handler)\n- app/services/session_service.py (switch_role logic)\n- Migration: create session_persona_switches table\n\nDefinition of done:\n- [ ] Endpoint validates publisher ownership.\n- [ ] selected_role_id updated + audit logged.\n- [ ] Test: subscriber cannot switch roles (403).\n- [ ] Integration test: role change reflected in next ephemeral token request.\n'

# create_issue "$API_REPO" \
# "SEIDU-4: HeyGen environment config + API key management" \
# "ss20675-beep" \
# "feature" \
# $'Priority: MEDIUM\nIntended Project Column: Backlog\nIntended labels: chore, priority:medium, area:avatar, dev:ss20675-beep\n\nGoal:\nSet up HeyGen API credentials and client factory.\n\nImplementation:\n- app/config.py: add HEYGEN_API_KEY (SecretStr) + HEYGEN_API_URL\n- env.example: document HeyGen vars\n- app/services/heygen_service.py (new):\n  └── HeyGenClient wrapper around HeyGen REST API\n  └── Methods: (future) create_photo_avatar(), create_studio_avatar(), get_avatar_status()\n  └── Async client using httpx\n\nFor now, the service is a skeleton. HeyGen streaming happens client-side (JS SDK).\n\nDefinition of done:\n- [ ] Config vars added + documented in env.example.\n- [ ] HeyGenClient class created (even if mostly stub methods).\n- [ ] No errors on app startup when HEYGEN_API_KEY is set.\n'

# # ============================================
# # CHEN — Authentication, Registration, Forgot Password (API)
# # ============================================

# create_issue "$API_REPO" \
# "CHEN-1: SMTP service integration + global email client (foundation for all mailing)" \
# "chen" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:critical, area:auth, dev:chen\n\nGoal:\nBuild a global, reusable SMTP service so all features (auth, invoices, campaigns) can send mail (§12 reference).\n\nImplementation:\n- app/services/email_service.py (new)\n  └── EmailClient class (wraps smtplib or Resend/SendGrid)\n  └── Methods:\n      send_email(to, subject, html_body)\n      send_registration_confirmation(user_email, token)\n      send_password_reset(user_email, reset_token)\n      send_bulk(recipients, template_name, context)\n\n- app/config.py:\n  └── SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD (or SendGrid/Resend API key)\n  └── MAIL_FROM_ADDRESS\n  └── MAIL_FROM_NAME\n\n- env.example: document email config\n\n- app/templates/emails/ (new directory)\n  └── registration_confirmation.html\n  └── password_reset.html\n  └── (stubs for future: invoice_notification.html, campaign.html)\n\nTesting:\n- Unit tests with mock SMTP\n- Use Mailhog (local dev) or a test SMTP service\n\nDefinition of done:\n- [ ] EmailClient created + initialized on app startup.\n- [ ] Config vars in place.\n- [ ] Async send_email works (test with Mailhog or mock).\n- [ ] No actual emails sent in test mode (only logged).\n'

# create_issue "$API_REPO" \
# "CHEN-2: Enhanced registration with strong password validation + terms acceptance + email verification" \
# "chen" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:critical, area:auth, dev:chen\n\nGoal:\nUpgrade registration endpoint with security + legal requirements (§12 reference).\n\nChanges to POST /api/auth/register:\n\nRequest body:\n{\n  "email": "...",\n  "password": "...",\n  "first_name": "...",\n  "last_name": "...",\n  "agree_terms": true      ← NEW (required)\n}\n\nPassword validation:\n- Minimum 12 characters (configurable, recommend 12+ for gov use case)\n- Must include: uppercase, lowercase, digit, special char (!@#$%^&*)\n- No common passwords (check against rockyou/common list)\n- Reject if password similar to email/name (distance < 3)\n\nDatabase:\n- app/database/models.py User.terms_agreed_at (new timestamp field)\n- User.email_verified (bool, default False)\n- User.email_verification_token (new field, nullable)\n\nAlembic migration:\n- alembic revision --autogenerate -m "add_registration_fields"\n\nFlow:\n1. Validate all fields (password strength, email format, terms=true)\n2. Hash password\n3. Create user record with email_verified=false\n4. Generate email_verification_token (secure random, 32 bytes, hex encoded)\n5. Send email via email_service:\n   └── Link: /verify-email?token=...\n6. Return 201 with message "Check your email to verify account"\n\nEndpoint POST /api/auth/verify-email?token=...\n- Verify token matches email_verification_token\n- Set email_verified=true, terms_agreed_at=now()\n- Return auth token (auto-login)\n\nDefinition of done:\n- [ ] Password validation enforced (12 char min, complexity).\n- [ ] Terms checkbox required (agree_terms: true).\n- [ ] Verification email sent on registration.\n- [ ] Email verification endpoint works.\n- [ ] Tests: password edge cases (too short, no special char, similar to email).\n- [ ] Tests: terms acceptance mandatory.\n- [ ] Integration test: full registration + verification flow.\n'

# create_issue "$API_REPO" \
# "CHEN-3: Login with username OR email + password" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nModify login to accept either username or email (currently username only).\n\nChanges to POST /api/auth/login:\n\nRequest body:\n{\n  "username_or_email": "...",  ← NEW (replaces old "username" field)\n  "password": "..."\n}\n\nBackend logic:\n1. Determine if input is email (contains @) or username\n2. Query User by email OR username\n3. Verify password against stored hash\n4. Return auth token (if successful)\n\nDatabase:\n- Add unique index on users.username\n- Ensure users.email is unique\n\nImplementation:\n- app/services/auth_service.py: add is_email(str) helper\n- Modify login() to try email lookup first, then username\n- Tests: login by email, login by username, case-insensitive email lookup\n\nDefinition of done:\n- [ ] Can login with email OR username.\n- [ ] Case-insensitive email (user@example.com == USER@EXAMPLE.COM).\n- [ ] Tests for both paths (email + username).\n- [ ] Password validation unchanged.\n'

# create_issue "$API_REPO" \
# "CHEN-4: Forgot password + password reset flow" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nImplement forgotten password recovery.\n\nEndpoint 1: POST /api/auth/forgot-password\nRequest: { "email": "..." }\nFlow:\n1. Verify email exists in users table\n2. Generate reset_token (secure random, 32 bytes, hex)\n3. Store in new table password_resets with 1-hour TTL\n4. Send email via email_service (password_reset.html template)\n   └── Link: /reset-password?token=...\n5. Return 200 { "message": "Check your email for reset link" }\n\nNote: Never reveal whether email exists (always return same message).\n\nEndpoint 2: POST /api/auth/reset-password\nRequest: { "token": "...", "new_password": "..." }\nFlow:\n1. Verify token exists in password_resets + not expired (1h)\n2. Validate new_password (same strength rules as registration)\n3. Update users.password_hash\n4. Delete password_resets row (single-use)\n5. Return 200 { "message": "Password reset successful. Login with your new password." }\n\nDatabase schema:\n- New table password_resets:\n  id (UUID, PK)\n  user_id (UUID, FK)\n  token (VARCHAR, unique)\n  created_at (TIMESTAMP)\n  expires_at (TIMESTAMP)\n\nAlembic migration:\n- alembic revision --autogenerate -m "add_password_resets_table"\n\nImplementation:\n- app/services/auth_service.py: request_password_reset(), reset_password()\n- Email template: password_reset.html with reset link + expiry warning\n\nDefinition of done:\n- [ ] Forgot password endpoint returns same message for existing/non-existing emails.\n- [ ] Reset link valid for 1 hour only.\n- [ ] New password subject to same strength validation.\n- [ ] Token single-use (deleted after reset).\n- [ ] Tests: expired token rejected, invalid token rejected, successful reset.\n- [ ] Integration test: forgot password + reset flow end-to-end.\n'

# create_issue "$API_REPO" \
# "CHEN-5: Email verification on first login attempt (gate access until verified)" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nEnforce email verification before first API access.\n\nLogic:\n- User registers (email_verified=false)\n- User clicks email verification link\n- Email marked verified (email_verified=true)\n- Subsequent logins work normally\n- If user tries to login before verifying email: 403 Forbidden with message\n  "Your email has not been verified. Check your inbox for verification link."\n\nImplementation:\n- Modify get_current_user() in app/dependencies/auth.py\n  └── After JWT decode, check user.email_verified\n  └── If false: raise HTTPException(403, "Email not verified")\n- Verification endpoint (from CHEN-2) auto-verifies + logs user in\n\nDefinition of done:\n- [ ] Unverified users blocked from protected endpoints (403).\n- [ ] Verification link auto-logs user in + redirects to onboarding.\n- [ ] Test: unverified user gets 403.\n- [ ] Test: verified user can access protected endpoints.\n'

# echo ""
# echo "=========================================="
# echo "Creating Frontend Repo Issues"
# echo "=========================================="

# # ============================================
# # JOB — Frontend UI/UX (Layout, Components, Responsiveness)
# # ============================================

# create_issue "$FE_REPO" \
# "JOB-1: Restore settings page in new side navigation layout + implement privacy controls" \
# "jobsenn" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:ui, dev:jobsenn\n\nGoal:\nRestore user settings previously hidden by layout changes. Add privacy settings card.\n\nImplementation:\n- src/app/(dashboard)/settings/page.tsx (new or restored)\n- src/components/settings/ProfileSettings.tsx\n- src/components/settings/NotificationPreferences.tsx\n- src/components/settings/PrivacySettings.tsx (GDPR — see CHEN profile for backend)\n\nPrivacy section includes:\n- Export my data button\n- Delete account button (with "type DELETE" confirmation)\n- Marketing email opt-in toggle\n\nAdd to side nav (src/components/Sidebar.tsx):\n- Settings link (visible to all roles: subscriber, publisher, admin)\n\nResponsiveness:\n- Sidebar collapses to hamburger on mobile (< 768px)\n- Settings forms stack vertically on mobile\n- Buttons full-width on mobile, auto on desktop\n\nTheme support:\n- Light: white background, dark text, blue accents\n- Dark: slate-900 background, light text, blue accents\n- Test both themes: screenshot comparison\n\nDefinition of done:\n- [ ] Settings page renders correctly on desktop (1920px) + tablet (768px) + mobile (375px).\n- [ ] Dark/light theme switching works.\n- [ ] All settings cards responsive (no horizontal scroll on mobile).\n- [ ] Component tests for ProfileSettings + PrivacySettings.\n'

# create_issue "$FE_REPO" \
# "JOB-2: Fix layout issues + ensure components fully responsive (mobile-first approach)" \
# "jobsenn" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:ui, dev:jobsenn\n\nGoal:\nAudit and fix responsive layout issues across all pages.\n\nAudit checklist:\n- [ ] All pages tested at: 375px (mobile), 768px (tablet), 1920px (desktop)\n- [ ] No horizontal scrolling on mobile\n- [ ] Text readable at all sizes (no zoom required on mobile)\n- [ ] Touch targets >= 44px (mobile-friendly buttons/links)\n- [ ] Images scale properly (max-width: 100% on mobile)\n- [ ] Forms stack vertically on mobile, side-by-side on desktop\n- [ ] Sidebar collapses to hamburger on mobile\n- [ ] Tables scroll horizontally on mobile (not break layout)\n\nPages to audit:\n- /dashboard (student/publisher/admin views)\n- /courses (list + detail)\n- /sessions (list + detail)\n- /settings (all cards)\n- /auth (login/register)\n\nCommon fixes:\n- Replace hardcoded widths with Tailwind responsive prefixes (sm:, md:, lg:)\n- Use flex wrapping instead of fixed grids on mobile\n- Reduce padding/margins on mobile (px-3/py-2 → px-1/py-1)\n- Font sizes: h1 smaller on mobile\n\nImplementation:\n- Use Tailwind utilities: responsive prefixes (sm:, md:, lg:, xl:)\n- No media queries in CSS files\n- Test with Chrome DevTools mobile emulator + real devices if possible\n\nDefinition of done:\n- [ ] Layout audit complete across all pages.\n- [ ] No horizontal scroll on any viewport.\n- [ ] Touch targets >= 44px on mobile.\n- [ ] Sidebar collapses properly.\n- [ ] All pages screenshot-tested at 3 breakpoints.\n- [ ] No Tailwind warnings in build (unused classes, invalid syntax).\n'

# create_issue "$FE_REPO" \
# "JOB-3: Dark/light theme toggle + theme persistence + component audit" \
# "jobsenn" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:ui, dev:jobsenn\n\nGoal:\nImplement theme switching + ensure all components support both themes.\n\nImplementation:\n- ThemeProvider (using next-themes library if not already installed)\n- Theme toggle button in header (sun/moon icon)\n- Persist theme preference to localStorage\n- System preference fallback (prefers-color-scheme)\n\nComponent audit:\n- [ ] All components tested in light mode\n- [ ] All components tested in dark mode\n- [ ] Text contrast >= 4.5:1 (WCAG AA)\n- [ ] Colors not pure white/black (use gray-50, slate-950)\n- [ ] Borders visible in both modes\n\nColors:\n- Light: bg-white, text-gray-900, borders gray-200\n- Dark: bg-slate-900, text-gray-50, borders slate-700\n- Accents: blue-600 (both modes)\n\nFiles to update:\n- src/app/layout.tsx (ThemeProvider wrapper)\n- src/components/Header.tsx (add theme toggle)\n- src/styles/globals.css (Tailwind dark mode setup)\n- All component files: add dark: prefix to color utilities\n\nDefinition of done:\n- [ ] Theme toggle visible + functional.\n- [ ] Preference persists across browser sessions.\n- [ ] All pages readable in light + dark mode.\n- [ ] Contrast tests pass (WCAG AA).\n- [ ] Component tests verify both themes.\n'

# create_issue "$FE_REPO" \
# "JOB-4: Sidebar navigation + role-based menu visibility (publisher/subscriber/admin)" \
# "jobsenn" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:ui, dev:jobsenn\n\nGoal:\nBuild collapsible sidebar with role-based menu items.\n\nImplementation:\n- src/components/Sidebar.tsx (new or refactored)\n- src/components/NavLink.tsx (reusable nav item)\n- src/contexts/NavContext.tsx (global sidebar state: open/close)\n\nMenu structure (role-based):\n\nSubscriber:\n  - Dashboard\n  - My Courses\n  - Marketplace\n  - Settings\n  - Help\n\nPublisher:\n  - Dashboard\n  - My Avatars\n  - Courses\n  - Analytics\n  - Settings\n  - Help\n\nAdmin:\n  - Dashboard\n  - Templates\n  - Marketplace\n  - Users\n  - Analytics\n  - Settings\n\nBehavior:\n- On desktop (≥768px): always open, no toggle (or toggle visible but doesn\'t collapse)\n- On mobile: collapsible hamburger menu (shows/hides on tap)\n- Current page highlighted\n- Active section expanded (nested menus)\n\nResponsiveness:\n- Desktop: sidebar fixed left 256px width, main content flows right\n- Mobile: hamburger icon top-left, overlay sidebar (z-50), close on nav click\n\nTheme:\n- Light: bg-gray-50, text-gray-900, active bg-blue-100\n- Dark: bg-slate-800, text-gray-50, active bg-blue-900\n\nDefinition of done:\n- [ ] Sidebar renders correctly at all breakpoints.\n- [ ] Mobile hamburger collapses/expands.\n- [ ] Menu items filtered by user role.\n- [ ] Current page highlighted.\n- [ ] Theme colors correct (light + dark).\n- [ ] Component tests for menu filtering + collapse behavior.\n'

# create_issue "$FE_REPO" \
# "JOB-5: Refactor existing pages to use new layout (header + sidebar + content area)" \
# "jobsenn" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:ui, dev:jobsenn\n\nGoal:\nAdapt all dashboard pages to new unified layout structure.\n\nPages to refactor:\n- src/app/(dashboard)/student/dashboard/page.tsx → StudentDashboard layout\n- src/app/(dashboard)/publisher/dashboard/page.tsx → PublisherDashboard layout\n- src/app/(dashboard)/admin/dashboard/page.tsx → AdminDashboard layout\n- src/app/(dashboard)/courses/page.tsx\n- src/app/(dashboard)/sessions/page.tsx\n- src/app/(dashboard)/settings/page.tsx\n\nLayout pattern:\n```\n<Layout>\n  <Header />\n  <div className=\"flex\">\n    <Sidebar />\n    <main className=\"flex-1 p-4 md:p-8\">\n      {children}\n    </main>\n  </div>\n</Layout>\n```\n\nEach page:\n- Removes hardcoded nav (uses Sidebar)\n- Responsive padding (p-4 on mobile, p-8 on desktop)\n- Proper spacing between sections\n- Mobile-optimized card layouts\n\nDefinition of done:\n- [ ] All pages use new layout (no duplicate navs).\n- [ ] Content area responsive (proper padding/margins on all breakpoints).\n- [ ] No layout shift when navigating between pages.\n- [ ] Page load smooth + sidebar state preserved.\n'

# # ============================================
# # SEIDU — Avatar & HeyGen Integration (Frontend)
# # ============================================

# create_issue "$FE_REPO" \
# "SEIDU-1: HeyGen Streaming Avatar component + SDK integration" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:avatar, dev:ss20675-beep\n\nGoal:\nBuild HeyGen Streaming Avatar wrapper component (§6, §5.2).\n\nImplementation:\n- src/components/avatar/HeyGenStreaming.tsx (new)\n  └── Wraps HeyGen Streaming Avatar SDK\n  └── Props: avatar_id, session_language, quality\n  └── Methods: speak(text), interrupt(), stop()\n  └── Error handling: network failure, auth failure\n\n- src/hooks/useHeyGenAvatar.ts (new)\n  └── Manages HeyGen connection lifecycle\n  └── Auto-reconnect on disconnect\n  └── Cleanup on unmount\n\n- src/services/heygenConnection.ts (new)\n  └── Initializes SDK with NEXT_PUBLIC_HEYGEN_API_KEY\n  └── Event handlers (ready, error, speaking)\n\nInstallation:\n- npm install @heygen/streaming-avatar\n- Add NEXT_PUBLIC_HEYGEN_API_KEY to .env.local (public, safe for browser)\n\nUsage in TeachingInterface:\n```jsx\nconst heygenAvatar = useHeyGenAvatar(heygen_avatar_id);\n\nonRealtimeEvent((event) => {\n  if (event.type === "response.text.delta\") {\n    heygenAvatar.speak(event.delta.text);\n  }\n});\n```\n\nDefinition of done:\n- [ ] HeyGenStreaming component renders <video> element.\n- [ ] SDK initializes on mount, connects successfully.\n- [ ] speak() method works (text → lip-sync video).\n- [ ] Errors handled gracefully (fallback: transcript-only mode).\n- [ ] Component tests with mock SDK.\n'

# create_issue "$FE_REPO" \
# "SEIDU-2: Avatar persona switcher control + role selection UI (publisher-only)" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:avatar, dev:ss20675-beep\n\nGoal:\nBuild persona switcher for publishers (§7).\n\nImplementation:\n- src/components/avatar/PersonaSwitcher.tsx (new)\n  └── Dropdown or pill buttons showing available roles\n  └── Click role → PATCH /api/sessions/{id}/role\n  └── Display current role highlighted\n  └── Show HeyGen avatar thumbnail/name per role\n\n- Add to TeachingInterface (publisher view only)\n  └── Control panel above video\n  └── Hidden from subscriber view\n\nFlow:\n1. Session starts, selected_role_id known\n2. PersonaSwitcher displays all available roles from avatar template\n3. Publisher clicks "Switch to Gentleman"\n4. Frontend: PATCH /api/sessions/{id}/role { role_id: \"...\" }\n5. Backend returns new heygen_avatar_id\n6. Frontend: heygenAvatar.stopAvatar() + create new with new avatar_id\n7. Brief transition animation (fade out → fade in)\n\nUI:\n- Compact layout (horizontal pill buttons on desktop, dropdown on mobile)\n- Current role highlighted with blue background\n- Show avatar name + optional thumbnail (if heygen_avatar_id maps to image)\n\nDefinition of done:\n- [ ] Switcher renders available roles.\n- [ ] Click triggers PATCH endpoint correctly.\n- [ ] HeyGen avatar switches smoothly (brief pause acceptable).\n- [ ] Hidden from subscriber view (role check in component).\n- [ ] Component tests for UI + API call.\n'

# create_issue "$FE_REPO" \
# "SEIDU-3: Floating avatar panel + minimize/expand + session state persistence" \
# "ss20675-beep" \
# "feature" \
# $'Priority: MEDIUM\nIntended Project Column: Backlog\nIntended labels: feature, priority:medium, area:avatar, dev:ss20675-beep\n\nGoal:\nImplement persistent floating avatar UI (Client 1 requirement — §12.3).\n\nImplementation:\n- src/components/avatar/FloatingAvatarPanel.tsx (new)\n  └── Always-on-screen widget (bottom-right corner by default)\n  └── Minimize button (collapse to just avatar thumbnail)\n  └── Expand button (show full video + controls)\n  └── Close button (ends session)\n\n- src/contexts/FloatingAvatarContext.tsx (new)\n  └── Global state: isMinimized, isPanelOpen, currentSession\n  └── Persists minimize state to localStorage\n\n- Mount FloatingAvatarPanel in root layout (src/app/layout.tsx)\n  └── Always rendered, hidden when no active session\n\nUI states:\n- Hidden: no active session\n- Minimized: thumbnail + badge (e.g., "In Session")\n- Expanded: full video + persona switcher + end session button\n\nResponsiveness:\n- Desktop: 360px wide panel, bottom-right (safe from scroll bar)\n- Tablet: 320px wide, adjust position if keyboard visible\n- Mobile: full-screen by default when expanded (not floating)\n\nBehavior:\n- Minimize does NOT pause session (HeyGen keeps playing)\n- Session continues in background when minimized\n- Unmount on session end or close click\n\nDefinition of done:\n- [ ] Panel renders correctly at all breakpoints.\n- [ ] Minimize state persists across page navigation.\n- [ ] Session continues when minimized (voice still plays).\n- [ ] No layout shift when panel unmounts.\n- [ ] Component tests for state management.\n'

# create_issue "$FE_REPO" \
# "SEIDU-4: Ephemeral token endpoint integration + pass heygen_avatar_id to HeyGen SDK" \
# "ss20675-beep" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:rag, dev:ss20675-beep\n\nGoal:\nWire ephemeral token response into HeyGen initialization (§6.3).\n\nFlow:\n1. Frontend: GET /api/session/ephemeral?session_id={id}&session_run_id={runId}\n2. Backend returns:\n   {\n     "openai_token": "...",\n     "heygen_avatar_id": "emirati_lady_001",\n     "heygen_quality": "high",\n     "session_language": "ar",\n     "session_mode": "teaching\"\n   }\n3. Frontend: initialize both OpenAI Realtime + HeyGen with responses\n\nImplementation:\n- Modify src/hooks/useRealtimeAPI.ts (or equivalent)\n  └── When ephemeral token received, extract heygen fields\n  └── Pass to useHeyGenAvatar(heygen_avatar_id, quality, language)\n\n- src/services/sessionService.ts (new or updated)\n  └── Fetch ephemeral token\n  └── Parse response (both openai_token + heygen fields)\n  └── Return structured object\n\nError handling:\n- If heygen_avatar_id is null: fallback to transcript-only (no video)\n- If HeyGen init fails: continue with audio-only (OpenAI Realtime still works)\n\nDefinition of done:\n- [ ] Ephemeral token endpoint called correctly.\n- [ ] heygen_avatar_id extracted + passed to SDK.\n- [ ] HeyGen avatar initializes with correct ID.\n- [ ] Fallback to audio-only if HeyGen unavailable.\n- [ ] Integration test: full session start (token → avatar render).\n'

# # ============================================
# # ELENI — Course + Session Frontend
# # ============================================

# create_issue "$FE_REPO" \
# "ELENI-1: Course management pages (create, edit, list, enroll)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:courses, dev:eleni\n\nGoal:\nBuild course management UI for publishers.\n\nPages:\n- src/app/(dashboard)/publisher/courses/page.tsx (list)\n- src/app/(dashboard)/publisher/courses/[id]/page.tsx (detail + edit)\n- src/app/(dashboard)/publisher/courses/new/page.tsx (create)\n- src/app/(dashboard)/publisher/courses/[id]/enrollment/page.tsx (manage students)\n\nFeatures:\n- Create/edit: name, description, code, department, semester, is_public toggle\n- List: filter by avatar, search by name\n- Enroll: single invite or bulk upload (CSV: email, access_level)\n- Unenroll: remove students from course\n\nComponents:\n- src/components/courses/CourseForm.tsx (create/edit form)\n- src/components/courses/CourseCard.tsx (list view card)\n- src/components/courses/EnrollmentTable.tsx (students list)\n- src/components/courses/BulkEnrollDialog.tsx (CSV upload modal)\n\nHooks:\n- src/hooks/useCourses.ts (GET /api/courses, POST/PATCH)\n- src/hooks/useCourseEnrollment.ts (POST enroll, DELETE unenroll, GET students)\n\nBFF routes:\n- src/app/api/courses/route.ts (GET/POST)\n- src/app/api/courses/[id]/route.ts (GET/PATCH)\n- src/app/api/courses/[id]/enroll/route.ts (POST/DELETE)\n- src/app/api/courses/[id]/enroll-bulk/route.ts (POST)\n\nDefinition of done:\n- [ ] CRUD flows work end-to-end (create → edit → list → delete).\n- [ ] Bulk enrollment CSV upload works (handles 500+ users).\n- [ ] Forms responsive on mobile.\n- [ ] Validation: required fields, email format, CSV parsing.\n- [ ] Component tests for forms + table.\n'

# create_issue "$FE_REPO" \
# "ELENI-2: Session creation workflow (upload slides, configure mode/role, publish)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:sessions, dev:eleni\n\nGoal:\nBuild session creation wizard for publishers.\n\nFlow:\n1. Step 1: Select course + avatar\n2. Step 2: Upload presentation (PDF/PPTX)\n3. Step 3: Configure session (name, mode, role, is_active)\n4. Step 4: Review + publish\n\nImplementation:\n- src/app/(dashboard)/publisher/sessions/new/page.tsx (wizard)\n- src/components/sessions/SessionWizard.tsx (multi-step form)\n- src/components/sessions/SlideUploader.tsx (file upload)\n- src/components/sessions/SessionConfigForm.tsx (mode/role selection)\n\nHooks:\n- src/hooks/useSessions.ts (POST /api/sessions, PATCH /api/sessions/{id})\n- src/hooks/useFileUpload.ts (multipart upload to /api/upload)\n\nBFF routes:\n- src/app/api/sessions/route.ts (POST create)\n- src/app/api/sessions/[id]/route.ts (PATCH update)\n- src/app/api/upload/route.ts (file upload handler — proxies to backend)\n\nUI:\n- Wizard steps with progress indicator\n- File upload with progress bar\n- Mode toggle (teaching ↔ examination)\n- Role dropdown (populated from avatar template)\n\nValidation:\n- File type (PDF/PPTX only)\n- File size (<52 MB)\n- Session name required\n- At least one slide after upload\n\nDefinition of done:\n- [ ] Wizard flows smoothly through all 4 steps.\n- [ ] File upload works + shows progress.\n- [ ] Mode/role selection reflects API options.\n- [ ] Session created + appears in list after publish.\n- [ ] Component tests for wizard state + file upload.\n'

# create_issue "$FE_REPO" \
# "ELENI-3: Subscriber course browsing + enrollment (public courses + access codes)" \
# "eleni" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:courses, dev:eleni\n\nGoal:\nBuild marketplace/browse experience for subscribers.\n\nPages:\n- src/app/(dashboard)/subscriber/marketplace/page.tsx (browse public courses)\n- src/app/(dashboard)/subscriber/my-courses/page.tsx (enrolled courses)\n- src/app/(dashboard)/subscriber/my-courses/[id]/sessions/page.tsx (session list for course)\n\nFeatures:\n- Browse: filter by avatar, search by name, pagination\n- Course card: title, description, avatar, session count, enroll button\n- Self-enroll: one-click (if free/public)\n- Enroll with access code: input field to redeem code\n- My courses: list enrolled courses, show progress\n\nComponents:\n- src/components/courses/CourseMarketplaceCard.tsx (browse card)\n- src/components/courses/EnrollmentButton.tsx (self-enroll)\n- src/components/courses/AccessCodeRedemption.tsx (code input modal)\n- src/components/courses/MyCoursesList.tsx (enrolled courses)\n\nHooks:\n- src/hooks/usePublicCourses.ts (GET /api/courses?is_public=true)\n- src/hooks/useEnrolledCourses.ts (GET /api/courses?enrolled=true)\n- src/hooks/useEnrollment.ts (POST /api/courses/{id}/enroll)\n- src/hooks/useAccessCode.ts (POST /api/billing/redeem)\n\nBFF routes:\n- src/app/api/courses/public/route.ts (GET public courses)\n- src/app/api/courses/[id]/enroll/route.ts (POST self-enroll)\n- src/app/api/billing/redeem/route.ts (POST redeem code)\n\nUI:\n- Light/dark theme support\n- Responsive grid (1 col mobile, 2 tablet, 3+ desktop)\n- Course cards show avatar thumbnail + role\n\nDefinition of done:\n- [ ] Browse public courses works (filters + search).\n- [ ] Self-enroll button functional.\n- [ ] Access code redemption modal works.\n- [ ] My courses list shows correct enrollments.\n- [ ] Component tests for browse + enrollment flows.\n'

# create_issue "$FE_REPO" \
# "ELENI-4: Teaching interface (publish-side) — real-time session control + student view" \
# "eleni" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:critical, area:sessions, dev:eleni\n\nGoal:\nBuild the main teaching/learning interface (§4.2).\n\nImplementation:\n- src/app/(dashboard)/publisher/sessions/[id]/teach/page.tsx (publisher teaching view)\n- src/app/(dashboard)/subscriber/sessions/[id]/learn/page.tsx (subscriber learning view)\n- src/components/sessions/TeachingInterface.tsx (unified component, role-aware)\n\nPublisher view includes:\n- Large video area (HeyGen avatar + optional webcam overlay)\n- Slide deck preview (side panel)\n- Persona switcher control\n- Session timer + end button\n- Transcript panel\n- Control bar: mute, record, pause\n\nSubscriber view includes:\n- Video area (HeyGen avatar only, full-screen)\n- Slide preview (side)\n- Transcript (bottom scrollable)\n- Feedback buttons (thumbs up / flag incorrect on messages)\n- Session controls: mute mic, end session\n\nShared:\n- OpenAI Realtime WebRTC connection\n- HeyGen Streaming Avatar video\n- Transcript rendering (both roles see it)\n- Auto-reconnect on network failure\n\nResponsiveness:\n- Desktop: 2-column layout (video left, slides right)\n- Tablet: stacked vertically\n- Mobile: video full-screen with minimizable slide panel\n\nDefinition of done:\n- [ ] Video + audio working (OpenAI Realtime connected).\n- [ ] HeyGen avatar rendering.\n- [ ] Slide deck visible + navigable.\n- [ ] Transcript updates in real-time.\n- [ ] Publisher can switch personas.\n- [ ] Subscriber can rate/flag messages.\n- [ ] Responsive at all breakpoints.\n- [ ] Component tests for control flows.\n'

# # ============================================
# # CHEN — Authentication Frontend (Registration, Login, Forgot Password)
# # ============================================

# create_issue "$FE_REPO" \
# "CHEN-1: Enhanced registration form (password strength, terms checkbox, email verification)" \
# "chen" \
# "feature" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: feature, priority:critical, area:auth, dev:chen\n\nGoal:\nUpgrade registration UI with security + UX (§12 reference).\n\nImplementation:\n- src/app/(auth)/register/page.tsx (refactor existing)\n- src/components/auth/RegistrationForm.tsx (new)\n\nForm fields:\n- Email (required, validated)\n- Password (required, with strength meter)\n- Confirm password (must match)\n- First name (required)\n- Last name (required)\n- Agree to terms (required checkbox) ← NEW\n- Subscribe to updates (optional checkbox)\n\nPassword strength meter:\n- Show real-time validation:\n  ✓ Minimum 12 characters\n  ✓ Uppercase letter\n  ✓ Lowercase letter\n  ✓ Number\n  ✓ Special character (!@#$%^&*)\n  ✗ Common password (if detected)\n  ✗ Similar to email/name (if detected)\n- Color-coded: red (weak) → yellow (medium) → green (strong)\n\nTerms checkbox:\n- Link to /terms-of-service\n- Link to /privacy-policy\n- Must be checked to enable Submit button\n\nFlow:\n1. Fill form + check terms\n2. Submit → POST /api/auth/register\n3. Show spinner + \"Checking availability...\"\n4. On success: show \"Check your email for verification link\"\n5. Auto-redirect to /verify-email page (optional resend link)\n\nValidation (client-side, mirrored on backend):\n- Email format (RFC 5322)\n- Password strength (12 char min + complexity)\n- Passwords match\n- Terms checkbox checked\n\nUI:\n- Responsive form (full-width on mobile, 400px on desktop)\n- Light/dark theme support\n- Clear error messages (no generic \"Invalid input\")\n- Loading state: disabled submit + spinner\n\nDefinition of done:\n- [ ] Password strength meter works real-time.\n- [ ] Terms checkbox required (Submit disabled if unchecked).\n- [ ] Client-side validation mirrors backend.\n- [ ] Error messages clear + helpful.\n- [ ] Form responsive at all breakpoints.\n- [ ] Component tests for validation + submission.\n'

# create_issue "$FE_REPO" \
# "CHEN-2: Email verification page + resend verification link" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nBuild email verification flow (post-registration).\n\nImplementation:\n- src/app/(auth)/verify-email/page.tsx (new)\n- src/components/auth/EmailVerificationPanel.tsx (new)\n\nFlow:\n1. User registers → auto-redirects to /verify-email\n2. Shows message: "Check your email. Click the link to verify your account."\n3. Shows countdown timer (if resend available after 30s)\n4. "Resend verification link" button (disabled until timer expires)\n5. User clicks email link (from backend email) → navigates to /verify-email?token=...\n6. Page auto-verifies token + auto-logs user in\n7. Redirects to onboarding OR dashboard\n\nURL handling:\n- /verify-email (no token): show "Check email" message\n- /verify-email?token=xyz: auto-verify + auto-login + redirect\n\nImplementation:\n- src/app/api/auth/verify-email/route.ts (BFF for token verification)\n- Call backend POST /api/auth/verify-email?token=... (backend validates token from DB)\n- Extract auth token from response → store in localStorage → redirect\n\nUI:\n- Center-aligned, simple layout\n- Email icon + message\n- Resend button (disabled until timer)\n- Timer countdown: "Resend available in 25 seconds"\n- Optional: show email address (user@example.com)\n\nError handling:\n- Expired token: show "Link expired. Click here to request new link."\n- Invalid token: show "Invalid verification link."\n\nDefinition of done:\n- [ ] Verification page renders correctly.\n- [ ] Auto-verify on token query param works.\n- [ ] Resend button respects 30s cooldown.\n- [ ] Auto-login after verification.\n- [ ] Error handling for expired/invalid tokens.\n- [ ] Component tests for verification flow.\n'

# create_issue "$FE_REPO" \
# "CHEN-3: Enhanced login form (username OR email + password, username/email validation)" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nUpgrade login to accept email or username (§12 reference).\n\nImplementation:\n- src/app/(auth)/login/page.tsx (refactor existing)\n- src/components/auth/LoginForm.tsx (update)\n\nForm fields:\n- Username or email (new label, single field)\n- Password (existing)\n- "Remember me" checkbox (optional, stores 7-day token)\n\nFlow:\n1. Enter email OR username + password\n2. Submit → POST /api/auth/login { \"username_or_email\": \"...\", \"password\": \"...\" }\n3. Backend determines if input is email or username\n4. Returns auth token (if credentials valid)\n5. Store in localStorage + redirect to /dashboard\n\nValidation (client-side):\n- username_or_email not empty\n- password not empty\n- If input contains @: validate as email (basic check)\n- If input doesn\'t contain @: validate as username (alphanumeric + hyphens)\n\nUI:\n- Form label: "Username or email" (helper text: "Enter your username or email address")\n- Password field (toggle show/hide with icon)\n- "Forgot password?" link below password\n- "Remember me" checkbox (optional)\n- Submit button: "Sign in"\n- Link to register: "Don\'t have an account? Sign up"\n\nError handling:\n- 401 Unauthorized: "Invalid username/email or password."\n- Account not verified: "Your email has not been verified. Check your inbox."\n- Account locked (optional): "Too many login attempts. Try again in 15 minutes."\n\nDefinition of done:\n- [ ] Login accepts both email + username.\n- [ ] Form validation works (email vs username).\n- [ ] Remember me checkbox (if enabled, extends session TTL).\n- [ ] Error messages clear.\n- [ ] Form responsive.\n- [ ] Component tests for both email + username paths.\n'

# create_issue "$FE_REPO" \
# "CHEN-4: Forgot password workflow (request reset link + reset form)" \
# "chen" \
# "feature" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: feature, priority:high, area:auth, dev:chen\n\nGoal:\nBuild password recovery UX (§12 reference).\n\nImplementation:\n- src/app/(auth)/forgot-password/page.tsx (new)\n- src/app/(auth)/reset-password/page.tsx (new)\n- src/components/auth/ForgotPasswordForm.tsx (request form)\n- src/components/auth/ResetPasswordForm.tsx (reset form)\n\nPage 1: Forgot Password (/forgot-password)\n- Form field: email\n- Submit: POST /api/auth/forgot-password { \"email\": \"...\" }\n- On success: show message\n  "If an account exists with this email, you will receive a password reset link."\n  (Never reveal if email exists — same message always)\n- Show: \"Didn\'t receive an email? Check spam folder or try another account.\"\n- Optional: link back to login\n\nPage 2: Reset Password (/reset-password?token=xyz)\n- Auto-extract token from URL\n- Show message: \"Enter your new password to regain access to your account.\"\n- Form fields:\n  - New password (with strength meter, same rules as registration)\n  - Confirm password\n- Submit: POST /api/auth/reset-password { \"token\": \"...\", \"new_password\": \"...\" }\n- On success: show message + auto-redirect to login in 3 seconds\n  "Password reset successful. Redirecting to login...\"\n- On error (expired token): show \"This link has expired. Request a new one.\"\n  Link to /forgot-password\n\nImplementation:\n- src/app/api/auth/forgot-password/route.ts (BFF)\n- src/app/api/auth/reset-password/route.ts (BFF)\n- Calls backend endpoints (CHEN-4 on API side)\n\nUI:\n- Centered, simple layout\n- Progress indicator (forgot → reset)\n- Password strength meter on reset form\n- Clear copy (no jargon)\n\nDefinition of done:\n- [ ] Forgot password form works (submits email).\n- [ ] Success message shown (generic, no email enumeration).\n- [ ] Reset password page auto-extracts token from URL.\n- [ ] Reset form validates password strength.\n- [ ] Auto-redirect to login on success.\n- [ ] Expired token error handled.\n- [ ] Component tests for both forms.\n'

# echo ""
# echo "=========================================="
# echo "Creating LEAD issues"
# echo "=========================================="

# # ============================================
# # LEAD issues
# # ============================================

# create_issue "$API_REPO" \
# "LEAD: Create GitHub Project board + configure columns + automation rules (API repo)" \
# "$LEAD" \
# "chore" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: chore, priority:critical, area:ops\n\nGoal:\nSet up project management board for API repo.\n\nSteps:\n1. Go to mmedcon-tech/profsidekick-api → Projects tab\n2. Create new project (type: Table or Kanban)\n3. Create columns:\n   - Backlog\n   - Ready\n   - In Progress\n   - In Review\n   - Blocked\n   - Done\n\n4. Configure automation:\n   - New issues → Backlog\n   - PRs opened → In Review\n   - PRs merged → Done (optional)\n\n5. Add custom fields (optional):\n   - Priority (Critical/High/Medium/Low)\n   - Assignee filtering\n\n6. Share project view with team (public link)\n\nDefinition of done:\n- [ ] Project created + columns visible.\n- [ ] Team can drag issues between columns.\n- [ ] Automation working (new issues appear in Backlog).\n'

# create_issue "$FE_REPO" \
# "LEAD: Create GitHub Project board + configure columns + automation rules (Frontend repo)" \
# "$LEAD" \
# "chore" \
# $'Priority: CRITICAL\nIntended Project Column: Backlog\nIntended labels: chore, priority:critical, area:ops\n\nGoal:\nSet up project management board for Frontend repo.\n\nSteps:\n1. Go to mmedcon-tech/profsidekick-frontend → Projects tab\n2. Create new project (type: Table or Kanban)\n3. Create columns:\n   - Backlog\n   - Ready\n   - In Progress\n   - In Review\n   - Blocked\n   - Done\n\n4. Configure automation:\n   - New issues → Backlog\n   - PRs opened → In Review\n   - PRs merged → Done (optional)\n\n5. Add custom fields (optional):\n   - Priority (Critical/High/Medium/Low)\n   - Assignee filtering\n\n6. Share project view with team (public link)\n\nDefinition of done:\n- [ ] Project created + columns visible.\n- [ ] Team can drag issues between columns.\n- [ ] Automation working (new issues appear in Backlog).\n'

# create_issue "$API_REPO" \
# "LEAD: Create global label taxonomy for both repos" \
# "$LEAD" \
# "chore" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: chore, priority:high, area:ops\n\nGoal:\nCreate consistent labels across API + Frontend repos for filtering + reporting.\n\nLabels to create (in both repos):\n\nType:\n- feature\n- bug\n- chore\n- test\n\nPriority:\n- priority:critical\n- priority:high\n- priority:medium\n- priority:low\n\nArea (API repo):\n- area:auth\n- area:courses\n- area:sessions\n- area:subscriptions\n- area:avatar\n- area:rag\n- area:billing\n- area:ops\n- area:docs\n\nArea (Frontend repo):\n- area:auth\n- area:courses\n- area:sessions\n- area:avatar\n- area:ui\n- area:rag\n- area:billing\n- area:docs\n\nTeam:\n- dev:eleni\n- dev:seidu\n- dev:jobsenn\n- dev:chen\n- lead:required\n\nDefinition of done:\n- [ ] All labels created in both repos.\n- [ ] Consistent naming + colors across repos.\n- [ ] Team can filter by label in issues view.\n'

# create_issue "$API_REPO" \
# "LEAD: Design + document HeyGen avatar instances for Client 1 (UAE Government)" \
# "$LEAD" \
# "chore" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: chore, priority:high, area:avatar\n\nGoal:\nSet up HeyGen avatar IDs + personas for the reference client.\n\nWork:\n1. Decide HeyGen avatar tier (Photo Avatar recommended for speed)\n2. Procure Emirati female + male talent (photos or video)\n3. Create avatars in HeyGen portal:\n   - Avatar 1: \"Emirati Lady\" → capture avatar_id\n   - Avatar 2: \"Emirati Gentleman\" → capture avatar_id\n4. Document in internal wiki / Notion:\n   - Avatar names\n   - HeyGen avatar_ids\n   - Voice recommendations (Arabic, professional tone)\n   - Face description (for prompts)\n5. Create seed script or manual DB entries:\n   - avatar_template_roles.heygen_avatar_id values\n\nDeliverables:\n- [ ] Two HeyGen avatar instances live in test environment\n- [ ] avatar_ids documented + stored in config\n- [ ] Local testing: can initialize HeyGen with these IDs\n- [ ] Screenshot: both avatars rendering on dev machine\n'

# create_issue "$FE_REPO" \
# "LEAD: Set up HeyGen SDK testing environment + document integration" \
# "$LEAD" \
# "chore" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: chore, priority:high, area:avatar\n\nGoal:\nPrepare frontend for HeyGen Streaming Avatar integration.\n\nWork:\n1. Create HeyGen test account (if not already done)\n2. Generate test avatar_id (can use HeyGen demo avatar for initial testing)\n3. Document HeyGen SDK setup:\n   - npm install @heygen/streaming-avatar\n   - API key management (NEXT_PUBLIC_HEYGEN_API_KEY in .env.local)\n   - Basic SDK initialization example\n4. Create example code:\n   - src/examples/heygenBasicUsage.tsx (pseudocode for team reference)\n5. Set up error handling + fallback (if HeyGen unavailable → audio-only mode)\n\nDeliverables:\n- [ ] HeyGen SDK installed locally\n- [ ] Test avatar_id working in browser console\n- [ ] Documentation + example code reviewed by team\n- [ ] Integration checklist for SEIDU-1 task\n'

# create_issue "$API_REPO" \
# "LEAD: Database migration planning + execution strategy (avoid conflicts)" \
# "$LEAD" \
# "chore" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: chore, priority:high, area:ops\n\nGoal:\nCoordinate database migrations across four devs to avoid conflicts.\n\nStrategy:\n1. Maintain a migration order log (shared doc):\n   - ELENI: course + enrollment migrations (first)\n   - SEIDU: avatar role + language migrations (second)\n   - CHEN: registration fields + password reset migrations (third)\n   - Others: remaining migrations\n\n2. Before each migration:\n   - Announce in Slack (e.g., \"ELENI starting course migration\")\n   - Ensure all team members have pulled latest main\n   - No parallel migrations\n\n3. After each migration:\n   - Commit alembic upgrade output to git\n   - Update MIGRATION_LOG.md with status\n   - Signal next dev to proceed\n\n4. Conflict resolution (if needed):\n   - Rebase alembic history (dangerous — discuss first)\n   - Or add manual migration step to reconcile\n\nDefinition of done:\n- [ ] Migration order documented.\n- [ ] Team briefed on coordination rules.\n- [ ] First developer (ELENI) can start without blocking.\n'

# create_issue "$FE_REPO" \
# "LEAD: Responsive design + theme audit (light/dark mode + all breakpoints)" \
# "$LEAD" \
# "chore" \
# $'Priority: HIGH\nIntended Project Column: Backlog\nIntended labels: chore, priority:high, area:ui\n\nGoal:\nAudit entire app for responsive layout + theme compliance before dev sprints.\n\nAudit checklist:\n- [ ] All pages tested at 375px (mobile), 768px (tablet), 1920px (desktop)\n- [ ] Light mode: all pages readable + colors correct\n- [ ] Dark mode: all pages readable + colors correct\n- [ ] Text contrast >= 4.5:1 (WCAG AA)\n- [ ] Touch targets >= 44px (mobile-friendly)\n- [ ] No horizontal scrolling on mobile\n- [ ] Images scale responsively\n- [ ] Forms stack properly\n- [ ] Sidebar collapses on mobile\n\nPages to audit:\n- /auth (login, register, forgot-password, verify-email, reset-password)\n- /dashboard (all role variants)\n- /courses (browse, detail, manage)\n- /sessions (create, list, teach, learn)\n- /settings (all cards)\n\nOutput:\n- [ ] Screenshot comparison (mobile, tablet, desktop, light + dark)\n- [ ] Bug list for JOB-2 + JOB-3 tasks\n- [ ] Tailwind class recommendations (responsive prefixes)\n\nDefinition of done:\n- [ ] Audit complete.\n- [ ] Screenshots documented.\n- [ ] Issues filed for responsive breaks.\n'

# echo ""
# echo "=========================================="
# echo "✅ All issues created successfully!"
# echo "=========================================="
# echo ""
# echo "Next steps:"
# echo "1. Create GitHub Project boards (LEAD tasks)"
# echo "2. Create labels (LEAD task)"
# echo "3. Drag issues to 'Ready' column if they\'re unblocked"
# echo "4. Team members start picking up 'Ready' issues"
# echo ""
# echo "Verify with:"
# echo "  gh issue list -R $API_REPO --limit 300"
# echo "  gh issue list -R $FE_REPO --limit 300"
# echo ""

#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail

API_REPO="mmedcon-tech/profsidekick-api"
FE_REPO="mmedcon-tech/profsidekick-frontend"

sleep_between_creates_seconds=1

create_milestone() {
  local repo="$1"
  local title="$2"
  local description="$3"
  local due_date="$4"

  echo "Creating milestone: [$repo] $title (due: $due_date)"
  gh api -X POST "repos/$repo/milestones" \
    -f title="$title" \
    -f description="$description" \
    -f due_on="${due_date}T00:00:00Z"
  sleep "$sleep_between_creates_seconds"
}

echo "=========================================="
echo "Creating Milestones for ProfSidekick"
echo "Tuesday, June 9, 2026 - Complete Avatar, Courses & Sessions Workflows"
echo "=========================================="
echo ""

# SINGLE MILESTONE: Complete Avatar, Courses & Sessions Workflows (Tuesday, June 9, 2026)
echo "🎯 MILESTONE: Avatar, Courses & Sessions Integration (Tue, Jun 9, 2026)"
create_milestone "$API_REPO" \
  "M1: Avatar, Courses & Sessions Integration (Tue, Jun 9)" \
  "Complete end-to-end workflows for avatar management, course creation/enrollment, and session lifecycle.

## WHAT MUST BE DONE BY TUESDAY, JUNE 9, 2026

### 🧑‍🎓 Avatar & Persona Management (Seidu)

**Backend (API):**
- Avatar template roles with HeyGen integration
  - [ ] Add heygen_avatar_id, heygen_voice_id, default_language to avatar_template_roles
  - [ ] Alembic migration: add_heygen_fields_to_roles
  - [ ] Seed two default roles: \"Emirati Lady\" + \"Emirati Gentleman\" with placeholder HeyGen IDs
  
- Session language preference + ephemeral tokens
  - [ ] Add preferred_language to sessions table
  - [ ] Modify openai_service.get_ephemeral_token() to:
    - Look up selected_role_id → get heygen_avatar_id
    - Return in response: { openai_token, heygen_avatar_id, heygen_quality, session_language, session_mode }
  
- Avatar persona switching mid-session
  - [ ] PATCH /api/sessions/{id}/role endpoint
  - [ ] Validates publisher owns session
  - [ ] Updates sessions.selected_role_id
  - [ ] Returns new heygen_avatar_id for frontend
  - [ ] Audit log: session_persona_switches table

**Frontend (UI/UX):**
- HeyGen Streaming Avatar component
  - [ ] src/components/avatar/HeyGenStreaming.tsx wraps SDK
  - [ ] Initializes with avatar_id, language, quality
  - [ ] Methods: speak(text), interrupt(), stop()
  - [ ] Error handling: fallback to audio-only if HeyGen unavailable
  
- Avatar persona switcher (publisher-only)
  - [ ] src/components/avatar/PersonaSwitcher.tsx
  - [ ] Shows available roles in dropdown or pill buttons
  - [ ] Click role → PATCH /api/sessions/{id}/role
  - [ ] Smooth HeyGen transition (stop current → start new)
  - [ ] Hidden from subscriber view
  
- Floating avatar panel
  - [ ] src/components/avatar/FloatingAvatarPanel.tsx (bottom-right corner)
  - [ ] Minimize → shows only thumbnail
  - [ ] Expand → shows full video + controls
  - [ ] Close → ends session
  - [ ] Minimize state persists to localStorage
  - [ ] Mobile: full-screen when expanded
  
- Ephemeral token integration
  - [ ] GET /api/session/ephemeral response parsed
  - [ ] heygen_avatar_id extracted → passed to HeyGenStreaming
  - [ ] Both OpenAI Realtime + HeyGen initialized together
  - [ ] Fallback to transcript-only if HeyGen fails

---

### 📚 Courses Management (Eleni)

**Backend (API):**
- Course CRUD endpoints
  - [ ] POST /api/courses (create: name, description, code, department, semester, is_public)
  - [ ] GET /api/courses (list with filters: avatar_id, is_public, user_id)
  - [ ] GET /api/courses/{id} (detail)
  - [ ] PATCH /api/courses/{id} (update: is_public, description)
  - [ ] DELETE /api/courses/{id} (soft delete or hard delete)
  
- Course privacy model
  - [ ] courses.is_public (boolean)
  - [ ] GET /api/courses filters by: is_public=true OR user_id=current_user OR enrolled
  - [ ] Private courses only visible to enrolled subscribers + publisher
  - [ ] Service layer enforces: course_service.get_courses() filters by user role
  
- Course enrollment management
  - [ ] POST /api/courses/{id}/enroll (single: subscriber self-enrolls)
  - [ ] POST /api/courses/{id}/enroll-bulk (bulk: CSV/JSON with emails)
  - [ ] GET /api/courses/{id}/students (list enrolled students)
  - [ ] DELETE /api/courses/{id}/students/{user_id} (unenroll)
  - [ ] Bulk enrollment handles 500+ users without N+1 queries

**Frontend (UI/UX):**
- Course browsing (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/marketplace/page.tsx
  - [ ] List public courses with filters: avatar, search, pagination
  - [ ] Course cards: title, description, avatar thumbnail, session count
  - [ ] Self-enroll button (one-click for free/public)
  - [ ] Access code input modal (redeem code to enroll)
  
- My courses (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/my-courses/page.tsx
  - [ ] List enrolled courses with progress bars
  - [ ] Click course → view sessions list
  
- Course management (publisher view)
  - [ ] src/app/(dashboard)/publisher/courses/page.tsx (list)
  - [ ] src/app/(dashboard)/publisher/courses/new/page.tsx (create wizard)
  - [ ] src/app/(dashboard)/publisher/courses/[id]/page.tsx (edit)
  - [ ] Create form: name, description, code, department, semester, is_public toggle
  - [ ] Validate: required fields, unique course code
  
- Course enrollment UI (publisher)
  - [ ] src/app/(dashboard)/publisher/courses/[id]/enrollment/page.tsx
  - [ ] List enrolled students (table: email, joined_at, status)
  - [ ] Single invite: input email → send invite link
  - [ ] Bulk upload: CSV modal (email, access_level)
  - [ ] Unenroll button per student
  - [ ] BFF routes: POST /api/courses/[id]/enroll, POST /api/courses/[id]/enroll-bulk, DELETE /api/courses/[id]/students/[user_id]

---

### 🎬 Sessions & Teaching Interface (Eleni + Seidu)

**Backend (API):**
- Session lifecycle endpoints
  - [ ] POST /api/sessions (create: course_id, avatar_id, name, session_mode, selected_role_id, is_active)
  - [ ] GET /api/sessions/{id} (detail: includes slides_details, preferred_language, selected_role_id)
  - [ ] PATCH /api/sessions/{id}/mode (switch: teaching ↔ examination)
  - [ ] PATCH /api/sessions/{id}/role (switch avatar role — already in SEIDU tasks)
  - [ ] POST /api/sessions/{id}/run/start (create session_run record, check subscriptions + enrollment)
  - [ ] POST /api/sessions/{id}/run/stop (end session, save transcript, trigger AI summary)
  
- Session modes (teaching vs examination)
  - [ ] sessions.session_mode (enum: teaching, examination)
  - [ ] Ephemeral token injects mode-specific prompt:
    - teaching: uses teaching_prompt from template
    - examination: uses examination_prompt from template
  - [ ] Frontend UI different for each mode (assessment widget for exam)
  
- Subscription validation before session start (§8.3 Five Checkpoints)
  - [ ] Before ephemeral token issued, validate:
    1. user.role == subscriber
    2. avatar_subscriptions exists + is_active
    3. course_students enrollment exists
    4. session.is_active == true
    5. Privacy check (is_public OR authorized)
  - [ ] If any fail: 403 Forbidden (generic message)
  - [ ] Implementation: openai_service.get_ephemeral_token() calls subscription_service.validate_session_access()

**Frontend (UI/UX):**
- Session creation wizard (publisher)
  - [ ] src/app/(dashboard)/publisher/sessions/new/page.tsx (multi-step wizard)
  - [ ] Step 1: Select course + avatar
  - [ ] Step 2: Upload presentation (PDF/PPTX)
    - File upload with progress bar
    - Backend: file_processor.py converts to images, extracts slides
    - Returns: slide count, thumbnails
  - [ ] Step 3: Configure session
    - Session name (required)
    - Session mode toggle (teaching ↔ examination)
    - Avatar role selector (dropdown: Emirati Lady / Emirati Gentleman)
    - is_active toggle (publish immediately or draft)
  - [ ] Step 4: Review + publish
  - [ ] BFF route: POST /api/sessions with multipart file upload
  
- Teaching interface (publisher view)
  - [ ] src/app/(dashboard)/publisher/sessions/[id]/teach/page.tsx
  - [ ] Layout: large video left, slide deck preview right (responsive stack on mobile)
  - [ ] Video area: HeyGen avatar + optional webcam overlay
  - [ ] Persona switcher control (PersonaSwitcher component)
  - [ ] Slide navigation: prev/next buttons, slide counter
  - [ ] Transcript panel: scrollable, shows subscriber messages + AI responses
  - [ ] Control bar: mute mic, record (future), pause, end session button
  - [ ] Session timer + status
  - [ ] Connected to OpenAI Realtime WebRTC
  
- Learning interface (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/sessions/[id]/learn/page.tsx
  - [ ] Layout: similar to teaching but simpler (no persona switcher, no webcam)
  - [ ] Video area: HeyGen avatar full-featured
  - [ ] Slide preview: minimizable on mobile
  - [ ] Transcript: read-only messages, can flag/rate responses
  - [ ] Controls: mute mic, end session
  - [ ] Post-session: rating modal (5-star feedback)
  - [ ] Connected to OpenAI Realtime WebRTC (ephemeral token)
  
- Responsive TeachingInterface component
  - [ ] src/components/sessions/TeachingInterface.tsx (role-aware wrapper)
  - [ ] Desktop: 2-column (video left 60%, slides right 40%)
  - [ ] Tablet: stacked vertically (video top, slides bottom)
  - [ ] Mobile: video full-screen with minimizable slide panel
  - [ ] Dark/light theme support
  - [ ] No horizontal scroll at any breakpoint

---

### 🔗 Data Integrations & Workflows

**Backend Database:**
- [ ] Alembic migrations applied (in order, no parallel):
  1. add_heygen_fields_to_roles (Seidu)
  2. add_language_and_role_to_sessions (Seidu)
  3. add_course_tables (Eleni)
  4. add_session_tables (Eleni)
  5. add_subscription_tables (Eleni)
  6. add_session_persona_switches (Seidu)

- [ ] New models in app/database/models.py:
  - avatar_template_roles (with heygen_avatar_id, heygen_voice_id, default_language)
  - sessions (with preferred_language, selected_role_id, session_mode, is_active)
  - courses (with user_id, is_public, code, department, semester)
  - course_students (enrollment records)
  - avatar_subscriptions (with is_active, expires_at)
  - session_runs (active session tracking)
  - session_persona_switches (audit log)

**Backend Services:**
- [ ] app/services/avatar_service.py
  - get_avatar_roles(avatar_id)
  - switch_persona(session_id, new_role_id) — updates session + audit log
  
- [ ] app/services/course_service.py
  - CRUD operations with publisher isolation
  - get_courses(user_id, role, filters) — privacy filtering
  - enroll_subscriber(user_id, course_id)
  - enroll_bulk(course_id, emails_list)
  
- [ ] app/services/session_service.py
  - create_session(course_id, avatar_id, ...) — validates ownership
  - start_run(session_id, subscriber_id) — checks all 5 validation points
  - stop_run(session_id, run_id) — saves transcript + summary
  - switch_mode(session_id, new_mode) — teaching ↔ examination
  
- [ ] app/services/subscription_service.py
  - validate_session_access(user_id, session_id, course_id) — 5-point check
  - get_active_subscriptions(user_id)

**Frontend Hooks & BFF Routes:**
- [ ] Hooks:
  - useAvatarRoles(avatar_id)
  - useCourses(filters)
  - useEnrolledCourses(user_id)
  - useSessions(course_id)
  - useSessionStart(session_id)
  - useHeyGenAvatar(avatar_id, language)
  
- [ ] BFF routes:
  - POST /api/courses (create)
  - GET /api/courses (list)
  - GET /api/courses/[id]
  - PATCH /api/courses/[id]
  - DELETE /api/courses/[id]
  - POST /api/courses/[id]/enroll
  - POST /api/courses/[id]/enroll-bulk
  - GET /api/courses/[id]/students
  - DELETE /api/courses/[id]/students/[user_id]
  - POST /api/sessions (create with file upload)
  - GET /api/sessions/[id]
  - PATCH /api/sessions/[id]/mode
  - PATCH /api/sessions/[id]/role
  - POST /api/sessions/[id]/run/start
  - POST /api/sessions/[id]/run/stop
  - GET /api/session/ephemeral (with heygen fields)

---

### ✅ End-to-End Workflows (Manual Test Cases)

By Tuesday, June 9, these workflows must work completely:

**Workflow 1: Publisher Sets Up Avatar + Course**
1. [ ] Publisher logs in (CHEN auth, verified email)
2. [ ] Navigates to /publisher/courses/new
3. [ ] Creates course: name, code, description, marks is_public=true
4. [ ] Course appears in /publisher/courses list
5. [ ] Course appears in /subscriber/marketplace (public)

**Workflow 2: Publisher Creates Session with Avatar Persona**
1. [ ] Publisher clicks \"Create Session\" in course detail
2. [ ] Uploads PDF presentation (file_processor extracts slides)
3. [ ] Selects session_mode: \"teaching\"
4. [ ] Selects avatar role: \"Emirati Lady\"
5. [ ] Publishes session
6. [ ] Session appears in course's session list

**Workflow 3: Subscriber Enrolls in Course**
1. [ ] Subscriber logs in (verified email)
2. [ ] Navigates to /subscriber/marketplace
3. [ ] Sees public course (filter by avatar works)
4. [ ] Clicks \"Enroll\" on course card
5. [ ] Redirects to /subscriber/my-courses
6. [ ] Course now appears in their list

**Workflow 4: Subscriber Starts Session (Avatar + HeyGen Rendering)**
1. [ ] Subscriber in /subscriber/my-courses/[course_id]/sessions
2. [ ] Clicks session → navigates to /subscriber/sessions/[id]/learn
3. [ ] Frontend calls GET /api/session/ephemeral
4. [ ] Backend validates all 5 checkpoints ✓
5. [ ] Ephemeral token response includes heygen_avatar_id
6. [ ] Frontend initializes:
   - OpenAI Realtime WebRTC connection
   - HeyGenStreaming component with avatar_id
7. [ ] HeyGen video renders (avatar speaking) ✓
8. [ ] Slide deck visible on side panel ✓
9. [ ] Subscriber can speak → AI responds → avatar lip-syncs ✓

**Workflow 5: Publisher Switches Avatar Persona Mid-Session**
1. [ ] Publisher in teaching interface (subscriber also in learning interface)
2. [ ] Publisher sees PersonaSwitcher control showing \"Emirati Lady\" (current)
3. [ ] Clicks \"Switch to Emirati Gentleman\"
4. [ ] Frontend: PATCH /api/sessions/[id]/role { role_id: \"gentleman_uuid\" }
5. [ ] Backend updates sessions.selected_role_id + returns new heygen_avatar_id
6. [ ] Frontend: stops current HeyGen avatar → starts new
7. [ ] Brief visual transition (fade out → fade in)
8. [ ] Subscriber sees avatar switch (video changes to gentleman)
9. [ ] Conversation continues uninterrupted (OpenAI Realtime not affected)

**Workflow 6: Publisher Enrolls Bulk Students in Course**
1. [ ] Publisher in /publisher/courses/[id]/enrollment
2. [ ] Clicks \"Bulk Upload\" button
3. [ ] Uploads CSV: email1@example.com, email2@example.com, ... (500 rows)
4. [ ] Backend processes bulk enrollment (no N+1 queries)
5. [ ] Success message: \"500 students enrolled\"
6. [ ] All students now see course in /subscriber/marketplace (if enrolled)

---

### 🎯 Definition of Done (Tuesday, June 9)

**All of the following must be TRUE:**

Backend (API):
- [ ] All models migrated (heygen fields, language, courses, subscriptions, session modes)
- [ ] All endpoints working (CRUD for courses, sessions, personas, enrollments)
- [ ] 5-point subscription validation enforced before session token issued
- [ ] Ephemeral token includes heygen_avatar_id + language + mode
- [ ] Persona switching creates audit log
- [ ] Tests: pytest -v passes for all new endpoints
- [ ] No secrets or credentials committed

Frontend (UI/UX):
- [ ] Course browsing + filtering works
- [ ] Course creation wizard complete
- [ ] Session creation wizard complete
- [ ] Teaching interface renders (publisher view)
- [ ] Learning interface renders (subscriber view)
- [ ] HeyGen avatar initializes + speaks (with audio fallback)
- [ ] Persona switcher functional (publisher-only)
- [ ] Floating avatar panel minimizable + responsive
- [ ] All pages responsive at 375px, 768px, 1920px
- [ ] Dark + light theme working on all pages
- [ ] npm test passes
- [ ] No console errors

Integration (End-to-End):
- [ ] Workflow 1: course creation ✓
- [ ] Workflow 2: session with avatar ✓
- [ ] Workflow 3: subscriber enrollment ✓
- [ ] Workflow 4: session join + HeyGen renders ✓
- [ ] Workflow 5: persona switch mid-session ✓
- [ ] Workflow 6: bulk enrollment ✓

Documentation:
- [ ] AGENTS.md §5 updated with all new endpoints
- [ ] README updated with avatar/HeyGen setup
- [ ] Team briefed on architecture

---

## SUMMARY FOR TUESDAY, JUNE 9, 2026

This milestone represents the **core platform pivot**: from authentication-only to **fully operational avatar-driven learning platform**.

By Tuesday EOD, a publisher can:
- Create courses with public/private access
- Upload presentations as sessions
- Configure which avatar persona teaches each session
- Switch between avatars mid-session (Emirati Lady ↔ Gentleman)

A subscriber can:
- Browse and enroll in public courses
- Start a live session
- See a photorealistic Emirati avatar speaking (via HeyGen)
- Hear AI voice (via OpenAI Realtime)
- Learn from slide content presented by the avatar

**This is a fully functional, end-to-end learning experience ready for Client 1 (UAE Government) demos.**

" \
  "2026-06-09"

create_milestone "$FE_REPO" \
  "M1: Avatar, Courses & Sessions Integration (Tue, Jun 9)" \
  "Complete end-to-end workflows for avatar management, course creation/enrollment, and session lifecycle.

## WHAT MUST BE DONE BY TUESDAY, JUNE 9, 2026

### 🧑‍🎓 Avatar & Persona Management (Seidu)

**Frontend (UI/UX):**
- HeyGen Streaming Avatar component
  - [ ] src/components/avatar/HeyGenStreaming.tsx wraps SDK
  - [ ] Initializes with avatar_id, language, quality
  - [ ] Methods: speak(text), interrupt(), stop()
  - [ ] Error handling: fallback to audio-only if HeyGen unavailable
  
- Avatar persona switcher (publisher-only)
  - [ ] src/components/avatar/PersonaSwitcher.tsx
  - [ ] Shows available roles in dropdown or pill buttons
  - [ ] Click role → PATCH /api/sessions/{id}/role
  - [ ] Smooth HeyGen transition (stop current → start new)
  - [ ] Hidden from subscriber view
  
- Floating avatar panel
  - [ ] src/components/avatar/FloatingAvatarPanel.tsx (bottom-right corner)
  - [ ] Minimize → shows only thumbnail
  - [ ] Expand → shows full video + controls
  - [ ] Close → ends session
  - [ ] Minimize state persists to localStorage
  - [ ] Mobile: full-screen when expanded
  
- Ephemeral token integration
  - [ ] GET /api/session/ephemeral response parsed
  - [ ] heygen_avatar_id extracted → passed to HeyGenStreaming
  - [ ] Both OpenAI Realtime + HeyGen initialized together
  - [ ] Fallback to transcript-only if HeyGen fails

---

### 📚 Courses Management (Eleni)

**Frontend (UI/UX):**
- Course browsing (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/marketplace/page.tsx
  - [ ] List public courses with filters: avatar, search, pagination
  - [ ] Course cards: title, description, avatar thumbnail, session count
  - [ ] Self-enroll button (one-click for free/public)
  - [ ] Access code input modal (redeem code to enroll)
  
- My courses (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/my-courses/page.tsx
  - [ ] List enrolled courses with progress bars
  - [ ] Click course → view sessions list
  
- Course management (publisher view)
  - [ ] src/app/(dashboard)/publisher/courses/page.tsx (list)
  - [ ] src/app/(dashboard)/publisher/courses/new/page.tsx (create wizard)
  - [ ] src/app/(dashboard)/publisher/courses/[id]/page.tsx (edit)
  - [ ] Create form: name, description, code, department, semester, is_public toggle
  - [ ] Validate: required fields, unique course code
  
- Course enrollment UI (publisher)
  - [ ] src/app/(dashboard)/publisher/courses/[id]/enrollment/page.tsx
  - [ ] List enrolled students (table: email, joined_at, status)
  - [ ] Single invite: input email → send invite link
  - [ ] Bulk upload: CSV modal (email, access_level)
  - [ ] Unenroll button per student
  - [ ] BFF routes: POST /api/courses/[id]/enroll, POST /api/courses/[id]/enroll-bulk, DELETE /api/courses/[id]/students/[user_id]

---

### 🎬 Sessions & Teaching Interface (Eleni + Seidu)

**Frontend (UI/UX):**
- Session creation wizard (publisher)
  - [ ] src/app/(dashboard)/publisher/sessions/new/page.tsx (multi-step wizard)
  - [ ] Step 1: Select course + avatar
  - [ ] Step 2: Upload presentation (PDF/PPTX)
    - File upload with progress bar
    - Backend: file_processor.py converts to images, extracts slides
    - Returns: slide count, thumbnails
  - [ ] Step 3: Configure session
    - Session name (required)
    - Session mode toggle (teaching ↔ examination)
    - Avatar role selector (dropdown: Emirati Lady / Emirati Gentleman)
    - is_active toggle (publish immediately or draft)
  - [ ] Step 4: Review + publish
  - [ ] BFF route: POST /api/sessions with multipart file upload
  
- Teaching interface (publisher view)
  - [ ] src/app/(dashboard)/publisher/sessions/[id]/teach/page.tsx
  - [ ] Layout: large video left, slide deck preview right (responsive stack on mobile)
  - [ ] Video area: HeyGen avatar + optional webcam overlay
  - [ ] Persona switcher control (PersonaSwitcher component)
  - [ ] Slide navigation: prev/next buttons, slide counter
  - [ ] Transcript panel: scrollable, shows subscriber messages + AI responses
  - [ ] Control bar: mute mic, record (future), pause, end session button
  - [ ] Session timer + status
  - [ ] Connected to OpenAI Realtime WebRTC
  
- Learning interface (subscriber view)
  - [ ] src/app/(dashboard)/subscriber/sessions/[id]/learn/page.tsx
  - [ ] Layout: similar to teaching but simpler (no persona switcher, no webcam)
  - [ ] Video area: HeyGen avatar full-featured
  - [ ] Slide preview: minimizable on mobile
  - [ ] Transcript: read-only messages, can flag/rate responses
  - [ ] Controls: mute mic, end session
  - [ ] Post-session: rating modal (5-star feedback)
  - [ ] Connected to OpenAI Realtime WebRTC (ephemeral token)
  
- Responsive TeachingInterface component
  - [ ] src/components/sessions/TeachingInterface.tsx (role-aware wrapper)
  - [ ] Desktop: 2-column (video left 60%, slides right 40%)
  - [ ] Tablet: stacked vertically (video top, slides bottom)
  - [ ] Mobile: video full-screen with minimizable slide panel
  - [ ] Dark/light theme support
  - [ ] No horizontal scroll at any breakpoint

---

### ✅ End-to-End Workflows (Manual Test Cases)

By Tuesday, June 9, these workflows must work completely:

**Workflow 1: Publisher Sets Up Avatar + Course**
1. [ ] Publisher logs in (email verified)
2. [ ] Navigates to /publisher/courses/new
3. [ ] Creates course: name, code, description, marks is_public=true
4. [ ] Course appears in /publisher/courses list
5. [ ] Course appears in /subscriber/marketplace (public)

**Workflow 2: Publisher Creates Session with Avatar Persona**
1. [ ] Publisher clicks \"Create Session\" in course detail
2. [ ] Uploads PDF presentation (file_processor extracts slides)
3. [ ] Selects session_mode: \"teaching\"
4. [ ] Selects avatar role: \"Emirati Lady\"
5. [ ] Publishes session
6. [ ] Session appears in course's session list

**Workflow 3: Subscriber Enrolls in Course**
1. [ ] Subscriber logs in (verified email)
2. [ ] Navigates to /subscriber/marketplace
3. [ ] Sees public course (filter by avatar works)
4. [ ] Clicks \"Enroll\" on course card
5. [ ] Redirects to /subscriber/my-courses
6. [ ] Course now appears in their list

**Workflow 4: Subscriber Starts Session (Avatar + HeyGen Rendering)**
1. [ ] Subscriber in /subscriber/my-courses/[course_id]/sessions
2. [ ] Clicks session → navigates to /subscriber/sessions/[id]/learn
3. [ ] Frontend calls GET /api/session/ephemeral
4. [ ] Ephemeral token response includes heygen_avatar_id
5. [ ] Frontend initializes:
   - OpenAI Realtime WebRTC connection
   - HeyGenStreaming component with avatar_id
6. [ ] HeyGen video renders (avatar speaking) ✓
7. [ ] Slide deck visible on side panel ✓
8. [ ] Subscriber can speak → AI responds → avatar lip-syncs ✓

**Workflow 5: Publisher Switches Avatar Persona Mid-Session**
1. [ ] Publisher in teaching interface (subscriber also in learning interface)
2. [ ] Publisher sees PersonaSwitcher control showing \"Emirati Lady\" (current)
3. [ ] Clicks \"Switch to Emirati Gentleman\"
4. [ ] Frontend: PATCH /api/sessions/[id]/role { role_id: \"gentleman_uuid\" }
5. [ ] Backend updates sessions.selected_role_id + returns new heygen_avatar_id
6. [ ] Frontend: stops current HeyGen avatar → starts new
7. [ ] Brief visual transition (fade out → fade in)
8. [ ] Subscriber sees avatar switch (video changes to gentleman)
9. [ ] Conversation continues uninterrupted (OpenAI Realtime not affected)

**Workflow 6: Publisher Enrolls Bulk Students in Course**
1. [ ] Publisher in /publisher/courses/[id]/enrollment
2. [ ] Clicks \"Bulk Upload\" button
3. [ ] Uploads CSV: email1@example.com, email2@example.com, ... (500 rows)
4. [ ] Backend processes bulk enrollment (no N+1 queries)
5. [ ] Success message: \"500 students enrolled\"
6. [ ] All students now see course in /subscriber/marketplace (if enrolled)

---

### 🎯 Definition of Done (Tuesday, June 9)

Frontend (UI/UX):
- [ ] Course browsing + filtering works
- [ ] Course creation wizard complete
- [ ] Session creation wizard complete
- [ ] Teaching interface renders (publisher view)
- [ ] Learning interface renders (subscriber view)
- [ ] HeyGen avatar initializes + speaks (with audio fallback)
- [ ] Persona switcher functional (publisher-only)
- [ ] Floating avatar panel minimizable + responsive
- [ ] All pages responsive at 375px, 768px, 1920px
- [ ] Dark + light theme working on all pages
- [ ] npm test passes
- [ ] No console errors

Integration (End-to-End):
- [ ] Workflow 1: course creation ✓
- [ ] Workflow 2: session with avatar ✓
- [ ] Workflow 3: subscriber enrollment ✓
- [ ] Workflow 4: session join + HeyGen renders ✓
- [ ] Workflow 5: persona switch mid-session ✓
- [ ] Workflow 6: bulk enrollment ✓

---

## SUMMARY FOR TUESDAY, JUNE 9, 2026

This milestone represents the **core platform pivot**: from authentication-only to **fully operational avatar-driven learning platform**.

By Tuesday EOD, a publisher can:
- Create courses with public/private access
- Upload presentations as sessions
- Configure which avatar persona teaches each session
- Switch between avatars mid-session (Emirati Lady ↔ Gentleman)

A subscriber can:
- Browse and enroll in public courses
- Start a live session
- See a photorealistic Emirati avatar speaking (via HeyGen)
- Hear AI voice (via OpenAI Realtime)
- Learn from slide content presented by the avatar

**This is a fully functional, end-to-end learning experience ready for Client 1 (UAE Government) demos.**
" \
  "2026-06-09"

echo ""
echo "=========================================="
echo "✅ Milestone Created for Tuesday, June 9, 2026!"
echo "=========================================="
echo ""
echo "SINGLE MILESTONE: Avatar, Courses & Sessions Integration"
echo ""
echo "Contents:"
echo "  - Avatar & Persona Management (Seidu)"
echo "  - Courses Management (Eleni)"
echo "  - Sessions & Teaching Interface (Eleni + Seidu)"
echo "  - 6 End-to-End Workflow Tests"
echo "  - Complete Definition of Done"
echo ""
echo "View milestones:"
echo "  gh milestone list -R $API_REPO"
echo "  gh milestone list -R $FE_REPO"
echo ""