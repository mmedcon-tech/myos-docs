# MyOS Deployment Plan on AWS

**Prepared:** 21 October 2026 · **Scope:** US fertility and plastic-surgery clinics first; UAE later · **Read with:** `MyOS_Expert_Twin_Architecture_v2.md`

Prices below are rough estimates for planning. Check them in the AWS Pricing Calculator before committing, and confirm every "HIPAA-eligible" service against AWS's current list.

---

## 1. The short version

- **AWS is the right home for patient data**, because it signs a business associate agreement (BAA) online and most of the services MyOS needs are HIPAA-eligible. Your AWS Activate credits cover the first year or two.
- **AWS alone is not enough.** Every other vendor that touches patient data needs its own BAA, and you need policies, training, risk assessments and security evidence on top of the hosting (section 2).
- **AWS is only "for big companies" if you use it like one.** Keep the setup small: managed services, one region, a few containers, and strict budget alerts (section 3).
- **The avatars decide most of the design and the cost.** 3D avatars run in the browser for almost nothing; the MyOS lip-sync model needs GPUs, so it's the one part to engineer carefully (section 5).

---

## 2. If everything is on AWS, is that all you need?

No. AWS secures the cloud itself; you are responsible for everything you put in it and everyone else you send data to. This is called the shared responsibility model.

**What AWS covers once you accept its BAA**

- Physical security of data centres, hardware and the underlying network
- HIPAA-eligible services you can build on (databases, storage, containers, encryption keys, logging)
- Compliance reports you can download for clinics' security teams

**What you still need**

| Item | Why | Who provides it |
| --- | --- | --- |
| BAA with your AI model provider | Patient messages go to the model | AWS (Claude on Bedrock, covered by the AWS BAA) or OpenAI (API BAA, zero-retention endpoints only) |
| BAA with your voice provider | Patient speech and the twin's replies pass through it | ElevenLabs Enterprise (BAAs are Enterprise-only), or Amazon Polly and Transcribe under the AWS BAA |
| BAA with any third-party avatar service | It receives the text the twin speaks | HeyGen only if they sign one; otherwise keep it to demos and Doctor Brand videos |
| BAAs for email, SMS and error tracking | Notifications and error logs can leak patient details | Amazon SES and SNS under the AWS BAA, or vendors who sign |
| A HIPAA risk assessment and written policies | Required by the HIPAA Security Rule | You, ideally with Vanta, Drata or Secureframe |
| Staff security training and access reviews | Required, and clinics will ask | You |
| Incident response and breach-notification plan | Required | You |
| SOC 2 Type 1, then Type 2 | Clinics' IT teams ask for it | An auditor, prepared with the compliance tool |
| BAAs with each clinic, terms of service and a privacy notice | You are the clinic's business associate | You and a healthcare lawyer |
| UAE: in-country hosting and Department of Health approval | UAE health data must stay in the UAE | A separate UAE deployment (section 8) |

---

## 3. Why people say AWS is only worth it for big companies

There's truth in it, for typical web apps:

1. **Complexity.** AWS has hundreds of services and a powerful but confusing permissions system. Small teams lose weeks to setup that Railway or Vercel does in minutes.
2. **Unpredictable bills.** Charges hide in places beginners don't expect: data leaving AWS, NAT gateways (about $32 a month each before traffic), idle test environments, forgotten GPU instances and log storage.
3. **It needs operations skills.** Someone has to own networking, backups, patching and monitoring.
4. **Simple platforms are cheaper for simple apps.** Railway, Render or Vercel cost less and need no specialist.

**Why it's different for MyOS**

- **Healthcare needs a BAA.** Most simple hosting platforms either don't sign one or only sign on expensive enterprise plans.
- **Clinics trust it.** "Hosted on AWS under a BAA" ends a lot of security-review questions early.
- **You need GPUs, private storage, encryption keys and audit logs** in one place, under one agreement.
- **Your credits cover the learning curve.**

**How to avoid the big-company trap**

- Use managed services only: Fargate containers, RDS, S3, SQS. Avoid Kubernetes until you have a dedicated engineer.
- One region (us-east-1) until the UAE launch.
- Infrastructure as code (Terraform or AWS CDK), so environments can be rebuilt and torn down.
- AWS Budgets alerts at 50%, 80% and 100% of a monthly limit, plus a nightly check that stops idle GPU instances.
- Tag every resource by environment and feature, so you can see what each part costs.

---

## 4. Target architecture (US production)

```text
Patients and staff (browser, clinic app, embedded widget)
  │
  ├── Marketing site, Doctor Brand videos, embed script ── Cloudflare (no patient data)
  │
  └── app.myos… and api.myos… (DNS only, not proxied by Cloudflare)
        │
        ▼
   AWS WAF ─► Application Load Balancer
        │
        ├── Next.js app on ECS Fargate
        ├── FastAPI API on ECS Fargate
        │     ├── RDS PostgreSQL with pgvector (Multi-AZ, encrypted)
        │     ├── ElastiCache Redis (encrypted)
        │     ├── S3 private buckets (knowledge, likeness, audit archive)
        │     ├── SQS queues ─► worker containers (ingestion, embeddings, transcripts, pre-rendering)
        │     ├── Amazon Bedrock (Claude) or OpenAI API (BAA, zero retention)
        │     └── Voice: ElevenLabs Enterprise or Amazon Polly and Transcribe
        │
        └── Real-time media
              ├── LiveKit media server (self-hosted on ECS or EC2)
              └── MyOS lip-sync service on GPU instances (EC2 with NVIDIA L4)
```

**Accounts** (AWS Organizations, with sign-in through IAM Identity Center and MFA everywhere):

| Account | Holds | Patient data? |
| --- | --- | --- |
| `management` | Billing and organisation settings only | No |
| `log-archive` | CloudTrail and security logs, write-once | Logs only, scrubbed |
| `dev` and `staging` | Development and pre-release testing | **Never**: fake and seeded demo data only |
| `prod-us` | Live clinics | Yes |
| `prod-uae` (later) | UAE clinics, in the UAE region | Yes |

**Services and their roles**

| Need | AWS service | Notes |
| --- | --- | --- |
| App and API | ECS on Fargate | Two or more tasks each, autoscaling on CPU and requests |
| Database and vector search | RDS for PostgreSQL with pgvector | Multi-AZ in production, encrypted with KMS, point-in-time recovery |
| Cache and sessions | ElastiCache for Redis | Encryption in transit and at rest |
| Files | S3 | Block all public access, KMS encryption, short-lived signed links, versioning |
| Background jobs | SQS plus worker containers | Document ingestion, embeddings, video pre-rendering, data deletion |
| Secrets | Secrets Manager | No keys in code or environment files |
| Encryption keys | KMS | One key per environment; a data key per clinic for tenant separation |
| Threat detection and audit | GuardDuty, Security Hub, CloudTrail, AWS Config | CloudTrail across all accounts into `log-archive` |
| Web protection | AWS WAF | Rate limits on sign-in and every AI endpoint |
| Backups | AWS Backup | Daily, cross-region copy, restore tested monthly |
| Deploys | GitHub Actions with OIDC into AWS | No long-lived AWS keys in GitHub |
| Email and SMS | SES and SNS | Neutral wording: never the topic of a private consultation |

**Logging rule:** application logs must never contain patient messages, names or transcripts. Log IDs and event types only, scrub before writing, and keep error tracking inside AWS (CloudWatch) unless the vendor signs a BAA.

---

## 5. Deploying the avatars

The renderer is chosen per Variant (architecture v2, section 6). Each one deploys differently.

| Renderer | Where it runs | Patient data involved | Main cost | Use for |
| --- | --- | --- | --- | --- |
| `glb_3d` | In the patient's browser (three.js); models served from S3 and CloudFront | No: lip movement comes from the audio in the browser | Almost nothing | Low-cost sessions, stylised brand avatars |
| `audio_only` | Browser, with a still portrait | No extra | Voice only | Private mode's discreet option, poor connections |
| `myos_lipsync` | GPU containers in `prod-us`, streaming video through LiveKit | Yes: it receives the twin's spoken reply | GPU hours | Default photo-real expert twins |
| `streaming_talking_head` (HeyGen) | HeyGen's cloud | Yes, if used in patient sessions | Per-minute fees | Demos and Doctor Brand; patient sessions only with a HeyGen BAA |

### 5.1 The MyOS lip-sync service

- **Hardware:** start on single-GPU NVIDIA L4 instances (the g6 family, roughly $0.80 an hour on demand in us-east-1). Benchmark how many live streams one GPU can serve before choosing sizes.
- **Scaling:** keep a small warm pool during clinic hours and scale on active sessions. Scale to zero overnight in staging, and keep at least one warm instance in production so the first patient doesn't wait.
- **Rough budget:** one L4 GPU running 12 hours a day costs about $290 a month on demand. Savings Plans or reserved capacity cut that once usage is steady.
- **Fallback:** if no GPU is free within a few seconds, switch the session to `audio_only` and say so on screen. Never leave a patient waiting.

### 5.2 Pre-rendered answers (the biggest cost saver)

- For each approved answer that patients ask about often, render the twin's video once in a batch job (AWS Batch on Spot GPU instances, which cost much less).
- Store the clips in S3 and serve them through CloudFront with signed links.
- During a live session, if a question matches an approved pre-rendered answer, play the clip instead of generating live video.
- Doctor Brand videos use the same batch pipeline, and contain no patient data.

### 5.3 Likeness assets (doctors' headshots, video and voice)

- Keep them in a separate S3 bucket with its own KMS key and access limited to the onboarding workers.
- Store a consent record ID with every file. Revoking consent triggers a job that deletes the files, the provider avatar and the cloned voice, and writes to the audit log.
- Clinics' patients never have access to this bucket.

### 5.4 Real-time conversation pipeline

1. The browser connects to LiveKit (self-hosted, so no extra vendor sees the audio).
2. Speech-to-text runs in the clinic's region (Amazon Transcribe, or the chosen model provider under its BAA).
3. The twin's reply is generated from approved knowledge only (Bedrock or the OpenAI API).
4. Text-to-speech uses the doctor's cloned voice (ElevenLabs Enterprise) or a stock voice (Amazon Polly).
5. The lip-sync service turns the audio and the doctor's portrait into video, streamed back through LiveKit.
6. Only the text transcript is stored, encrypted. No patient audio or video is kept.

**To confirm before production:** the code currently uses OpenAI's Realtime API with ephemeral tokens. Confirm with OpenAI whether Realtime endpoints are covered by its BAA and zero-retention terms. If they aren't, use the step-by-step pipeline above for patient sessions.

---

## 6. Environments and data rules

| Environment | Data allowed | Renderers allowed |
| --- | --- | --- |
| Local and dev | Fake data only | All, including HeyGen with test keys |
| Staging | The seeded demo workspace (fictional twins) | All |
| Demo (investors, sales) | Demo workspace only, with `NEXT_PUBLIC_DEMO_MODE=true` | All |
| Production US | Real patients, under BAAs | `myos_lipsync`, `glb_3d`, `audio_only`; HeyGen only with a BAA |
| Production UAE | Real patients, in-country only | Only providers running inside the UAE |

---

## 7. Rollout

| Phase | Weeks | Work | Done when |
| --- | --- | --- | --- |
| 0. Foundations | 1 | AWS Organizations and accounts; accept the AWS BAA in AWS Artifact (production account); Identity Center with MFA; CloudTrail, GuardDuty and Security Hub; Budgets alerts | Accounts exist, BAA accepted, alerts working |
| 1. Staging on AWS | 1–2 | Terraform or CDK for the VPC, Fargate, RDS with pgvector, Redis, S3, SQS and WAF; GitHub Actions with OIDC; move off Railway | Staging matches local behaviour; all tests pass in CI |
| 2. Voice and simple avatars | 3–4 | `glb_3d` and `audio_only` in staging; ElevenLabs on the startup grant for demos; LiveKit | A full demo session runs end to end on AWS |
| 3. Lip-sync and pre-rendering | 5–8 | GPU service, autoscaling, fallback to audio; batch pre-rendering; benchmark streams per GPU | Real cost per video minute measured and recorded |
| 4. Production go-live | 8–10 | BAAs signed (AWS, model provider, ElevenLabs Enterprise); risk assessment; policies and training; penetration test; restore test; incident-response runbook | The go-live checklist below is complete |
| 5. UAE | After approval | Separate deployment in the AWS UAE region or Azure UAE North; in-country model, speech and lip-sync | Department of Health approval received; no data leaves the UAE |

### Go-live checklist (production US)

- [ ] AWS BAA accepted for the production account
- [ ] BAAs signed with the model provider and voice provider, with zero retention configured
- [ ] HeyGen excluded from patient sessions unless a BAA is signed
- [ ] HIPAA risk assessment completed and stored
- [ ] Security policies written and staff trained
- [ ] Encryption at rest (KMS) and in transit (TLS) verified on every service
- [ ] No patient content in logs or error reports (tested)
- [ ] Backups restored successfully in a test
- [ ] Penetration test passed, findings fixed
- [ ] Incident-response and breach-notification runbook written
- [ ] Rate limits on sign-in and all AI endpoints
- [ ] Private-mode deletion job running and tested
- [ ] Budget alerts and idle-GPU shutdown active
- [ ] Clinic BAA, terms of service and privacy notice reviewed by a healthcare lawyer

---

## 8. UAE deployment notes

- UAE health data generally cannot be stored or processed outside the UAE, and Abu Dhabi requires Department of Health approval before patient data goes into the cloud.
- Deploy a completely separate copy: the AWS UAE region or Azure UAE North (Azure also offers OpenAI with UAE data residency, and Core42's sovereign cloud).
- ElevenLabs does not currently offer UAE data residency, so UAE sessions need in-country speech or your own voice models.
- Run the lip-sync GPUs in the UAE as well.
- UAE law requires health data to be kept for at least 25 years after a patient's last procedure. Check with a UAE health lawyer how that applies to twin conversations before promising short retention there.

---

## 9. Rough monthly costs (US, before credits)

Estimates for planning only; confirm in the AWS Pricing Calculator.

| Item | Staging | Production pilot (5–10 clinics) |
| --- | --- | --- |
| App and API containers (Fargate) | $60–120 | $150–300 |
| RDS PostgreSQL | $30–60 (single instance) | $150–300 (Multi-AZ) |
| Redis | $15–30 | $50–100 |
| Load balancer, WAF, NAT gateway | $60–100 | $100–200 |
| S3, CloudFront, backups, logs | $10–30 | $50–150 |
| Security services (GuardDuty, Security Hub, Config) | $20–50 | $50–150 |
| GPU for live lip-sync | Scale to zero; pay per test | About $290 per GPU at 12 hours a day |
| AI model, speech and voice | Usage-based | Usage-based; meter per session |
| **Total before usage-based items** | **About $200–400** | **About $850–1,500, plus GPUs** |

Your AWS Activate credits should cover these through the pilot phase. The numbers to watch are GPU hours and AI usage per patient episode, which feed directly into the break-even model.
