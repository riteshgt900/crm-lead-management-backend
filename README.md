# CRM for Lead Management — Backend API

Production-grade NestJS and PostgreSQL backend for lead management, project coordination, and workflow automation.

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Setup Environment
# Copy .env.example to .env and update DATABASE_URL

# 3. Database Migration & Seed
node tools/migrate.js
node tools/seed.js

# 4. Start Development
npm run start:dev
```

## Documentation (The 9-File Structure)

This project follows an AI-optimized documentation structure located in the `docs/` folder:

1.  **[00_AI_CONTEXT.md](docs/00_AI_CONTEXT.md)**: AI Memory Anchor — High-level context.
2.  **[01_PROJECT_META.md](docs/01_PROJECT_META.md)**: Overview, Tech Stack, and Setup.
3.  **[02_ARCHITECTURE_STANDARDS.md](docs/02_ARCHITECTURE_STANDARDS.md)**: Non-negotiable laws and AI session workflow.
4.  **[03_DATABASE_CORE.md](docs/03_DATABASE_CORE.md)**: Schema, SQL Injection prevention, and Dispatcher pattern.
5.  **[04_API_AUTH_AND_UI_CONFIG.md](docs/04_API_AUTH_AND_UI_CONFIG.md)**: Auth Flow, API Contracts, UI settings logic, and Error Registry.
6.  **[05_WORKFLOW_AUTOMATION.md](docs/05_WORKFLOW_AUTOMATION.md)**: Automation Engine and Default Rules.
7.  **[06_TESTING_AND_SEED.md](docs/06_TESTING_AND_SEED.md)**: QA Strategy and Mandatory Seed Data.
8.  **[07_OPERATIONS_LOG.md](docs/07_OPERATIONS_LOG.md)**: Project State, Phase Log, and Changelog.
9.  **[08_AI_PROMPTS.md](docs/08_AI_PROMPTS.md)**: Master Prompt for skeleton generation and session sync templates.

## Agentic Development Protocol

This project is optimized for **Agentic AI development** (e.g., Gemini Antigravity, Cursor, Windsurf). Every session follows a strict 3-step loop:

1.  **Thinking**: AI Agents must start every turn with an internal `<thought>` block to analyze dependencies and the "Thick SQL" architecture.
2.  **Tooling**: Agents are encouraged to use their tools proactively (`run_command` for migrations, `ls` for discovery, `read_terminal` for debugging).
3.  **Syncing**: Every session MUST synchronize its state by updating `07_OPERATIONS_LOG.md` before closing.

## Tech Stack
- **Runtime**: Node.js 20.20.1 (LTS)
- **Framework**: NestJS 10.4.5
- **Database**: PostgreSQL 17
- **Auth**: Cookie-based Sessions (HttpOnly)
- **Architecture**: 'Thin Nest, Thick PostgreSQL' (Business logic in SQL dispatchers)

## Enterprise Readiness
- **Dynamic RBAC & UI Config**: Features dedicated Super Admin APIs (`/rbac`) to build custom roles and assign permissions on the fly, dynamically driving the frontend UI.
- **AI Observability**: Mandatory operation logging via `ai_operation_logs`.
- **Performance**: In-memory RBAC caching and optimized SQL dispatching.
- **Security & Reliability**: ACID-compliant PL/pgSQL transactions, Throttler rate limiting, strict Joi environment validation, soft delete constraints, and firm DTO bounds.

---

> [!TIP]
> **Cursor/Windsurf users**: Always read `docs/07_OPERATIONS_LOG.md` before starting a development session to synchronize. Older history is automatically moved to `docs/archive/` once the log exceeds 500 lines.
