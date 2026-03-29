# 01_PROJECT_META.md
# CRM for Lead Management — Project Overview & Setup

## 1. OVERVIEW
Production-grade CRM backend for lead management, project coordination, task tracking, stakeholder communication, and workflow automation.

### Tech Stack
| Layer      | Technology                                | Version        |
|------------|-------------------------------------------|----------------|
| Runtime    | Node.js                                   | 20.20.1 (LTS)  |
| Framework  | NestJS                                    | 10.4.5         |
| Language   | TypeScript                                | 5.5.3 (strict) |
| Database   | PostgreSQL                                | 17             |
| Auth       | Cookie-based sessions                     | HttpOnly       |
| Validation | class-validator                           | 0.14.1         |

`HTTP Request -> NestJS Controller (Validate) -> NestJS Service (Dispatch) -> PostgreSQL Function (Logic) -> JSON Response`

### Global Standards (Anti-Hallucination)
- **Filenames**: Always `kebab-case` for NestJS files (e.g., `user.controller.ts`) and `snake_case` for SQL (e.g., `fn_user_ops.sql`).
- **Primary Keys**: Always `UUID` (v4/v7). Never `SERIAL/INT`.
- **Time/Dates**: Always `TIMESTAMPTZ`. Storage always in `UTC`.
- **Error Format**: Always use the error envelope defined in `04_API_AUTH_AND_RBAC.md`.

---

## 1.5 DOCUMENTATION INDEX (The 9-File Structure)
1. **[00_AI_CONTEXT.md](00_AI_CONTEXT.md)**: AI Memory Anchor.
2. **[01_PROJECT_META.md](01_PROJECT_META.md)**: Project Overview & Setup.
3. **[02_ARCHITECTURE_STANDARDS.md](02_ARCHITECTURE_STANDARDS.md)**: Development Laws.
4. **[03_DATABASE_CORE.md](03_DATABASE_CORE.md)**: Schema & SQL Dispatchers.
5. **[04_API_AUTH_AND_UI_CONFIG.md](04_API_AUTH_AND_UI_CONFIG.md)**: Auth & API Contracts.
6. **[05_WORKFLOW_AUTOMATION.md](05_WORKFLOW_AUTOMATION.md)**: Automation Engine.
7. **[06_TESTING_AND_SEED.md](06_TESTING_AND_SEED.md)**: QA & Seed Data.
8. **[07_OPERATIONS_LOG.md](07_OPERATIONS_LOG.md)**: Project Health & Logs.
9. **[08_AI_PROMPTS.md](08_AI_PROMPTS.md)**: AI Instruction Sets.

---

## 2. SETUP & DEPENDENCIES

### Exact Version Pins (package.json)
```json
{
  "dependencies": {
    "@nestjs/common":          "10.4.5",
    "@nestjs/core":            "10.4.5",
    "@nestjs/platform-express":"10.4.5",
    "@nestjs/config":          "3.2.3",
    "@nestjs/schedule":        "4.1.0",
    "pg":                      "8.12.0",
    "bcrypt":                  "5.1.1",
    "cookie-parser":           "1.4.6",
    "class-validator":         "0.14.1",
    "class-transformer":       "0.5.1",
    "helmet":                  "7.1.0",
    "multer":                  "1.4.5-lts.1",
    "@nestjs/throttler":       "6.2.1",
    "joi":                     "17.13.3"
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
SESSION_SECRET=change_this
UPLOAD_DIR=./uploads

# Notifications (SMTP/SendGrid)
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=notifications@crm.local
MAIL_PASS=change_this
MAIL_FROM=notifications@crm.local
```

### Setup Steps
1. **Schema**: Run `CREATE SCHEMA IF NOT EXISTS crm;` (Already created by User).
2. **Extensions**: Run `CREATE EXTENSION IF NOT EXISTS "pgcrypto", "uuid-ossp", "pg_trgm";` (Usually in `public` or `crm`).
3. **Install**: `npm install`
4. **Migrate**: `npm run db:migrate` (Targets `crm` schema)
5. **Seed**: `npm run db:seed`
6. **Start**: `npm run start:dev`

---

## 3. SCOPE AUDIT & COVERAGE

### Module Status
| Module | Coverage | Status |
| :--- | :--- | :--- |
| **3.1 Lead Management** | Intake, Pipeline, Conversion | [DONE] |
| **3.2 Project Management**| Phases, Milestones, Templates | [DONE] |
| **3.3 Task Management** | Kanban, Escalations, Templates| [DONE] |
| **3.4 Stakeholders** | Categories, Project Feeds | [DONE] |
| **3.5 Documents** | Versioning, Secure Uploads | [DONE] (V065) |
| **3.6 Automation** | Lead -> Project blueprints | [DONE] (V066) |
| **3.7 RBAC & Settings** | Dynamic permissions, Roles | [DONE] |
| **3.8 Reporting** | CSV Export, Weekly Summary | [DONE] (V049) |
| **3.9 Audit Logs** | Chronological History Feed  | [DONE] (V034) |

### Totals
- **Tables**: 34 Core + Mapping Tables
- **Endpoints**: 140+
- **Migrations**: 65 (Applied & Verified)
- **Roles**: Super Admin, Admin, PM, Team, External (Architect/PMC/Vendor)

---

## 4. SECURITY BASELINES
- **File Uploads (Multer)**: Strictly validate in NestJS.
  - **Max Size**: 25MB per file.
  - **Allowed MIME**: `application/pdf`, `image/jpeg`, `image/png`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`.
  - **Storage**: `./uploads` directory. Never serve statically; always pipe through an authenticated NestJS stream router.

---

## 5. DEFERRED TO V2
- Two-factor authentication (2FA)
- Full data export (ZIP/CSV)
- Mobile App / Client Portal
- Invoice generation from quotations
