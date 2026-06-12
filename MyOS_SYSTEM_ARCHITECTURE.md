# MyOS Platform System Architecture

## 1. Core Principles & Platform Overview
MyOS is transitioning from a heavily hardcoded, customer-specific implementation to a fully decoupled, database-driven architecture. The platform operates as a multi-tenant ecosystem where all configuration—from visual theming to AI voice modeling—is dictated by the database.

### 1.1 Terms & Policies
- Before users can fully access the platform (Publisher or Subscriber), they must agree to Terms, Privacy, and Policy agreements. Acceptance is tracked at the User record level.

---

## 2. Decoupled Entities & Responsibilities

### 2.1 Avatars (The Core Entity)
The Avatar replaces the "Course" as the central subscription unit of the platform.
- **Definition:** All AI logic (model selection, prompt base) resides at the Avatar level.
- **Variants:** A single Avatar supports multiple Variants (e.g., Male, Female, alternate languages). Each Variant independently defines its TTS Voice model and 3D Model mapping.
- **3D Models:** The available 3D models (`.glb`/`.gltf`) are strictly managed and uploaded by the platform Admins. Publishers select from this curated library when configuring a Variant.
- **Visibility:** Avatars can be Public (discoverable in the Marketplace) or Private (hidden, accessed only via Access Code).
- **Access Codes:** Managed inside the Avatar. Codes can:
  - Be limited to a specific number of redemptions.
  - Automatically allocate a defined amount of top-up credits per user.
  - Form the basis of custom billing (e.g., billing the Publisher for the total credit volume assigned via codes).
- **Subscribers:** Subscribing to an Avatar automatically enrolls the user in *all* Courses delivered by that Avatar. Publishers have an interface to remove or re-onboard these subscribers.

### 2.2 Programs (Organizational & Theming Layer)
Programs allow Publishers to group multiple Avatars and Courses under a unified brand identity.
- **Dynamic Theming:** Entering a Program shifts the entire MyOS branding. The portal adapts to the `theme_config` of the Program (custom logos, colors, names).
- **Access Flow:** Users automatically gain access to a Program when they enroll in an Avatar that belongs to that Program. However, the enrollment UI *must* explicitly inform the user that their enrollment will also join them to the associated Program.
- **Program Switcher:** A dropdown/toggle in the top-right navigation allows users enrolled in multiple Programs to switch contexts.
- **Fallback State:** If no Program is selected, or if a Publisher doesn't use Programs, the user is immersed in the default "MyOS" Marketplace interface.

### 2.3 Courses & Sessions (Content Containers)
- **Courses:** Cleanly decoupled from Avatars. A Course holds raw learning metadata (Title, Description). Publishers map Courses to Avatars, allowing a single Course to be delivered by multiple Avatars across different domains/Programs.
- **Sessions:** Simplified to bare essentials. 
  - Required fields: `Title`, `Duration`, `Description`, `Mode` (Teaching or Assessment).
  - Deprecated: Max student caps and hardcoded semester schedules.

---

## 3. The Learning Experience (Execution Layer)

### 3.1 Autonomous Session Runs
- When a user enters a Session, it is driven entirely by the selected Avatar Variant.
- The Avatar AI is empowered to autonomously execute frontend commands: `nextslide`, `previousslide`, `goToslide`.
- Built-in UI controls allow the user to easily toggle Mic On/Off, Audio On/Off, and Connect/Disconnect state.

### 3.2 Live Transcription & Context
- **Transcription:** A persistent side-panel generates a live chat-like transcript, flawlessly merging both the AI's Speech-to-Text output and the user's STT input. This can be exported.
- **RAG Implementation:** The Avatar pulls context from uploaded Course materials using Retrieval-Augmented Generation (RAG), delivering highly accurate and verifiable knowledge. Feedback loops allow users to rate the RAG outputs.
- **Progress Tracking:** Robust telemetry tracks the user's progress through the Course material, persisting to the backend.

---

## 4. AI Navigation Assistant
Separate from the 3D Avatars, MyOS features a globally persistent AI Assistant.
- **Form Factor:** A lightweight conversational agent (voice and chat) integrated into the global layout.
- **Knowledge & Memory:** Aware of the user’s current navigation state, past activity, enrolled Programs, and Avatar subscriptions.
- **Action-Oriented Capability:** The Assistant is authorized to execute actions on the platform on behalf of the user. For example, it can process natural language commands like *"enroll me in the UAE Training avatar"* or *"switch my theme to Dark Mode"* by invoking the respective internal APIs.

---

## 5. Analytics & Telemetry
A multi-tiered analytics engine scales based on the user's role:
1. **Subscriber Level:** Personal dashboards tracking course completion, credits spent, and learning progress.
2. **Publisher Level:** Aggregated metrics across their Avatars, Programs, and Course engagement, plus detailed subscriber tracking.
3. **Admin Level:** System-wide overview encompassing compute costs, global engagement, and API usage (TTS/STT).
