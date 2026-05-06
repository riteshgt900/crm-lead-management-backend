# CRM Backend — Quick Reference Guide
**Last Updated**: 2026-04-29  
**Status**: Production Ready (Phase 18)

---

## 🎯 One-Page Project Overview

```
┌─────────────────────────────────────────────────────────────────┐
│         CRM + Project Management Backend (NestJS + PostgreSQL)  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase: 18 (Complete)  │  Status: Production Ready             │
│  Modules: 27           │  Endpoints: 180+                      │
│  Services: 28          │  Controllers: 26                      │
│  Tables: 42+           │  Migrations: 92                       │
│  Functions: 20+        │  Lines of Code: 4,009 TS              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Architecture at a Glance

```
┌──────────────────────────────────────────────────────────────┐
│                    CLIENT REQUEST                            │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  SessionGuard: Validate crm_session cookie                   │
│  → Populate req.user { id, roleId, permissions[] }           │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Controller: Validate DTO, Check @Permissions()              │
│  → Call Service method                                       │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Service: Pass-through                                       │
│  → return this.db.callDispatcher(fnName, payload)            │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  DatabaseService: Whitelist check                            │
│  → Call PostgreSQL dispatcher function                       │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  PostgreSQL Dispatcher: Execute business logic               │
│  → Return JSONB { success, data, errors }                    │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  ResponseInterceptor: Wrap in envelope                       │
│  → { rid, statusCode, data, message, meta }                  │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                    CLIENT RESPONSE                           │
└──────────────────────────────────────────────────────────────┘
```

---

## 🏢 Business Workflow

```
LEAD (Prospect)
  ↓ [Convert]
OPPORTUNITY (Deal Pipeline)
  ├─ Stage: prospecting → proposal → negotiation → won/lost
  ├─ Tracks: revenue, probability, close date
  └─ Auto-creates: Account + Contact
  ↓ [Mark Won]
PROJECT (Execution)
  ├─ Phases & Milestones
  ├─ Tasks & Subtasks (with dependencies)
  ├─ Team Members & Stakeholders
  └─ Activity Timeline
  ↓ [Execute]
TASKS → COMPLETION → REPORTING
```

---

## 📦 Module Organization (27 Total)

```
┌─ INFRASTRUCTURE (4)
│  ├─ DatabaseModule
│  ├─ ConfigModule
│  ├─ ScheduleModule
│  └─ ThrottlerModule
│
├─ AUTH & SECURITY (4)
│  ├─ AuthModule
│  ├─ UsersModule
│  ├─ RbacModule
│  └─ PortalModule
│
├─ CRM PIPELINE (4)
│  ├─ LeadsModule
│  ├─ OpportunitiesModule
│  ├─ AccountsModule
│  └─ ContactsModule
│
├─ PROJECT EXECUTION (4)
│  ├─ ProjectsModule
│  ├─ TasksModule
│  ├─ ActivitiesModule
│  └─ NotesModule
│
├─ WORKFLOW & AUTOMATION (4)
│  ├─ WorkflowsModule
│  ├─ AssignmentsModule
│  ├─ SlasModule
│  └─ CronModule
│
├─ FINANCIALS & COMMUNICATION (4)
│  ├─ QuotationsModule
│  ├─ ExpensesModule
│  ├─ CommunicationsModule
│  └─ NotificationsModule
│
├─ ANALYTICS & ADMIN (5)
│  ├─ DashboardModule
│  ├─ ReportsModule
│  ├─ SearchModule
│  ├─ AuditModule
│  └─ RuntimeModule
│
└─ SUPPORTING (4)
   ├─ DocumentsModule
   ├─ EmailModule
   ├─ IntegrationsModule
   └─ ShareModule
```

---

## 🗄️ Database Schema (42+ Tables)

```
RBAC & Users (6)
├─ roles
├─ permissions
├─ role_permissions
├─ users
├─ sessions
└─ password_reset_tokens

CRM Pipeline (8)
├─ leads
├─ lead_status_history
├─ opportunities
├─ accounts
├─ contacts
├─ contact_addresses
├─ quotations
└─ quotation_items

Project Execution (6)
├─ projects
├─ project_members
├─ project_phases
├─ project_milestones
├─ project_templates
└─ project_stakeholders

Tasks (5)
├─ tasks
├─ task_comments
├─ task_time_logs
├─ task_dependencies
└─ task_watchers

Activity & Engagement (3)
├─ activities
├─ notes
└─ communications

Assignment System (3)
├─ assignment_history
├─ assignment_pools
└─ pool_members

SLA & Escalations (2)
├─ sla_policies
└─ escalation_logs

Documents & Files (3)
├─ documents
├─ document_versions
└─ document_shares

System & Audit (5+)
├─ audit_logs
├─ ai_operation_logs
├─ ui_entity_configs
├─ ui_field_configs
├─ api_endpoint_registry
├─ lookup_sets
├─ lookup_values
├─ custom_field_definitions
├─ saved_filters
└─ record_tags
```

---

## 🔌 API Endpoints by Category

```
Authentication (6)
├─ POST   /auth/login
├─ POST   /auth/logout
├─ GET    /auth/session
├─ GET    /auth/profile
├─ POST   /auth/change-password
└─ POST   /auth/forgot-password

Users & RBAC (12)
├─ GET    /users
├─ POST   /users/invite
├─ GET    /users/:id
├─ PATCH  /users/:id
├─ DELETE /users/:id
├─ GET    /rbac/roles
├─ POST   /rbac/roles
├─ GET    /rbac/roles/:id
├─ PATCH  /rbac/roles/:id
├─ DELETE /rbac/roles/:id
├─ GET    /rbac/permissions
└─ POST   /rbac/roles/:id/permissions

Leads (10)
├─ GET    /leads
├─ POST   /leads
├─ GET    /leads/:id
├─ PATCH  /leads/:id
├─ DELETE /leads/:id
├─ PATCH  /leads/:id/status
├─ POST   /leads/:id/convert
├─ POST   /leads/:id/assign
├─ POST   /leads/:id/claim
└─ POST   /leads/bulk

Opportunities (10)
├─ GET    /opportunities
├─ POST   /opportunities
├─ POST   /opportunities/get
├─ GET    /opportunities/:id
├─ PATCH  /opportunities/:id
├─ DELETE /opportunities/:id
├─ POST   /opportunities/:id/stage
├─ POST   /opportunities/:id/win
├─ POST   /opportunities/:id/lose
└─ POST   /opportunities/:id/assign

Projects (12)
├─ GET    /projects
├─ POST   /projects
├─ GET    /projects/:id
├─ PATCH  /projects/:id
├─ DELETE /projects/:id
├─ GET    /projects/:id/tasks
├─ GET    /projects/:id/activity
├─ GET    /projects/templates
├─ POST   /projects/:id/phases
├─ PATCH  /projects/:id/phases/:phaseId
├─ POST   /projects/:id/milestones
└─ PATCH  /projects/:id/milestones/:milestoneId

Tasks (10)
├─ GET    /tasks
├─ POST   /tasks
├─ GET    /tasks/:id
├─ PATCH  /tasks/:id
├─ DELETE /tasks/:id
├─ POST   /tasks/:id/comments
├─ GET    /tasks/:id/time-logs
├─ POST   /tasks/:id/time-logs
├─ POST   /tasks/:id/dependencies
└─ PATCH  /tasks/:id/status

Activities, Notes & Communications (15)
├─ GET    /activities
├─ POST   /activities
├─ GET    /activities/:id
├─ GET    /notes
├─ POST   /notes
├─ PATCH  /notes/:id
├─ DELETE /notes/:id
├─ POST   /notes/:id/pin
├─ GET    /communications
├─ POST   /communications
├─ GET    /communications/:id
├─ PATCH  /communications/:id
├─ DELETE /communications/:id
├─ GET    /contacts
└─ POST   /contacts

Assignments & SLAs (12)
├─ GET    /assignments/pools
├─ POST   /assignments/pools
├─ GET    /assignments/pools/:id
├─ PATCH  /assignments/pools/:id
├─ DELETE /assignments/pools/:id
├─ POST   /assignments/pools/:id/members
├─ GET    /slas
├─ POST   /slas
├─ GET    /slas/:id
├─ PATCH  /slas/:id
├─ DELETE /slas/:id
└─ GET    /slas/breaches

Documents, Quotations & Expenses (18)
├─ GET    /documents
├─ POST   /documents
├─ GET    /documents/:id
├─ PATCH  /documents/:id
├─ DELETE /documents/:id
├─ GET    /documents/:id/versions
├─ POST   /documents/:id/share
├─ GET    /quotations
├─ POST   /quotations
├─ GET    /quotations/:id
├─ PATCH  /quotations/:id
├─ DELETE /quotations/:id
├─ GET    /expenses
├─ POST   /expenses
├─ GET    /expenses/:id
├─ PATCH  /expenses/:id
├─ DELETE /expenses/:id
└─ GET    /accounts

Dashboard, Reports & Search (9)
├─ GET    /dashboard/kpis
├─ GET    /dashboard/pipeline
├─ GET    /dashboard/projects
├─ GET    /reports
├─ POST   /reports/export
├─ GET    /search
├─ POST   /search/advanced
├─ GET    /runtime/metadata
└─ GET    /portal/projects

Portal (Guest Auth) (8)
├─ POST   /portal/auth/login
├─ POST   /portal/auth/logout
├─ GET    /portal/projects
├─ GET    /portal/projects/:id
├─ GET    /portal/projects/:id/tasks
├─ POST   /portal/tasks/:id/comments
├─ GET    /portal/documents
└─ POST   /portal/documents/upload
```

---

## 🔐 Security Layers

```
┌─────────────────────────────────────────┐
│  1. Helmet.js (HTTP Headers)            │
├─────────────────────────────────────────┤
│  2. CORS (Origin Whitelist)             │
├─────────────────────────────────────────┤
│  3. Rate Limiting (100 req/min)         │
├─────────────────────────────────────────┤
│  4. Body Limits (1MB JSON, 25MB files)  │
├─────────────────────────────────────────┤
│  5. SQL Injection Prevention            │
│     (Parameterized queries)             │
├─────────────────────────────────────────┤
│  6. Session Security                    │
│     (HttpOnly, SameSite, Secure)        │
├─────────────────────────────────────────┤
│  7. RBAC Hierarchy                      │
│     (super_admin > admin > manager...)  │
├─────────────────────────────────────────┤
│  8. Soft Deletes                        │
│     (Never hard delete)                 │
├─────────────────────────────────────────┤
│  9. Audit Trail                         │
│     (All changes tracked)               │
└─────────────────────────────────────────┘
```

---

## 📋 Response Envelope Format

```json
{
  "rid": "s-lead-create",
  "statusCode": 201,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Acme Corp",
    "email": "contact@acme.com",
    "status": "new",
    "created_at": "2026-04-29T05:45:48Z"
  },
  "message": "Lead created successfully",
  "errors": null,
  "meta": {
    "timestamp": "2026-04-29T05:45:48.892Z"
  }
}
```

---

## 🚀 Quick Commands

```bash
# Setup
npm install
npm run db:migrate
npm run db:seed

# Development
npm run start:dev
npm run lint
npm run format

# Testing
npm test
npm run test:watch
npm run test:cov
npm run test:e2e

# Database
npm run db:dump
npm run contract:frontend
npm run openapi:generate

# Production
npm run build
npm run start:prod
```

---

## 📚 Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| ANALYSIS_SUMMARY.md | Overview of analysis | 15 min |
| PROJECT_ANALYSIS.md | Complete reference | 45 min |
| EXECUTIVE_SUMMARY.md | For stakeholders | 20 min |
| TECHNICAL_ARCHITECTURE.md | For developers | 40 min |
| DOCUMENTATION_INDEX.md | Navigation guide | 10 min |
| docs/00_AI_CONTEXT.md | AI memory anchor | 10 min |
| docs/01_PROJECT_META.md | Setup & overview | 15 min |
| docs/02_ARCHITECTURE_STANDARDS.md | Rules & standards | 15 min |
| docs/03_DATABASE_CORE.md | Database design | 20 min |
| docs/04_API_AUTH_AND_UI_CONFIG.md | API contracts | 25 min |
| docs/openapi.json | API specification | Reference |

---

## 🎯 Key Principles

1. **Thin Nest, Thick PostgreSQL** — ALL business logic in PostgreSQL
2. **Never hard delete** — Always use soft deletes (`deleted_at = NOW()`)
3. **Always validate DTOs** — Use class-validator decorators
4. **Always check permissions** — Use @Permissions() decorator
5. **Always use parameterized queries** — Prevent SQL injection
6. **Always include audit trail** — Triggers capture changes
7. **Always use response envelope** — Standardized format
8. **Always test migrations** — Run before committing

---

## 🔄 Request Lifecycle Summary

```
1. Client sends request with crm_session cookie
2. SessionGuard validates cookie
3. Controller validates DTO
4. Controller checks @Permissions()
5. Service calls DatabaseService.callDispatcher()
6. DatabaseService checks ALLOWED_FUNCTIONS whitelist
7. PostgreSQL dispatcher executes business logic
8. ResponseInterceptor wraps response in envelope
9. Client receives standardized response
```

---

## 📊 Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Runtime | Node.js | 20.20.1 |
| Framework | NestJS | 10.4.5 |
| Language | TypeScript | 5.5.3 |
| Database | PostgreSQL | 17 |
| Auth | Cookie Sessions | HttpOnly |
| Validation | class-validator | 0.14.1 |
| API Docs | Swagger/OpenAPI | 3.0 |
| Testing | Jest | 29.7.0 |

---

## ✅ Production Readiness

- ✅ RBAC with role hierarchy
- ✅ Session security (HttpOnly, SameSite)
- ✅ Rate limiting
- ✅ SQL injection prevention
- ✅ CORS enforcement
- ✅ Helmet.js headers
- ✅ Soft deletes
- ✅ Full audit trail
- ✅ File upload security
- ✅ Error standardization
- ✅ Swagger/OpenAPI docs
- ✅ Test coverage
- ✅ Migration versioning
- ✅ Cron scheduling
- ✅ Email notifications
- ✅ Full-text search
- ✅ Guest auth portal

---

## 🎓 Where to Start

**New Developer?**
1. Read ANALYSIS_SUMMARY.md (15 min)
2. Read EXECUTIVE_SUMMARY.md (20 min)
3. Read TECHNICAL_ARCHITECTURE.md (40 min)
4. Pick a module and explore

**Adding a Feature?**
1. Read TECHNICAL_ARCHITECTURE.md (40 min)
2. Review docs/02_ARCHITECTURE_STANDARDS.md (15 min)
3. Find similar module and follow pattern
4. Create migration → DTO → Service → Controller

**Debugging?**
1. Check docs/07_OPERATIONS_LOG.md for recent changes
2. Review audit_logs table for change history
3. Check PostgreSQL dispatcher function
4. Verify RBAC permissions

---

**Quick Reference Complete** — Use this as your daily reference guide.
