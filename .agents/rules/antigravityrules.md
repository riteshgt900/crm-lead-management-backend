# Antigravity Rules — CRM Lead Management Backend

These rules are project-specific and MUST be followed by the Antigravity agent at all times.

## 1. Architectural Guardrails
- **"Thin Nest, Thick PostgreSQL"**: Never implement business logic in NestJS. All logic must be in PL/pgSQL functions.
- **Schema Law**: All database objects (tables, types, sequences) and dispatcher functions MUST use the `crm` schema. Always `SET search_path = crm, public`.
- **Service Responsibility**: NestJS services MUST only use `this.db.callDispatcher(fn, payload)`.
- **Database Security**: Never use string concatenation for SQL. Always use `format()` with `%I` and `%L` tokens.
- **Cookie Auth**: Use only cookie-based sessions (`crm_session`). Do not use JWT or Bearer tokens.

## 2. Documentation & Sync Protocols
- **9-File Standard**: Always reference and maintain the 9-file documentation structure in `docs/`.
- **Operation Logging**: Every session must begin and end by updating `docs/07_OPERATIONS_LOG.md`.
- **AI Observability**: Proactively use the `fn_log_ai_operation` function to log significant feature implementations.

## 3. Tool Usage & Commands
- **Windows Preference**: Always use PowerShell-compatible commands for file operations and system tasks.
- **Root Context**: Work from the project root `c:\Projects\crm-lead-management-backend`.
- **Pre-execution Check**: Always run `npm install` and check the database connection before implementing a new module.

---

> [!CAUTION]
> **Deviance Detection**: If you are asked to implement logic in a NestJS service, you MUST remind the user of the "Thick PostgreSQL" architectural law and propose a dispatcher-based solution instead.
