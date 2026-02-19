# EpoxyBidPro — Full Stack Development Roadmap

> **Vision:** The definitive all-in-one iOS platform for epoxy floor businesses — combining AI-powered bidding, LiDAR floor measurement, CRM, job management, invoicing, and analytics into a single, sleek, field-ready tool.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [App Architecture](#3-app-architecture)
4. [Phase 0 — Project Bootstrap](#phase-0--project-bootstrap)
5. [Phase 1 — Core iOS Foundation](#phase-1--core-ios-foundation)
6. [Phase 2 — LiDAR Scanning Engine](#phase-2--lidar-scanning-engine)
7. [Phase 3 — AI Bidding Engine](#phase-3--ai-bidding-engine)
8. [Phase 4 — CRM Module](#phase-4--crm-module)
9. [Phase 5 — Bid & Proposal Generation](#phase-5--bid--proposal-generation)
10. [Phase 6 — Job Management & Scheduling](#phase-6--job-management--scheduling)
11. [Phase 7 — Invoicing & Payments](#phase-7--invoicing--payments)
12. [Phase 8 — Photo & Document Management](#phase-8--photo--document-management)
13. [Phase 9 — Analytics & Reporting Dashboard](#phase-9--analytics--reporting-dashboard)
14. [Phase 10 — Backend & API Layer](#phase-10--backend--api-layer)
15. [Phase 11 — Testing & QA](#phase-11--testing--qa)
16. [Phase 12 — App Store Submission & Launch](#phase-12--app-store-submission--launch)
17. [Post-Launch Roadmap](#post-launch-roadmap)
18. [Milestones Summary](#milestones-summary)

---

## 1. Project Overview

**EpoxyBidPro** is a native iOS application built for epoxy flooring contractors and businesses. It eliminates manual measuring, spreadsheet bidding, and juggling multiple apps by delivering:

| Feature Area          | Core Value                                                   |
|-----------------------|--------------------------------------------------------------|
| LiDAR Measurement     | Scan a room and get precise sq ft in seconds                 |
| AI Bidding Engine     | Auto-generate accurate bids based on scope, materials, labor |
| CRM                   | Track leads, clients, contacts, and job history              |
| Bid/Proposal Gen      | Professional branded PDF proposals sent in the field         |
| Job Management        | Scheduling, crew assignment, progress tracking               |
| Invoicing & Payments  | Send invoices, collect deposits and payments via Stripe      |
| Photo Documentation   | Before/after photos attached to jobs and proposals           |
| Analytics             | Revenue, win rates, material costs, crew performance         |

**Target Users:** Epoxy flooring contractors (1-person operations to mid-size companies with crews)

**Platform:** iOS 16+ (iPhone & iPad), with iPad as primary field device

---

## 2. Tech Stack

### iOS (Frontend)
| Layer            | Technology                                      |
|------------------|-------------------------------------------------|
| Language         | Swift 5.9+                                      |
| UI Framework     | SwiftUI (with UIKit bridges where needed)       |
| AR / LiDAR       | ARKit 6, RealityKit 2, SceneKit               |
| AI On-Device     | Core ML, Create ML                              |
| Local Database   | SwiftData (iOS 17+) / Core Data fallback        |
| Networking       | URLSession + async/await, Alamofire (optional)  |
| PDF Generation   | PDFKit, custom PDF renderer                     |
| Camera           | AVFoundation                                    |
| Auth             | Sign in with Apple, Firebase Auth               |
| Push Notifs      | APNs, Firebase Cloud Messaging                  |
| Maps/Geo         | MapKit, CoreLocation                            |
| Charts           | Swift Charts (iOS 16+)                          |
| State Mgmt       | Combine + @Observable (Swift 5.9 macro)         |

### Backend
| Layer            | Technology                                      |
|------------------|-------------------------------------------------|
| Runtime          | Node.js 20 LTS                                  |
| Framework        | Express.js + TypeScript                         |
| API Style        | REST + WebSockets (real-time job updates)       |
| Database         | PostgreSQL 16 (primary), Redis (caching/queues) |
| ORM              | Prisma                                          |
| AI / LLM         | OpenAI API (GPT-4o) for bid reasoning           |
| ML Training      | Python + scikit-learn (pricing model)           |
| File Storage     | AWS S3 (photos, PDFs)                           |
| Auth             | JWT + Apple Sign In verification                |
| Payments         | Stripe API                                      |
| Email/SMS        | SendGrid (email), Twilio (SMS)                  |
| Hosting          | AWS (EC2 + RDS + S3 + CloudFront)              |
| CI/CD            | GitHub Actions                                  |
| Containerization | Docker + Docker Compose                         |

---

## 3. App Architecture

```
EpoxyBidPro/
├── iOS App (Swift/SwiftUI)
│   ├── Features/
│   │   ├── Auth/
│   │   ├── Dashboard/
│   │   ├── LiDARScanner/
│   │   ├── BidEngine/
│   │   ├── CRM/
│   │   ├── Bids/
│   │   ├── Jobs/
│   │   ├── Invoicing/
│   │   ├── Photos/
│   │   └── Analytics/
│   ├── Core/
│   │   ├── Networking/
│   │   ├── Persistence/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings
│
├── Backend (Node.js/TypeScript)
│   ├── src/
│   │   ├── routes/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── models/         (Prisma schema)
│   │   ├── middleware/
│   │   └── utils/
│   ├── prisma/
│   │   └── schema.prisma
│   └── docker-compose.yml
│
├── ML/
│   ├── pricing_model/      (Python — scikit-learn)
│   └── CoreML_models/      (exported .mlmodel files)
│
└── ROADMAP.md
```

**Architecture Pattern:** iOS uses MVVM + Clean Architecture with separate data / domain / presentation layers. Backend follows MVC with a service layer.

---

## Phase 0 — Project Bootstrap

**Goal:** Repo, tooling, project structure, and environments ready for development.

**Estimated Duration:** 3–5 days

### Tasks

- [ ] Create GitHub repository with `main`, `develop`, and `feature/*` branch strategy
- [ ] Set up .gitignore (Swift, Node, Python, secrets)
- [ ] Create Xcode project: `EpoxyBidPro.xcodeproj`
  - Enable SwiftUI lifecycle
  - Enable LiDAR capability (`NSLocationWhenInUseUsageDescription`, Camera, ARKit)
  - Configure signing & capabilities (App Store Connect provisioning)
- [ ] Set up Swift Package Manager dependencies:
  - `firebase-ios-sdk`
  - `Stripe iOS SDK`
  - `Alamofire` (optional)
  - `Lottie` (animations)
- [ ] Initialize Node.js/TypeScript backend project
  - `npm init`, `tsconfig.json`, `eslint`, `prettier`
  - Install: `express`, `prisma`, `@prisma/client`, `jsonwebtoken`, `stripe`, `aws-sdk`, `openai`
- [ ] Set up Docker + `docker-compose.yml` (PostgreSQL + Redis)
- [ ] Initialize Prisma and create first database migration
- [ ] Configure environment variables (`.env.example` for both iOS and backend)
- [ ] Set up GitHub Actions CI pipeline (build + lint on PR)
- [ ] Set up App Store Connect app record + bundle ID `com.epoxybidpro.app`
- [ ] Configure Firebase project (Auth + FCM)

---

## Phase 1 — Core iOS Foundation

**Goal:** Navigation shell, authentication, design system, and offline-first data persistence.

**Estimated Duration:** 2–3 weeks

### 1.1 Design System

- [ ] Define color palette (brand colors: epoxy blues/grays/professional)
- [ ] Define typography scale (SF Pro system font + custom heading weights)
- [ ] Create reusable SwiftUI components:
  - `EBPButton` (primary, secondary, destructive styles)
  - `EBPTextField` + `EBPFormField`
  - `EBPCard` (list cards with shadow/corner radius)
  - `EBPBadge` (status: Lead / Active / Complete / Invoiced)
  - `EBPLoadingView`, `EBPEmptyState`
  - `EBPNavigationBar` (custom nav bar with branding)
- [ ] Dark mode support throughout
- [ ] iPad split-view layout support
- [ ] Haptic feedback utility

### 1.2 Authentication

- [ ] Sign in with Apple (primary)
- [ ] Email/password auth (Firebase)
- [ ] Onboarding flow:
  - Welcome screen with app value prop
  - Business profile setup (company name, logo, license #, address, phone)
  - First crew member setup
- [ ] Biometric lock (Face ID / Touch ID) for app re-entry
- [ ] JWT token management + auto-refresh
- [ ] Secure keychain storage for tokens

### 1.3 Navigation & Shell

- [ ] Tab bar navigation:
  - Dashboard (home icon)
  - CRM (people icon)
  - Scan / New Bid (LiDAR icon — center featured button)
  - Jobs (briefcase icon)
  - More (ellipsis — settings, reports, invoicing)
- [ ] Deep link support (`epoxybidpro://`)

### 1.4 Offline-First Persistence

- [ ] SwiftData schema for all core models (see data models below)
- [ ] Sync manager: queue offline changes → sync on reconnect
- [ ] Conflict resolution strategy (server wins for shared records, client wins for local drafts)
- [ ] Network reachability monitor

### 1.5 Core Data Models (SwiftData)

```swift
// Key entities — define all with @Model macro

@Model Client       // CRM contact
@Model Lead         // Pre-client inquiry
@Model Measurement  // LiDAR scan result
@Model Area         // Sub-area within a measurement
@Model Bid          // Bid (pricing + finalized proposal in one)
@Model BidLineItem  // Line item within a bid
@Model BidSignature // E-signature record
@Model Job          // Scheduled/active job
@Model Invoice      // Invoice linked to job
@Model Payment      // Payment record
@Model Photo        // Attached photo
@Model CrewMember   // Team member
@Model Material     // Material catalog item
@Model Template     // Bid/proposal template
```

---

## Phase 2 — LiDAR Scanning Engine

**Goal:** Use the iPhone/iPad LiDAR sensor to scan and measure floors precisely, automatically calculating square footage by room/area.

**Estimated Duration:** 3–4 weeks (most technically complex phase)

### 2.1 LiDAR Feasibility & Setup

- [ ] Confirm device compatibility check at runtime (A12 Pro+ chip required for LiDAR)
- [ ] Graceful fallback for non-LiDAR devices (manual dimension entry)
- [ ] Configure `ARWorldTrackingConfiguration` with `sceneReconstruction: .meshWithClassification`
- [ ] Enable LiDAR depth API via `ARDepthData`

### 2.2 Room Scanning Flow

- [ ] **Scan Screen UI:**
  - Full-screen AR camera view
  - Animated guide overlay ("Walk around the perimeter of the floor")
  - Real-time mesh visualization (semi-transparent floor highlight)
  - Live running square footage counter during scan
  - "Tap to mark corners" fallback mode
  - Scan quality indicator (coverage %)
  - "Finish Scan" button (appears when coverage is sufficient)

- [ ] **Mesh Processing:**
  - Extract floor plane from ARMeshGeometry
  - Filter mesh vertices to floor classification only
  - Compute floor polygon boundary (convex/concave hull)
  - Calculate area from polygon using Shoelace formula
  - Handle multi-level or split floors

- [ ] **Multi-Area Support:**
  - Scan multiple rooms/areas in sequence
  - Label each area (Garage, Basement, Commercial Bay 1, etc.)
  - Aggregate total sq footage across all areas
  - Individual area breakdown for bidding

- [ ] **Scan Result Screen:**
  - 3D floor plan preview (top-down view of scanned mesh)
  - Per-area breakdown with editable labels and sq footage
  - Manual correction: pinch area to adjust sq footage if needed
  - Export floor plan as image (for proposals)
  - Save scan to job record

### 2.3 Measurement Accuracy

- [ ] LiDAR accuracy validation: test against known dimensions
- [ ] Target accuracy: ±2% or within 1–2 sq ft for typical residential garage (500 sq ft)
- [ ] Unit support: sq ft (primary), sq m (settings toggle)
- [ ] Account for drain covers, pillars, cutouts (manual subtract tool)

### 2.4 Manual Entry Fallback

- [ ] Shape-based entry: Rectangle, L-Shape, T-Shape, Custom polygon drawing
- [ ] Dimension inputs (length × width, with unit selection)
- [ ] Same multi-area aggregation as LiDAR flow

---

## Phase 3 — AI Bidding Engine

**Goal:** Generate accurate, intelligent bids automatically from scan data, material catalog, labor rates, and historical job data.

**Estimated Duration:** 3–4 weeks

### 3.1 Pricing Data Foundation

- [ ] **Material Catalog:**
  - Pre-seeded epoxy product database (water-based, solvent-based, 100% solids, polyaspartic, flake, metallic, quartz)
  - Per-unit cost (gallon), coverage rate (sq ft/gallon), # of coats
  - User can add/edit custom materials
  - Supplier-linked items with price update reminders

- [ ] **Labor Rate Configuration:**
  - Hourly rate per crew member
  - Typical hours by job type and sq footage range
  - Overhead/burden rate (%)
  - Drive time billing settings

- [ ] **Business Settings for Bidding:**
  - Default markup % (materials)
  - Desired profit margin %
  - Tax rate
  - Travel/mobilization fee
  - Minimum job price

### 3.2 Rule-Based Pricing Engine (v1)

- [ ] Core formula:
  ```
  Material Cost = Σ(sq_ft / coverage_rate × cost_per_unit × num_coats) × (1 + waste_factor)
  Labor Cost    = estimated_hours × hourly_rate × num_crew
  Overhead      = (Material + Labor) × overhead_rate
  Subtotal      = Material + Labor + Overhead + Mobilization
  Markup        = Subtotal × markup_pct
  Total Bid     = Subtotal + Markup + Tax
  ```
- [ ] Configurable complexity multipliers:
  - Floor condition (excellent / good / fair / poor) → labor multiplier
  - Surface prep required (grind, shot blast, acid etch, patch cracks)
  - Coating system (1-coat clear, 2-coat flake, full metallic, commercial grade)
  - Access difficulty (basement, outdoor, elevated)
- [ ] Waste factor defaults: 10% standard, 15% complex layouts
- [ ] Multiple bid option tiers: Good / Better / Best (three pricing options)

### 3.3 AI Layer (GPT-4o Integration)

- [ ] Send job context to GPT-4o via backend API:
  - Square footage, area types, surface condition, coating system
  - Local market context (input by user or geo-detected)
  - Historical win/loss data from user's own jobs
- [ ] GPT-4o returns:
  - Bid justification narrative (used in proposal)
  - Risk flags ("Heavily pitted concrete — recommend additional prep time")
  - Suggested upsells ("Cove base installation would add $X and increase value")
  - Competitive pricing commentary
- [ ] AI bid review screen: accept, modify, or override AI suggestions
- [ ] AI learns from user corrections over time (fine-tuning pipeline — Phase 2 of AI)

### 3.4 Core ML Local Model (v2 — post-launch)

- [ ] Train pricing model on anonymized aggregate job data
- [ ] Export as `.mlmodel` for on-device inference
- [ ] Works offline, no API call required
- [ ] Feeds predictions into the bidding engine as an additional signal

### 3.5 Bid Builder UI

- [ ] **New Bid Flow:**
  1. Select or create client
  2. Attach LiDAR scan (or enter manually)
  3. Select coating system(s) per area
  4. Select surface prep requirements
  5. Review auto-generated line items
  6. AI suggestions panel (expandable)
  7. Edit/override any line item
  8. Choose Good/Better/Best tier
  9. Preview bid summary
  10. Save as Draft → Finalize & Send Bid

- [ ] Live price preview updates as user adjusts line items
- [ ] Margin calculator overlay (shows profit % in real time)
- [ ] Material quantity list (auto-generated shopping list)
- [ ] Save bid templates for recurring job types

---

## Phase 4 — CRM Module

**Goal:** Full client and lead management to track every relationship from inquiry to repeat business.

**Estimated Duration:** 2–3 weeks

### 4.1 Lead Management

- [ ] Lead capture form (shareable web link for inbound leads)
- [ ] Lead statuses: `New → Contacted → Site Visit Scheduled → Bid Sent → Won / Lost`
- [ ] Lead source tracking: referral, Google, Yelp, Facebook, door hanger, other
- [ ] Lead age indicator (how many days since inquiry)
- [ ] Bulk lead import (CSV)
- [ ] Lost reason tracking + analytics

### 4.2 Client Profiles

- [ ] Contact info (name, phone, email, address with MapKit preview)
- [ ] Client type: Residential / Commercial / Multi-Family / Industrial
- [ ] Full job history (all bids, jobs, invoices linked)
- [ ] Total lifetime revenue display
- [ ] Notes & activity log (timestamped)
- [ ] Photo gallery (all job photos linked to client)
- [ ] Tags/labels (VIP, Commercial Account, etc.)

### 4.3 Communication

- [ ] One-tap call / text / email from client profile
- [ ] SMS templates (appointment reminders, bid follow-ups)
- [ ] Email templates (bid delivery, invoice, follow-up)
- [ ] Communication log (track outgoing calls/texts/emails)
- [ ] Appointment reminders (push notification + SMS)
- [ ] Automated follow-up sequences (Day 1, Day 3, Day 7 after bid sent)

### 4.4 Pipeline View

- [ ] Kanban board: visualize leads/clients across pipeline stages
- [ ] Drag-and-drop stage changes
- [ ] Revenue at each pipeline stage
- [ ] Filter by source, date range, value

---

## Phase 5 — Bid & Proposal Generation

**Goal:** Generate polished, branded PDF proposals that wow clients and win jobs — produced in the field in under 2 minutes.

**Estimated Duration:** 2 weeks

### 5.1 Proposal Builder

- [ ] Pull from bid data automatically
- [ ] Cover page: company logo, client name, property address, date, bid number
- [ ] Executive summary (AI-generated or user-defined)
- [ ] Scope of Work section:
  - Per-area breakdown with sq footage
  - Coating system description
  - Prep work included
  - Estimated timeline
- [ ] Investment section (pricing — tiered or single)
- [ ] Product information (epoxy brand/specs)
- [ ] Warranty terms (configurable)
- [ ] Terms & Conditions (configurable boilerplate)
- [ ] Company credentials / about section
- [ ] Optional before/after photo gallery (from previous jobs)

### 5.2 Branding & Templates

- [ ] Upload company logo
- [ ] Brand color configuration (primary + accent)
- [ ] Multiple proposal layout templates (professional, modern, minimal)
- [ ] Custom footer text
- [ ] Template preview gallery

### 5.3 Delivery & E-Signature

- [ ] Generate PDF via PDFKit
- [ ] Share sheet: AirDrop, Email (in-app mail compose), iMessage, WhatsApp
- [ ] **E-signature integration** (DocuSign API or native drawing canvas)
  - Client signs on contractor's device in person
  - Or receives link via email/SMS to sign remotely
- [ ] Bid status tracking: Draft → Sent → Viewed → Signed → Declined
- [ ] View receipt (opens push notification when client opens bid PDF)

### 5.4 Bid Management

- [ ] Bid list with status badges
- [ ] Expiration date (auto-reminder 24h before expiry)
- [ ] One-tap "Convert Bid to Job" on acceptance
- [ ] Bid versioning (v1, v2 if revised)
- [ ] Clone bid for similar jobs

---

## Phase 6 — Job Management & Scheduling

**Goal:** Track every active job from kickoff to completion, schedule crew, and keep everyone on the same page.

**Estimated Duration:** 2–3 weeks

### 6.1 Job Dashboard

- [ ] Job statuses: `Scheduled → In Progress → Punch List → Complete → Invoiced → Paid`
- [ ] Job card shows: client, address, date, coating system, sq footage, assigned crew
- [ ] Color-coded by status
- [ ] Filter: by date, status, crew member, region

### 6.2 Calendar & Scheduling

- [ ] Monthly/weekly/daily calendar view (native feel)
- [ ] Drag-and-drop rescheduling
- [ ] Crew availability view (who's free on a given day)
- [ ] Travel time estimation between jobs (MapKit)
- [ ] iCal / Google Calendar sync
- [ ] Conflict detection (double-booked crew or equipment)

### 6.3 Job Detail Screen

- [ ] Client & property info (tap to navigate in Maps)
- [ ] Scope of work summary
- [ ] Assigned crew list
- [ ] Materials needed (auto-generated from bid)
- [ ] Checklist:
  - Surface prep steps
  - Primer / base coat / broadcast / topcoat stages
  - Final inspection
  - Cleanup
- [ ] Stage photo capture prompts (at each checklist step)
- [ ] Job notes / field notes
- [ ] Mark job complete → trigger invoice creation

### 6.4 Crew Management

- [ ] Crew member profiles (name, phone, role, hourly rate)
- [ ] Crew assignment to jobs
- [ ] Crew schedule view (per crew member)
- [ ] Time tracking (clock in/out per job)
- [ ] Job completion reports per crew member

### 6.5 Materials & Equipment

- [ ] Auto-generate materials list from bid
- [ ] Mark materials as "purchased / on-site / used"
- [ ] Equipment checklist per job type
- [ ] Supplier contact links

---

## Phase 7 — Invoicing & Payments

**Goal:** Get paid faster with professional invoices and integrated payment collection.

**Estimated Duration:** 2 weeks

### 7.1 Invoice Generation

- [ ] Auto-generate invoice from completed job (pulls all data from bid)
- [ ] Invoice line items (match bid or allow final adjustments)
- [ ] Deposit invoice (% of total, sent at booking)
- [ ] Progress billing (milestone-based)
- [ ] Final invoice
- [ ] Tax calculation (tax rate by state/locale)
- [ ] Discount / credit application
- [ ] Professional PDF invoice (branded, matching proposal style)

### 7.2 Payment Collection (Stripe)

- [ ] Stripe Connect integration (contractor's Stripe account)
- [ ] Payment link embedded in invoice (email/SMS)
- [ ] Accept:
  - Credit / debit card
  - ACH bank transfer (lower fees for large jobs)
  - Apple Pay
- [ ] In-person payment: tap-to-pay (Stripe Terminal / iPhone tap-to-pay)
- [ ] Partial payment tracking
- [ ] Automatic payment receipts (email to client)
- [ ] Stripe payout scheduling

### 7.3 Invoice Tracking

- [ ] Invoice statuses: `Draft → Sent → Partially Paid → Paid → Overdue → Voided`
- [ ] Overdue alerts (push notification + auto-reminder email to client)
- [ ] Aging report (30/60/90 day overdue buckets)
- [ ] One-tap payment reminder send
- [ ] QuickBooks / Xero export (CSV or direct API — Phase 2)

---

## Phase 8 — Photo & Document Management

**Goal:** Complete visual documentation of every job for quality control, warranties, and marketing.

**Estimated Duration:** 1–2 weeks

### 8.1 Photo Capture

- [ ] In-app camera (AVFoundation) — full resolution capture
- [ ] Photo categories: Before, During, After, Surface Condition, Damage, Marketing
- [ ] Bulk upload from photo library
- [ ] Auto-watermarking with company name + date (optional)
- [ ] GPS coordinates embedded in photo metadata
- [ ] Timestamp overlay option

### 8.2 Photo Organization

- [ ] Photos linked to: Job, Client, Quote
- [ ] Timeline view per job
- [ ] Before/After comparison slider (immersive UI)
- [ ] Gallery grid view
- [ ] Mark photos as "Proposal Ready" (curated set for use in future quotes)

### 8.3 Cloud Storage

- [ ] Auto-upload to AWS S3 on WiFi
- [ ] Local cache for offline viewing
- [ ] Compression settings (balance quality vs storage cost)
- [ ] Client photo sharing: generate temporary share link

### 8.4 Document Storage

- [ ] Store signed quotes, invoices, warranties
- [ ] Attach files from Files app (supplier quotes, permits)
- [ ] Document viewer in-app

---

## Phase 9 — Analytics & Reporting Dashboard

**Goal:** Give business owners clear visibility into revenue, performance, and growth opportunities.

**Estimated Duration:** 2 weeks

### 9.1 Business Dashboard (Home)

- [ ] Revenue this week / month / year (Swift Charts bar graph)
- [ ] Active jobs count
- [ ] Open quotes (total value)
- [ ] Overdue invoices (alert badge)
- [ ] Recent activity feed

### 9.2 Sales Analytics

- [ ] Quote win rate (% won vs sent)
- [ ] Win rate by job type, size, coating system
- [ ] Avg. quote value
- [ ] Avg. time to close (quote sent → signed)
- [ ] Revenue by lead source (ROI per channel)
- [ ] Seasonal trends (revenue by month over years)

### 9.3 Job Profitability

- [ ] Actual vs. estimated cost per job
- [ ] Margin per job (actual)
- [ ] Best and worst performing job types (by margin)
- [ ] Material cost tracking (actual vs. estimated)
- [ ] Labor hours: estimated vs. actual (time tracking)

### 9.4 CRM Analytics

- [ ] Lead pipeline value
- [ ] Lost deal analysis (loss reasons breakdown)
- [ ] Client lifetime value
- [ ] Best clients by revenue
- [ ] Geographic heat map of job locations (MapKit overlay)

### 9.5 Reports

- [ ] Weekly business summary (PDF export)
- [ ] Monthly P&L overview
- [ ] Crew performance report
- [ ] Tax prep report (revenue, expenses, by date range)
- [ ] Export all data as CSV

---

## Phase 10 — Backend & API Layer

**Goal:** Secure, scalable backend to power sync, AI, payments, storage, and notifications.

**Estimated Duration:** Concurrent with iOS phases (4–6 weeks total)

### 10.1 Database Schema (PostgreSQL via Prisma)

```prisma
// Core models — abbreviated

model User          // Business owner / admin
model Subscription  // Plan tiers
model Client
model Lead
model Measurement   // LiDAR scan data (JSON polygon)
model Bid
model LineItem
model Quote
model Signature
model Job
model JobStage
model CrewMember
model TimeEntry
model Invoice
model Payment
model Photo
model Document
model Material
model Template
model AuditLog
```

### 10.2 API Endpoints

**Auth**
- `POST /auth/apple` — Apple Sign In verification
- `POST /auth/refresh` — JWT refresh
- `POST /auth/register` — New business account

**Clients & Leads**
- `GET/POST/PUT/DELETE /clients`
- `GET/POST/PUT/DELETE /leads`
- `POST /leads/import` — CSV import

**Measurements**
- `POST /measurements` — Upload scan result
- `GET /measurements/:jobId`

**Bids**
- `POST /bids/generate` — Trigger AI bid generation
- `GET/PUT/DELETE /bids/:id`
- `POST /bids/:id/ai-suggest` — AI suggestions call to OpenAI

**Quotes**
- `GET/POST/PUT/DELETE /quotes`
- `POST /quotes/:id/send` — Email/SMS delivery
- `POST /quotes/:id/sign` — Record signature
- `GET /quotes/:id/pdf` — Generate PDF

**Jobs**
- `GET/POST/PUT/DELETE /jobs`
- `PUT /jobs/:id/status`
- `POST /jobs/:id/checklist`

**Invoices & Payments**
- `GET/POST /invoices`
- `POST /invoices/:id/send`
- `POST /payments/create-intent` — Stripe PaymentIntent
- `POST /payments/webhook` — Stripe webhook handler

**Photos / Files**
- `POST /photos/upload-url` — Pre-signed S3 URL
- `POST /photos/record` — Record photo metadata after upload
- `DELETE /photos/:id`

**Analytics**
- `GET /analytics/dashboard`
- `GET /analytics/revenue?range=30d|90d|1y`
- `GET /analytics/jobs/profitability`
- `GET /analytics/crm/pipeline`

**Notifications**
- `POST /notifications/register-device` — FCM token
- `POST /notifications/send` — Internal trigger

### 10.3 AI Service

- [ ] OpenAI API wrapper service
- [ ] Prompt templates for bid generation, risk analysis, upsell suggestions
- [ ] Rate limiting / cost controls (per user per day)
- [ ] Response caching (similar scan inputs → cached response)
- [ ] Logging for AI inputs/outputs (for fine-tuning dataset)

### 10.4 Security

- [ ] JWT auth middleware on all protected routes
- [ ] Row-level security: users only access their own business data
- [ ] HTTPS enforced (TLS 1.3)
- [ ] Input validation (Zod schemas)
- [ ] Rate limiting (express-rate-limit)
- [ ] OWASP security headers
- [ ] Stripe webhook signature verification
- [ ] PII encryption at rest (client contact data)

### 10.5 Infrastructure

- [ ] Docker Compose for local dev (Postgres + Redis + API)
- [ ] AWS deployment:
  - EC2 (API server) or AWS Lambda (serverless option)
  - RDS PostgreSQL (Multi-AZ for production)
  - S3 + CloudFront (photos/PDFs — CDN delivery)
  - ElastiCache Redis (session + caching)
- [ ] Environment configs: `development`, `staging`, `production`
- [ ] Automated DB backups (daily snapshots, 30-day retention)
- [ ] Logging: CloudWatch + structured JSON logs

---

## Phase 11 — Testing & QA

**Goal:** Ship a stable, reliable app with a rigorous testing strategy.

**Estimated Duration:** 2–3 weeks (interleaved throughout development)

### 11.1 iOS Testing

- [ ] **Unit Tests (XCTest):**
  - Pricing engine calculations (all formula paths)
  - LiDAR area calculation (Shoelace formula)
  - Data model validation
  - JWT token parsing
  - PDF generation
  - Target: 80% code coverage on business logic

- [ ] **UI Tests (XCUITest):**
  - Auth flow (sign up, sign in, biometric)
  - Full bid creation flow
  - Quote send flow
  - Invoice payment flow

- [ ] **Device Testing:**
  - iPhone 15 Pro (LiDAR)
  - iPhone 14 (no LiDAR — fallback test)
  - iPad Pro 12.9" (primary field device)
  - iPad Air (LiDAR — M1+)

- [ ] **AR/LiDAR Testing:**
  - Real-world scan accuracy tests (multiple room sizes)
  - Low-light scan behavior
  - Highly reflective surfaces (metallic epoxy itself)

### 11.2 Backend Testing

- [ ] **Unit Tests (Jest):**
  - All service layer functions
  - Pricing calculation parity with iOS engine
  - JWT utilities

- [ ] **Integration Tests:**
  - API endpoints (Supertest)
  - Stripe payment flow (test mode)
  - Email/SMS delivery (test mode)
  - S3 upload flow

- [ ] **Load Testing (k6):**
  - 100 concurrent users
  - PDF generation under load
  - AI bid endpoint response time

### 11.3 Beta Testing

- [ ] TestFlight internal build (team testing — 2 weeks)
- [ ] TestFlight external beta (10–20 real epoxy contractors — 3 weeks)
- [ ] Collect feedback via in-app survey (Typeform link)
- [ ] Bug tracking: GitHub Issues with priority labels

---

## Phase 12 — App Store Submission & Launch

**Goal:** Successful App Store approval and initial launch with marketing support.

**Estimated Duration:** 2–3 weeks

### 12.1 Pre-Submission Checklist

- [ ] App Store metadata complete:
  - App name, subtitle, description (keyword-optimized)
  - Keywords (epoxy bidding, floor contractor app, LiDAR measurement)
  - Screenshots: iPhone 6.9", iPhone 6.5", iPad 12.9" (all screen sizes)
  - App Preview video (30s demo of LiDAR scan → bid → proposal)
  - Support URL, Privacy Policy URL, Terms of Service
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) — required by Apple
- [ ] All required permissions justified in Info.plist:
  - Camera, LiDAR (ARKit), Location, Notifications, Face ID, Photo Library
- [ ] App Store Review Guidelines compliance audit
- [ ] Pricing: Subscription model
  - Free trial: 14 days
  - Solo plan: $49.99/month
  - Team plan: $99.99/month (up to 5 crew)
  - Enterprise: Custom

### 12.2 Submission Process

- [ ] Archive and upload build via Xcode Organizer
- [ ] Submit for App Store Review (allow 1–3 business days)
- [ ] Respond to any App Review rejections within 24h
- [ ] Gradual rollout: 10% → 50% → 100% (phased release)

### 12.3 Marketing Launch

- [ ] Landing page: `epoxybidpro.com`
  - Hero: LiDAR scan → instant bid demo GIF
  - Feature highlights
  - Pricing table
  - Testimonials (from beta testers)
  - App Store download badge
- [ ] Demo video uploaded to YouTube
- [ ] Epoxy contractor Facebook groups outreach
- [ ] Partnerships: IFCII, epoxy supplier reps, industry forums
- [ ] Launch promo: first 100 users get 60-day free trial
- [ ] Press kit for trade publications

---

## Post-Launch Roadmap

### v1.1 (Month 1–2 post-launch)
- [ ] Bug fixes from launch feedback
- [ ] Android / iPad-optimized layout improvements
- [ ] QuickBooks Online integration
- [ ] Push notification improvements

### v1.2 (Month 2–3)
- [ ] AI model fine-tuning (pricing predictions from real job data)
- [ ] Multi-crew scheduling board
- [ ] Client portal (web view for clients to track job status)
- [ ] Referral tracking in CRM

### v2.0 (Month 4–6)
- [ ] Core ML on-device pricing model (offline AI)
- [ ] Apple Watch companion (job timer, quick notes)
- [ ] Android app (React Native rewrite or Flutter)
- [ ] Team messaging / in-app chat per job
- [ ] Supplier integrations (live material pricing from Sherwin-Williams, HD Supply)

### v2.5 (Month 6–9)
- [ ] Marketplace: connect clients to certified EpoxyBidPro contractors
- [ ] 3D floor plan export (AR Quick Look for client preview)
- [ ] Custom AR visualizer (show client how coating will look on their floor)
- [ ] Multi-location / franchise support

---

## Milestones Summary

| Milestone                         | Target Duration  | Cumulative  |
|-----------------------------------|------------------|-------------|
| Phase 0 — Bootstrap               | Week 1           | Week 1      |
| Phase 1 — Core iOS Foundation     | Weeks 2–4        | Week 4      |
| Phase 2 — LiDAR Scanning Engine   | Weeks 3–6        | Week 6      |
| Phase 3 — AI Bidding Engine       | Weeks 5–8        | Week 8      |
| Phase 4 — CRM Module              | Weeks 7–9        | Week 9      |
| Phase 5 — Quote & Proposal Gen    | Weeks 9–10       | Week 10     |
| Phase 6 — Job Management          | Weeks 10–12      | Week 12     |
| Phase 7 — Invoicing & Payments    | Weeks 11–12      | Week 12     |
| Phase 8 — Photo Management        | Weeks 12–13      | Week 13     |
| Phase 9 — Analytics               | Weeks 13–14      | Week 14     |
| Phase 10 — Backend (concurrent)   | Weeks 1–14       | Week 14     |
| Phase 11 — Testing & QA           | Weeks 12–16      | Week 16     |
| Phase 12 — App Store Launch       | Weeks 17–18      | **Week 18** |

> **Total estimated time to App Store launch: ~18 weeks (4.5 months)**
> This assumes 1–2 dedicated full-stack iOS developers. Add 20–30% buffer for LiDAR complexity and App Store review cycles.

---

## Developer Notes

### Key Technical Risks & Mitigations

| Risk                              | Severity | Mitigation                                              |
|-----------------------------------|----------|---------------------------------------------------------|
| LiDAR accuracy on unusual floors  | High     | Manual entry fallback always available                  |
| App Store rejection (AR/payments) | Medium   | Follow guidelines strictly, thorough privacy manifest   |
| AI bid accuracy early on          | Medium   | User correction feedback loop, rule-based engine as base|
| Stripe Connect complexity         | Medium   | Start with standard Stripe, Connect in v1.1             |
| Offline sync conflicts            | Medium   | Conservative merge strategy, clear UI for conflicts     |
| SwiftData migration stability     | Low-Med  | Thorough migration tests, Core Data fallback plan       |

### Coding Standards

- Swift: SwiftLint enforced, async/await everywhere (no completion handlers)
- Backend: ESLint + Prettier, strict TypeScript (`strict: true`)
- Commits: Conventional Commits format (`feat:`, `fix:`, `chore:`)
- PRs require 1 reviewer approval + passing CI
- No secrets in code — all via environment variables / keychain

### Branch Strategy

```
main          ← production releases only
develop       ← integration branch
feature/*     ← individual features
fix/*         ← bug fixes
release/*     ← release candidate staging
```

---

*Last updated: February 18, 2026*
*Owner: EpoxyBidPro Dev Team*
