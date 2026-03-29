# 06_TESTING_AND_SEED.md
# CRM Platform — Quality Assurance & Seed Data

## 1. TESTING STRATEGY

### SQL Level (pgAdmin)
Validate every dispatcher operation with a `DO` block:
```sql
DO $$ 
DECLARE v_res JSONB;
BEGIN
    SELECT fn_lead_operations('{"operation":"create_lead","data":{"title":"Test"}}') INTO v_res;
    ASSERT (v_res->>'statusCode') = '201';
END $$;
```

### NestJS (Jest/E2E)
- **Status**: 100% Passed (18/18 Tests).
- **Coverage**: Auth, Leads (Lifecycle), Opportunities, Projects/Tasks (Functional), Financials, Search, Dashboard.
- **Protocol**: Standard E2E suite using `createTestApp` and `Supertest`.
- **Note**: Lead-to-Opportunity conversion requires deduplication logic (creates or links Contact/Account based on matching data). Opportunity close_won auto-creates Project.

### AI Session Verification
1. Login -> Verify Cookie.
2. Protected Route -> Verify 401.
3. Mutation -> Verify `audit_logs` entry.
4. Delete -> Verify `deleted_at` (soft delete).

---

## 2. SEED DATA (CORE)
These records are **mandatory** for the system to function. All seed scripts MUST use `ON CONFLICT DO NOTHING` or `UPDATE` logic to remain idempotent.

- **Permissions**: `dashboard`, `leads`, `opportunities`, `projects`, `kanban`, `tasks`, `contacts`, `documents`, `quotations`, `expenses`, `reports`, `settings`, `activities`, `notes`, `assignments`, `slas`.
- **Roles**: Super Admin, Admin, PM, Team, External.
- **Default Admin**: `admin@crm.local` / `Admin@123`.

---

## 3. SEED DATA (DEVELOPMENT)
Sample records for volume and UI testing:
- **Contacts**: Architects, Pmcs, Vendors.
- **Leads**: 3BHK Interior, Office Fit-out.
- **Projects**: Standard templates and milestones.
- **SLA Policies**: High Priority 4hr SLA.
- **Workflow Rules**: Auto pool assignment, Lead Converted -> Opportunity notification.
