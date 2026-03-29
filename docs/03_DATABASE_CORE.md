# 03_DATABASE_CORE.md
# CRM Platform — Database Architecture & Security

## 1. DATABASE SCHEMA (PostgreSQL 17, Schema: `crm`)

### Enums & Types
```sql
-- Lead lifecycle
CREATE TYPE lead_status     AS ENUM ('new','contacted','qualified','proposal_sent','negotiation','negotiating','proposal','converted','lost','on_hold');
CREATE TYPE lead_source     AS ENUM ('website','referral','social_media','cold_call','email_campaign','event','partner','other');
-- Opportunity (Deal Pipeline)
CREATE TYPE opportunity_stage AS ENUM ('prospecting','proposal','negotiation','won','lost');
-- Project
CREATE TYPE project_status  AS ENUM ('planning','active','on_hold','completed','cancelled','archived');
-- Tasks
CREATE TYPE task_status     AS ENUM ('todo','in_progress','under_review','review','completed','cancelled','blocked');
CREATE TYPE task_priority   AS ENUM ('low','medium','high','critical');
-- Communication & Activity
CREATE TYPE communication_type AS ENUM ('call','email','meeting','whatsapp','slack','other');
CREATE TYPE activity_type   AS ENUM ('call','meeting','email','task','note','system_event');
-- Documents
CREATE TYPE document_status AS ENUM ('draft','pending_approval','approved','rejected','archived');
-- Finance
CREATE TYPE quotation_status AS ENUM ('draft','sent','accepted','rejected','expired');
CREATE TYPE expense_category AS ENUM ('travel','materials','labor','software','marketing','other');
-- Assignment
CREATE TYPE assignment_rule_type AS ENUM ('round_robin','pool','manual');
-- HR
CREATE TYPE worker_status   AS ENUM ('active','inactive','on_leave');
```

### Core Table Groups

#### Group 1: RBAC & Users
| Table | Purpose |
|-------|---------|
| `roles` | Role definitions (admin, manager, team, external) |
| `permissions` | Module:action slugs |
| `role_permissions` | M:N mapping |
| `users` | System users |
| `sessions` | HttpOnly session tokens |
| `password_reset_tokens` | Time-limited reset links |

#### Group 2: CRM Pipeline (Sales)
| Table | Purpose |
|-------|---------|
| `leads` | Lead intake with full conversion traceability |
| `lead_status_history` | Chronological status changes |
| `opportunities` | Deal pipeline (Prospecting → Won/Lost) |
| `accounts` | Company/individual accounts |
| `contacts` | Contact persons with category (Architect, PMC, Vendor, Client) |
| `contact_addresses` | Normalized multi-address per contact |
| `quotations` | Sales estimates with line items |
| `quotation_items` | Individual line items |

#### Group 3: Project Execution
| Table | Purpose |
|-------|---------|
| `projects` | Project records linked to Opportunity+Account+Contact |
| `project_members` | Team assignment to projects |
| `project_phases` | Work phases (Planning, Design, Execution…) |
| `project_milestones` | Key deliverable markers |
| `project_templates` | Reusable project blueprints |
| `project_stakeholders` | External stakeholders (Architect, PMC, Vendor) |

#### Group 4: Tasks
| Table | Purpose |
|-------|---------|
| `tasks` | Task hierarchy (subtasks via `parent_task_id`) |
| `task_comments` | Discussion threads per task |
| `task_time_logs` | Time tracking entries |
| `task_dependencies` | Blocks/depends-on relationships |
| `task_watchers` | Subscribed watchers |

#### Group 5: Activity, Notes & Engagement
| Table | Purpose |
|-------|---------|
| `activities` | Unified timeline feed for ANY entity |
| `notes` | Pinnable notes on ANY entity |
| `communications` | Legacy/backward-compat call/email logs |

#### Group 6: Assignment System
| Table | Purpose |
|-------|---------|
| `assignment_history` | Full reassignment audit trail for ANY entity |
| `assignment_pools` | Round-robin / pool-pick / manual pool config |
| `pool_members` | Users in each assignment pool |

#### Group 7: SLA & Escalations
| Table | Purpose |
|-------|---------|
| `sla_policies` | Configurable SLA rules per entity type |
| `escalation_logs` | Breach events with status (open/acknowledged/resolved) |

#### Group 8: Documents & Files
| Table | Purpose |
|-------|---------|
| `documents` | Document metadata with versioning |
| `document_versions` | Full version history |
| `document_shares` | Secure time-limited share tokens |

#### Group 9: Automation & Notifications
| Table | Purpose |
|-------|---------|
| `workflow_rules` | Event-triggered configurable rules |
| `workflow_executions` | Execution history |
| `notifications` | In-app notification queue |

#### Group 10: Configuration (Runtime)
| Table | Purpose |
|-------|---------|
| `lookup_sets` | Dropdown master categories |
| `lookup_values` | Dropdown options with labels/colors |
| `custom_field_definitions` | Per-entity custom field schema |
| `custom_field_values` | Custom field values per record |
| `ui_entity_configs` | Entity-level UI configuration |
| `ui_field_configs` | Field-level UI configuration (list/create/update visibility) |
| `api_endpoint_registry` | Self-documenting API registry |
| `report_definitions` | Report templates and queries |
| `saved_filters` | User-saved search/filter presets |
| `record_tags` | Tagging on any entity |

#### Group 11: Audit & Finance
| Table | Purpose |
|-------|---------|
| `audit_logs` | Change history with old/new JSONB values |
| `ai_operation_logs` | AI agent session tracking |
| `expenses` | Project expense entries |

### Sequences & Auto-Numbering
```
LEAD-YYYY-0001    → lead_number_seq
OPP-YYYY-0001     → opportunity_number_seq  (NEW)
PROJ-YYYY-0001    → project_number_seq
TASK-YYYY-0001    → task_number_seq
QUOT-YYYY-0001    → quotation_number_seq
```

### Lead Conversion Traceability (NEW COLUMNS)
```sql
-- leads table (V078 additions)
converted_account_id     UUID  -- account created/linked during conversion
converted_contact_id     UUID  -- contact created/linked during conversion
converted_opportunity_id UUID  -- opportunity created at conversion
-- Note: converted_project_id removed; projects link via opportunity_id

-- projects table (V078 addition)
opportunity_id UUID  -- the opportunity that triggered project creation
```

---

## 2. THE DISPATCHER PATTERN (Thin Nest, Thick SQL)

### NestJS Bridge
```typescript
async callDispatcher(fnName: string, payload: object) {
    if (!ALLOWED_FUNCTIONS.has(fnName)) throw new BadRequestException('Unauthorized dispatcher');
    const result = await this.pool.query(`SELECT ${fnName}($1::jsonb) AS res`, [JSON.stringify(payload)]);
    return result.rows[0].res;
}
```

### ALLOWED_FUNCTIONS Whitelist (must stay up to date)
```
fn_auth_operations, fn_lead_operations, fn_opportunity_operations, fn_contact_operations,
fn_project_operations, fn_task_operations, fn_document_operations, fn_communication_operations,
fn_quotation_operations, fn_expense_operations, fn_workflow_operations, fn_notification_operations,
fn_report_operations, fn_dashboard_operations, fn_search_operations, fn_audit_operations,
fn_rbac_operations, fn_data_operations, fn_action_operations, fn_metadata_operations,
fn_contract_operations, fn_notes_operations, fn_activity_operations,
fn_assignment_operations, fn_sla_operations
```

### Dispatcher Payload Structure
```json
{
  "operation":   "list_leads",
  "data":        { "q": "villa", "status": "qualified", "limit": 20, "offset": 0 },
  "requestedBy": "user-uuid",
  "role":        "admin",
  "permissions": ["leads:manage", "projects:manage"]
}
```

### Standard Response Envelope
```json
{
  "rid":        "s-leads-listed",
  "statusCode": 200,
  "data":       [ ... ],
  "message":    "Operation successful",
  "meta":       { "timestamp": "2026-03-29T..." }
}
```

---

## 3. ACID TRANSACTIONS & DATA INTEGRITY

1. **ACID**: Every PL/pgSQL function runs in a single transaction. Multi-step operations (convert lead, close_won) auto-rollback on failure.
2. **Soft Deletes**: `deleted_at = NOW()`. All queries filter `WHERE deleted_at IS NULL`.
3. **Partial Unique Indexes**: `WHERE deleted_at IS NULL` on all unique constraints.
4. **Row-Level Locking**: `SELECT ... FOR UPDATE` on critical mutations.
5. **Automatic Audit**: All mutation tables have `trg_audit_*` trigger → `fn_audit_operation`.
6. **Assignment History Trigger**: `assigned_to` column changes auto-write to `assignment_history` via function calls inside the dispatcher.

---

## 4. SQL INJECTION PREVENTION (MANDATORY)

1. **No Concat**: `format('SELECT * FROM %I WHERE id = %L', table_name, id)`
2. **Like Safety**: `fn_escape_like()` + `ESCAPE '\\'`
3. **Whitelisting**: Sort columns whitelisted in `TEXT[]` before `ORDER BY`
4. **Strict Casting**: `(data->>'id')::UUID`, `(data->>'amount')::NUMERIC`
5. **Security Definer**: Always `SET search_path = crm, public`
6. **JSONB Null-Safety**: Always `COALESCE` when extracting JSONB fields

---

## 5. MIGRATION & DEPLOYMENT

- **Location**: `database/migrations/V000__...sql` through `V085__...sql`
- **Tracker**: `tools/migrate.js` with `crm.schema_migrations` table
- **Audit**: Core tables have `trg_audit_operation` trigger active
- **Next Migration**: `V086`

### Key Migration Reference
| Range | What |
|-------|------|
| V000–V031 | Core schema tables |
| V032–V036 | Sequences, triggers, helpers |
| V037–V056 | All dispatcher functions |
| V057–V069 | Fixes, expansions, pagination |
| V070–V077 | Enterprise foundation (accounts, runtime, seed) |
| V078 | NEW: Opportunities, Activities, Notes, SLA, Assignment tables |
| V079 | NEW: fn_lead_operations refactor (pool assignment, Opportunity conversion) |
| V080 | NEW: fn_opportunity_operations (deal lifecycle, close_won → Project) |
| V081 | NEW: fn_notes_operations |
| V082 | NEW: fn_activity_operations |
| V083 | NEW: fn_assignment_operations (pools, round-robin, history) |
| V084 | NEW: fn_sla_operations (policies, breach detection, escalations) |
| V085 | NEW: Seed for new modules (permissions, lookups, UI configs, API registry) |

---

## 6. OPPORTUNITY → PROJECT FLOW (Key Business Logic)

```sql
-- In fn_opportunity_operations, operation = 'close_won':
-- 1. Update opportunity stage = 'won', won_at = NOW(), probability = 100
-- 2. INSERT INTO projects (linked: opportunity_id, account_id, contact_id, lead_id)
-- 3. Clone project_phases from template if templateId provided
-- 4. INSERT INTO project_stakeholders (primary_contact)
-- 5. INSERT INTO activities (system_event) on both opportunity and project
-- 6. UPDATE leads.last_activity_at
-- 7. Run fn_trigger_workflow('lead_converted', lead_id)
```
