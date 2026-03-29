# 01_PROJECT_META.md
# CRM + Project Management Platform — Project Overview & Setup

## 1. OVERVIEW
Production-grade CRM + Deal Pipeline + Project Execution backend. The system manages the complete business lifecycle:

```
Lead → Opportunity (Deal) → Project → Tasks → Execution → Monitoring → Reporting
```

Supports lead capturing from multiple sources, deal pipeline management, project and task execution, stakeholder communication, document management, workflow automation, SLA tracking, real-time dashboards, RBAC, and full audit traceability.

### Tech Stack
| Layer | Technology | Version |
|-------|-----------|---------|
| Runtime | Node.js | 20.20.1 (LTS) |
| Framework | NestJS | 10.4.5 |
| Language | TypeScript | 5.5.3 (strict) |
| Database | PostgreSQL | 17 |
| Auth | Cookie-based sessions | HttpOnly |
| Validation | class-validator | 0.14.1 |
| API Docs | Swagger / OpenAPI | 3.0 |
| Scheduling | @nestjs/schedule | 4.1.0 |

`HTTP Request → SessionGuard → Controller (DTO Validate) → Service → DatabaseService → PG Dispatcher → ResponseInterceptor`

### Global Standards (Anti-Hallucination)
- **Filenames**: Always `kebab-case` for NestJS files, `snake_case` for SQL.
- **Primary Keys**: Always `UUID`. Never `SERIAL/INT`.
- **Time/Dates**: Always `TIMESTAMPTZ`, stored in UTC.
- **Error Format**: Always use `fn_error_envelope(rid, statusCode, message)`.
- **Soft Deletes**: `deleted_at = NOW()`. Never `DELETE FROM`.

---

## 2. SETUP & DEPENDENCIES

### Exact Version Pins (package.json)
```json
{
  "dependencies": {
    "@nestjs/common":           "10.4.5",
    "@nestjs/core":             "10.4.5",
    "@nestjs/platform-express": "10.4.5",
    "@nestjs/config":           "3.2.3",
    "@nestjs/schedule":         "4.1.0",
    "@nestjs/swagger":          "7.x",
    "@nestjs/throttler":        "6.2.1",
    "pg":                       "8.12.0",
    "bcrypt":                   "5.1.1",
    "cookie-parser":            "1.4.6",
    "class-validator":          "0.14.1",
    "class-transformer":        "0.5.1",
    "helmet":                   "7.1.0",
    "multer":                   "1.4.5-lts.1",
    "joi":                      "17.13.3"
  }
}
```

### Environment (.env.example)
```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/crm_core_local?search_path=crm,public
SESSION_COOKIE_NAME=crm_session
SESSION_MAX_AGE_MS=604800000
SESSION_SECRET=change_this_in_production
UPLOAD_DIR=./uploads
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=notifications@crm.local
MAIL_PASS=change_this
MAIL_FROM=notifications@crm.local
THROTTLE_TTL=60000
THROTTLE_LIMIT=100
```

### Setup Steps
1. `CREATE SCHEMA IF NOT EXISTS crm;`
2. `CREATE EXTENSION IF NOT EXISTS "pgcrypto", "uuid-ossp", "pg_trgm";`
3. `npm install`
4. `npm run db:migrate` (runs all V000–V085 migrations via `tools/migrate.js`)
5. `npm run start:dev`

---

## 3. SCOPE AUDIT & MODULE COVERAGE

### Module Status
| Module | Coverage | Status |
|--------|---------|--------|
| **4.1 Lead Management** | Intake, Pipeline, Round-Robin Pool, Manual/Claim | ✅ DONE |
| **4.2 Opportunity Management** | Prospecting → Negotiation → Won/Lost, Auto-creates Project | ✅ DONE |
| **4.3 Project Management** | Phases, Milestones, Templates, Health, Stakeholders | ✅ DONE |
| **4.4 Task Management** | Kanban, Dependencies, Time Tracking, Escalations | ✅ DONE |
| **4.5 Contact & Stakeholder** | Multi-category, Addresses, Account Links | ✅ DONE |
| **4.6 Account Management** | Company, Individual, Partner types | ✅ DONE |
| **4.7 Document Management** | Versioning, Approval Workflow, Secure Sharing | ✅ DONE |
| **4.8 Activity & Timeline** | Unified feed: Calls, Meetings, Emails, Notes, Events | ✅ DONE |
| **4.9 Notes System** | Entity-agnostic notes with pin, timeline mirror | ✅ DONE |
| **4.10 Communications** | Full log with backward compat from Activities | ✅ DONE |
| **4.11 Assignment System** | Round-robin pools, pool-pick, manual, history | ✅ DONE |
| **4.12 SLA & Escalation** | Policy CRUD, breach detection (cron), escalation logs | ✅ DONE |
| **4.13 Workflow Automation** | Event triggers, configurable rules, workflow executions | ✅ DONE |
| **4.14 Reporting & Dashboards** | Pipeline, Deal, Project Health, SLA, Activity, CSV Export | ✅ DONE |
| **4.15 RBAC** | Dynamic permissions, role-based record access | ✅ DONE |
| **4.16 Audit Trail** | Full change history, old/new values, triggers on all tables | ✅ DONE |
| **4.17 Quotations** | Quotation lifecycle with line items and tax | ✅ DONE |
| **4.18 Expenses** | Project expenses with receipts and categories | ✅ DONE |
| **4.19 Search** | Global full-text search via pg_trgm GIN indexes | ✅ DONE |

### System Totals
- **Tables**: 42 (including 7 new tables added in V078)
- **DB Dispatcher Functions**: 20+
- **Migrations**: 86 (V000–V085)
- **NestJS Modules**: 27
- **REST Endpoints**: 180+
- **Roles**: Admin, Manager, Team Member, External (Architect/PMC/Vendor)

---

## 4. SECURITY BASELINES
- **File Uploads (Multer)**: Max 25MB, allowed MIME: PDF, JPEG, PNG, DOC, DOCX.
- **JSON Body Limit**: 1MB (enforced in `main.ts`).
- **Rate Limiting**: 100 req/min global, 5 req/min on `/auth/*`.
- **Session**: HttpOnly, SameSite: Lax, Secure in production.
- **SQL**: All dispatcher calls use parameterized JSONB payloads. No string interpolation.
- **CORS**: Credentials + origin whitelist enforced.

---

## 5. DEFERRED TO V2
- Two-factor authentication (2FA)
- Client-facing portal / mobile app
- Invoice PDF generation from quotations
- Full ZIP data export
- Email provider integrations (Gmail / Outlook OAuth)
- Messaging integrations (Slack / WhatsApp)
- Cloud storage swap (S3Provider)
