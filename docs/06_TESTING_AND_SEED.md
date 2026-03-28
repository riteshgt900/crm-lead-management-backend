# 06_TESTING_AND_SEED.md
# CRM for Lead Management — Quality Assurance & Seed Data

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

### NestJS (Jest)
- **Unit**: Mock `DatabaseService`, test Service logic and DTO mapping.
- **E2E**: Full HTTP lifecycle using `Supertest`. All E2E tests MUST run against a clean database or use a cleanup script to ensure a fresh state for every run.
- **Mocking Policy**: Unit tests for controllers/services must mock the `DatabaseService`. However, the mock must still simulate the `ALLOWED_FUNCTIONS` whitelist behavior.

### AI Session Verification
1. Login -> Verify Cookie.
2. Protected Route -> Verify 401.
3. Mutation -> Verify `audit_logs` entry.
4. Delete -> Verify `deleted_at` (soft delete).

---

## 2. SEED DATA (CORE)
These records are **mandatory** for the system to function. All seed scripts MUST use `ON CONFLICT DO NOTHING` or `UPDATE` logic to remain idempotent.

- **Permissions**: `dashboard`, `leads`, `projects`, `kanban`, `tasks`, `contacts`, `documents`, `quotations`, `expenses`, `reports`, `settings`.
- **Roles**: Super Admin (p11), Admin (p10), PM (p10), Team (p7), External (p3).
- **Default Admin**: `admin@crm.local` / `Admin@123`.

---

## 3. SEED DATA (DEVELOPMENT)
Sample records for volume and UI testing:
- **Contacts**: Architects, Pmcs, Vendors.
- **Leads**: 3BHK Interior, Office Fit-out.
- **Project Template**: "Standard Interior Design" (4 Phases, 14 Tasks).
- **Workflows**: Converted lead -> Auto-project.
