# 00_AI_CONTEXT.md
# AI MEMORY ANCHOR — CRM LEAD MANAGEMENT BACKEND

## 1. STRATEGIC CONTEXT
This is a **production-grade NestJS and PostgreSQL backend** optimized for agentic AI development. The project adheres to a strict "Documentation-First" protocol to ensure architectural alignment and prevent context drift.

### Core Architectural Law
> [!IMPORTANT]
> **"Thin Nest, Thick PostgreSQL"**: ALL business logic must reside in PostgreSQL dispatcher functions. NestJS is merely a routing and validation layer.

---

## 2. CURRENT PROJECT STATE
- **Phase**: Documentation Finalized (9-File Structure).
- **Implementation**: Pending (Skeleton generation is the next step).
- **Active Workspace**: `c:\Projects\crm-lead-management-backend`
- **Environment**: Node.js 20, PostgreSQL 17, Windows.

---

## 3. DOCUMENTATION INDEX (The 9-File Structure)
AI agents MUST read these files in order to understand the project:

1.  **[00_AI_CONTEXT.md](00_AI_CONTEXT.md)**: (This file) High-level memory anchor.
2.  **[01_PROJECT_META.md](01_PROJECT_META.md)**: Overview, Tech Stack, and Scope Audit.
3.  **[02_ARCHITECTURE_STANDARDS.md](02_ARCHITECTURE_STANDARDS.md)**: Non-negotiable laws and workflows.
4.  **[03_DATABASE_CORE.md](03_DATABASE_CORE.md)**: Schema, Dispatchers, and SQL Injection prevention.
5.  **[04_API_AUTH_AND_UI_CONFIG.md](04_API_AUTH_AND_UI_CONFIG.md)**: Auth Flow and API Contracts.
6.  **[05_WORKFLOW_AUTOMATION.md](05_WORKFLOW_AUTOMATION.md)**: Automation Engine and Rules.
7.  **[06_TESTING_AND_SEED.md](06_TESTING_AND_SEED.md)**: QA Strategy and Mandatory Data.
8.  **[07_OPERATIONS_LOG.md](07_OPERATIONS_LOG.md)**: Project Health and Session History.
9.  **[08_AI_PROMPTS.md](08_AI_PROMPTS.md)**: Instruction sets for bootstrapping and development.

---

## 4. CRITICAL AGENTIC RULES
- **Backtrack Audit**: Every session MUST start by reading the last 3 entries in `07_OPERATIONS_LOG.md`.
- **Atomic Commits**: SQL first -> DTO next -> Service/Controller last.
- **Sync Protocol**: Update `07_OPERATIONS_LOG.md` before closing every session.
- **No Hallucination**: If a requirement is not in the `docs/` folder, ASK the user before implementing.
