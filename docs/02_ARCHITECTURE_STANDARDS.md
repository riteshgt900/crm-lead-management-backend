# 02_ARCHITECTURE_STANDARDS.md
# CRM for Lead Management — Rules & Standards

## 1. ARCHITECTURAL PATTERN (NON-NEGOTIABLE)

### The "Thin Nest, Thick Postgres" Law
1. **ALL business logic** lives in PostgreSQL dispatcher functions.
2. **NestJS Services** are pass-throughs: `return this.db.callDispatcher(fnName, payload);`.
3. **NestJS Controllers** only: Validate DTO, Check Session, Call Service.
4. **Response Envelope**: Always `{ rid, statusCode, data, message, errors, meta }`.
5. **Soft Deletes**: Use `deleted_at = NOW()`. Never `DELETE FROM`.
6. **Auth**: HttpOnly cookie `crm_session`. **NO JWT.**
7. **RBAC Caching**: `fn_auth_operations` must return `permissions[]` for in-memory checks.
8. **NO ORM**: Do NOT use TypeORM, Prisma, or Sequelize. Use the raw `pg` driver only.

### Request Lifecycle
`Client -> SessionGuard (Validate Cookie) -> Controller (DTO Validate) -> Service -> DatabaseService (Whitelist Check) -> PG Dispatcher -> ResponseInterceptor (Wrap)`

---

## 2. AI AGENT SESSION WORKFLOW

### Reading Order (Every Session)
1. `docs/07_OPERATIONS_LOG.md` -> Current State
2. `docs/02_ARCHITECTURE_STANDARDS.md` -> These Rules
3. `docs/03_DATABASE_CORE.md` -> Schema & Safety

### AI Logging Protocol
- **Start Task**: Log intent to `ai_operation_logs` (status: `pending`).
- **End Task**: Update log to `success` or `fail` with error details.
- **Session Sync**: Use `docs/08_AI_PROMPTS.md` to update Logs/Changelog.

### 2.2 Agentic Tool-Usage Checklist
- **Navigation**: Use `ls -R` or `list_dir` to confirm folder existence before writing files.
- **Validation**: Use `run_command` with `npm run start:dev` to check for bootstrap errors.
- **DB Debugging**: Use `read_terminal` after running `node tools/migrate.js` to catch SQL syntax errors.

---

## 3. PROJECT DIRECTORY TREE
```
crm-lead-management/
  docs/               <- Numbered MD files (01-08)
    archive/          <- Historical logs
  database/
    migrations/       <- SQL Versioning (V001...)
    functions/        <- SQL Dispatchers (fn_...)
    schema/           <- schema_full.sql
  src/
    main.ts           <- Bootstrap
    app.module.ts     <- Wiring
    common/           <- Guards, Filters, Interceptors
    modules/          <- Feature modules (leads, projects, etc.)
  tools/              <- migrate.js, dump-schema.js, seed.js
```

---

## 4. NAMING CONVENTIONS

### Database
- **Tables**: plural `snake_case` (`leads`, `audit_logs`)
- **Columns**: `snake_case` (`created_at`, `assigned_to`)
- **Functions**: `fn_` prefix (`fn_lead_operations`)
- **Indexes**: `idx_` prefix / **Sequences**: `_seq` suffix

### NestJS / TypeScript
- **Files**: `kebab-case` (`leads.controller.ts`, `session.guard.ts`)
- **Classes**: `PascalCase` (`LeadsService`)
- **Methods/Variables**: `camelCase` (`getLeads`, `leadId`)
- **DTO Suffix**: `Dto` (`CreateLeadDto`)

---

## 5. SAFETY & SECURITY
- **SQL Injection**: Use `format()` with `%I` (identifier) and `%L` (literal). See `03_DATABASE_CORE.md`.
- **Whitelisting**: `DatabaseService` checks `ALLOWED_FUNCTIONS` set before every call.
- **CORS**: Enforce credentials and origin whitelist in `main.ts`.

## 6. DATA & STORAGE HYGIENE
1. **Storage Abstraction**: The `DocumentService` must use a `StorageProvider` interface. By default, it uses `LocalWindowsProvider`, but it must be ready for `S3Provider` swap. Never use raw `fs` in controllers.
2. **Log Retention**: Audit and AI logs MUST be partitioned or truncated. Every 30 days, the `MASTER_PROMPT` setup should prompt for a manual `VACUUM ANALYZE` or archival move to history tables.
3. **Payload Limits**: NestJS `main.ts` must enforce a **1MB limit** for JSON bodies to prevent OOM attacks. Files are handled separately via Multer.
