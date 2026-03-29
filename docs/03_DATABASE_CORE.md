# 03_DATABASE_CORE.md
# CRM for Lead Management — Database Architecture & Security

## 1. DATABASE SCHEMA (PostgreSQL 17)

### Enums & Types
```sql
CREATE TYPE lead_status AS ENUM ('new', 'contacted', 'qualified', 'proposal_sent', 'negotiation', 'converted', 'lost', 'on_hold');
CREATE TYPE lead_source AS ENUM ('website', 'referral', 'social_media', 'cold_call', 'email_campaign', 'event', 'partner', 'other');
CREATE TYPE project_status AS ENUM ('planning', 'active', 'on_hold', 'completed', 'cancelled', 'archived');
CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'under_review', 'completed', 'cancelled', 'blocked');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'critical');
-- ... [Full list in migrations/V002__create_enum_types.sql]
```

### Core Tables
1. **RBAC**: `roles`, `permissions`, `role_permissions`
2. **Users**: `users`, `sessions`, `password_reset_tokens` (Note: Unique constraint on `email` MUST explicitly be `WHERE deleted_at IS NULL`)
3. **Sales**: `leads`, `lead_status_history`, `contacts`, `quotations`, `quotation_items`
4. **Execution**: `projects`, `project_members`, `project_phases`, `project_milestones`, `project_templates`
5. **Tasks**: `tasks`, `task_comments`, `task_time_logs`
6. **Files & Logs**: `documents`, `document_shares`, `audit_logs`, `ai_operation_logs` (Columns: `id`, `session_id`, `user_prompt`, `files_modified`, `summary`, `status`, `created_at`)
7. **Automation**: `workflow_rules`, `workflow_executions`, `notifications`

### Sequences & Auto-Numbering
- `lead_number_seq` (LEAD-YYYY-0001)
- `project_number_seq` (PROJ-YYYY-0001)
- `task_number_seq` (TASK-YYYY-0001)
- `quotation_number_seq` (QUOT-YYYY-0001)

---

## 2. THE DISPATCHER PATTERN (Thin Nest, Thick SQL)

### NestJS Bridge
```typescript
async callDispatcher(fnName: string, payload: object) {
    // 1. Whitelist Check
    if (!ALLOWED_FUNCTIONS.has(fnName)) throw new BadRequestException();
    // 2. Parameterized Call
    const result = await this.pool.query(`SELECT ${fnName}($1::jsonb) AS res`, [payload]);
    return result.rows[0].res;
}
```

### SQL Template
```sql
CREATE OR REPLACE FUNCTION crm.fn_lead_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
BEGIN
    CASE p_payload->>'operation'
        WHEN 'create_lead' THEN RETURN crm.fn_create_lead(p_payload->'data');
        -- ...
    END CASE;
END; $$;
```

## 3. ACID TRANSACTIONS & CASCADING SOFT DELETES
3. **ACID Transactions**: Every PL/pgSQL function runs in a transaction. If a multi-step operation (like converting a lead to a project) fails midway, the entire operation is automatically rolled back.
4. **Cascading Soft Deletes**: When a parent record is soft-deleted (e.g., `deleted_at = NOW()` on a `Project`), the dispatcher function MUST manually update and cascade the soft-delete down to all child records (e.g., `Tasks`, `Comments`) to maintain data hygiene.
5. **Partial Unique Indexes**: Any unique constraint (e.g., `email`, `code`) MUST include `WHERE deleted_at IS NULL` to allow re-use of unique values after a soft-delete.
6. **Row-Level Locking**: For critical mutations (e.g., `update_budget`, `change_status`), dispatchers MUST use `SELECT ... FOR UPDATE` to prevent race conditions during concurrent requests.
7. **Orphan Prevention**: Before soft-deleting a core entity (e.g., `User`, `Role`, `Contact`), the dispatcher MUST check for active dependencies. If users are assigned to a role, the role cannot be deleted (Return `e-dependency-exists`).
8. **Automatic Audit**: Every mutation table MUST have the `trg_audit_log` trigger attached, calling `fn_audit_operation`.

---

## 4. SQL INJECTION PREVENTION (MANDATORY)
1. **No Concat**: Use `format('SELECT * FROM %I WHERE id = %L', table, id)`.
2. **Like Safety**: Use `fn_escape_like()` + `ESCAPE '\'`.
3. **Whitelisting**: Hard-whitelist sort columns in an array `TEXT[]` before `ORDER BY`.
4. **Strict Casting**: Always cast JSONB: `(data->>'id')::UUID`, `(data->>'amount')::NUMERIC`.
6. **Security Definer**: Always include `SET search_path = crm, public`.
7. **JSONB Null-Safety**: Always use `COALESCE` or explicit `IS NULL` checks when extracting values from JSONB payloads to prevent runtime SQL errors if a field is missing.

---

## 5. MIGRATION & DEPLOYMENT
- **Location**: `database/migrations/V001__...sql`
- **Migration Tracker**: Uses `tools/migrate.js` with a dedicated `crm.schema_migrations` table to track execution state and prevent non-idempotent script collisions.
- **Audit Activation**: Core mutation tables (`leads`, `projects`, `tasks`) have the `trg_audit_operation` trigger active, feeding the `audit_logs` table for chronological history.
- **Workflow**: `migrate.js` (Tracked) -> `seed.js`.
