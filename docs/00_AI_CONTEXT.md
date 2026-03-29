# 00_AI_CONTEXT.md
# AI MEMORY ANCHOR — CRM + PROJECT MANAGEMENT BACKEND

## 1. STRATEGIC CONTEXT
This is a **production-grade NestJS and PostgreSQL backend** for a complete **CRM + Deal Pipeline + Project Execution Platform**. The project adheres to a strict "Documentation-First" protocol to ensure architectural alignment and prevent context drift.

### Core Architectural Law
> [!IMPORTANT]
> **"Thin Nest, Thick PostgreSQL"**: ALL business logic must reside in PostgreSQL dispatcher functions. NestJS is merely a routing, session validation, and DTO-validation layer.

---

## 2. CURRENT PROJECT STATE
- **Phase**: Full Enterprise Scope + CRM Enhancement — Complete & Verified
- **Business Flow**: `Lead → Opportunity → Project → Task → Execution → Reporting`
- **Core Features**: Auth, Leads, Opportunities (Deal Pipeline), Projects, Tasks, Financials, Search, Dashboard, Reports.
- **Enterprise Features**: Templates, Phases, Milestones, Escalations, CSV Export, Project Feeds.
- **New Modules** (2026-03-29): Opportunities, Activities, Notes, Assignments (Pools), SLAs & Escalations.
- **Active Workspace**: `c:\Projects\crm-lead-management-backend`
- **Environment**: Node.js 20, PostgreSQL 17, Windows.
- **Migrations Applied**: 86 (V000–V085)
- **NestJS Modules**: 27

---

## 3. DOCUMENTATION INDEX (The 11-File Structure)
AI agents MUST read these files in order to understand the project:

1.  **[00_AI_CONTEXT.md](00_AI_CONTEXT.md)**: (This file) High-level memory anchor.
2.  **[01_PROJECT_META.md](01_PROJECT_META.md)**: Overview, Tech Stack, Module Audit.
3.  **[02_ARCHITECTURE_STANDARDS.md](02_ARCHITECTURE_STANDARDS.md)**: Non-negotiable laws and workflows.
4.  **[03_DATABASE_CORE.md](03_DATABASE_CORE.md)**: Schema, Dispatchers, and SQL Injection prevention.
5.  **[04_API_AUTH_AND_UI_CONFIG.md](04_API_AUTH_AND_UI_CONFIG.md)**: Auth Flow and API Contracts.
6.  **[05_WORKFLOW_AUTOMATION.md](05_WORKFLOW_AUTOMATION.md)**: Automation Engine and Rules.
7.  **[06_TESTING_AND_SEED.md](06_TESTING_AND_SEED.md)**: QA Strategy and Mandatory Data.
8.  **[07_OPERATIONS_LOG.md](07_OPERATIONS_LOG.md)**: Project Health and Session History.
9.  **[08_AI_PROMPTS.md](08_AI_PROMPTS.md)**: Instruction sets for bootstrapping and development.
10. **[FE_INTEGRATION_GUIDE.md](FE_INTEGRATION_GUIDE.md)**: Frontend partner integration guide.
11. **[frontend-api-contract.json](frontend-api-contract.json)**: Complete machine-readable API contract for UI generation.

---

## 4. CRITICAL AGENTIC RULES
- **Backtrack Audit**: Every session MUST start by reading the last 3 entries in `07_OPERATIONS_LOG.md`.
- **Atomic Commits**: SQL migration first → DTO next → Service/Controller last.
- **Sync Protocol**: Update `07_OPERATIONS_LOG.md` before closing every session.
- **No Hallucination**: If a requirement is not in the `docs/` folder, ASK the user before implementing.
- **Migration Numbering**: Next available migration is `V086`. Always check the `database/migrations/` directory before creating a new file.
- **New Operations**: When adding a new operation to an existing dispatcher, use `CREATE OR REPLACE FUNCTION` — never create a new file for the same function.

---

## 5. MODULE → DISPATCHER MAP
| Module | NestJS Controller | DB Dispatcher |
|--------|------------------|---------------|
| Leads | `/leads` | `fn_lead_operations` / `fn_data_operations` / `fn_action_operations` |
| Opportunities | `/opportunities` | `fn_opportunity_operations` |
| Projects | `/projects` | `fn_project_operations` / `fn_data_operations` |
| Tasks | `/tasks` | `fn_task_operations` / `fn_data_operations` |
| Contacts | `/contacts` | `fn_contact_operations` / `fn_data_operations` |
| Accounts | `/api/data/account` | `fn_data_operations` |
| Activities | `/activities` | `fn_activity_operations` |
| Notes | `/notes` | `fn_notes_operations` |
| Assignments | `/assignments` | `fn_assignment_operations` |
| SLAs | `/slas` | `fn_sla_operations` |
| Documents | `/documents` | `fn_document_operations` |
| Communications | `/communications` | `fn_communication_operations` |
| Quotations | `/quotations` | `fn_quotation_operations` |
| Expenses | `/expenses` | `fn_expense_operations` |
| Reports | `/reports` | `fn_report_operations` |
| Dashboard | `/dashboard` | `fn_dashboard_operations` |
| Auth | `/auth` | `fn_auth_operations` |
| RBAC | `/rbac` | `fn_rbac_operations` |
