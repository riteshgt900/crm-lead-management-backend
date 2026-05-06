# Frontend API to Feature Mapping Guide

This document is a comprehensive guide for frontend developers, mapping every major business feature in the application to its complete end-to-end REST API lifecycle (CRUD operations).

> **Crucial Tip:** For exact data shapes, required payloads, HTTP parameters, and response models, refer to `docs/openapi.json` or view the interactive Swagger UI at `http://localhost:3000/api/docs`. For static dropdown menus and UI configs, refer to `docs/frontend-api-contract.json`.

---

## 1. Authentication & Session
**Feature:** Logging in internal staff, managing their profile, and handling their session.

*   **Check Active Session:** `GET /api/auth/session`
*   **Login Staff:** `POST /api/auth/login` (Sets HTTP-Only cookie `crm_session`)
*   **Logout Staff:** `POST /api/auth/logout`
*   **Get Profile (Me):** `GET /api/auth/profile`
*   **Update Password:** `POST /api/auth/change-password`
*   **Forgot Password:** `POST /api/auth/forgot-password`
*   **Reset Password:** `POST /api/auth/reset-password`

---

## 2. Admin: Users, Roles & Access
**Feature:** Managing internal team access, provisioning accounts, and RBAC policy.

### Users
*   **List all Users:** `GET /api/users`
*   **Get User Details:** `GET /api/users/{id}`
*   **Create / Invite User:** `POST /api/users/invite`
*   **Update User Details & Roles:** `PATCH /api/users/{id}`
*   **Delete / Deactivate User:** `DELETE /api/users/{id}`

### Roles & Permissions (RBAC)
*   **List Roles:** `GET /api/rbac/roles`
*   **Get Role Details:** `GET /api/rbac/roles/{id}`
*   **Create Role:** `POST /api/rbac/roles`
*   **Update Role (Name/Config):** `PATCH /api/rbac/roles/{id}`
*   **Delete Role:** `DELETE /api/rbac/roles/{id}`
*   **List System Permissions:** `GET /api/rbac/permissions`
*   **Assign Permissions to Role:** `POST /api/rbac/roles/{id}/permissions`

---

## 3. CRM: Leads & Deal Pipeline
**Feature:** Tracking prospects and converting them to opportunities and accounts.

### Leads
*   **List / Filter Leads:** `GET /api/leads`
*   **Get Lead Details:** `GET /api/leads/{id}`
*   **Create Lead Intake:** `POST /api/leads`
*   **Update Lead Info & Status:** `PATCH /api/leads/{id}`
*   **Delete Lead:** `DELETE /api/leads/{id}`
*   **Convert Lead to Deal:** `POST /api/leads/{id}/convert` (Auto-creates Contacts/Opportunities)

### Opportunities (Deals / Pipeline)
*   **List Deals (Kanban):** `GET /api/opportunities`
*   **Get Deal Details:** `POST /api/opportunities/get` (Uses POST to fetch single item)
*   **Create Manual Opportunity:** `POST /api/opportunities`
*   **Update Opportunity Details:** `PATCH /api/opportunities/{id}`
*   **Delete Opportunity:** `DELETE /api/opportunities/{id}`
*   **Change Kanban Stage:** `POST /api/opportunities/{id}/stage`
*   **Mark as Won:** `POST /api/opportunities/{id}/win` (Triggers Project Creation if configured)
*   **Mark as Lost:** `POST /api/opportunities/{id}/lose`
*   **Assign Deal to User/Team:** `POST /api/opportunities/{id}/assign`

### Stakeholders (Accounts & Contacts)
*   **List Accounts (Companies):** `GET /api/accounts`
*   **Get Account Details:** `GET /api/accounts/{id}`
*   **Create Account:** `POST /api/accounts`
*   **Update Account:** `PATCH /api/accounts/{id}`
*   **Delete Account:** `DELETE /api/accounts/{id}`
*   **List Contacts (People):** `GET /api/contacts`
*   **Get Contact Details:** `GET /api/contacts/{id}`
*   **Create Contact:** `POST /api/contacts`
*   **Update Contact:** `PATCH /api/contacts/{id}`
*   **Delete Contact:** `DELETE /api/contacts/{id}`

---

## 4. Project & Task Execution
**Feature:** Tracking delivery, kanban execution boards, and task resolution.

### Projects
*   **List Active Projects:** `GET /api/projects`
*   **Get Project Details & Milestones:** `GET /api/projects/{id}`
*   **Get Project Tasks:** `GET /api/projects/{id}/tasks`
*   **Get Project Activity Feed:** `GET /api/projects/{id}/activity`
*   **Create Project:** `POST /api/projects`
*   **Update Project Details:** `PATCH /api/projects/{id}`
*   **Delete Project:** `DELETE /api/projects/{id}`
*   **List Project Templates:** `GET /api/projects/templates`

### Tasks
*   **List Tasks (Filter by Project):** `GET /api/tasks` (Pass `?projectId=xyz`)
*   **Get Task Details:** `GET /api/tasks/{id}`
*   **Create Task / Subtask:** `POST /api/tasks` (Pass `parent_task_id` for subtasks)
*   **Update Task Status / Details:** `PATCH /api/tasks/{id}`
*   **Delete Task:** `DELETE /api/tasks/{id}`

---

## 5. Universal / Shared Components
**Feature:** Polymorphic components attachable to *any* entity. Always pass the relevant `{ "entityType": "lead|project|task", "entityId": "uuid" }` payload.

### Notes
*   **List Notes:** `GET /api/notes`
*   **Get Note Details:** `GET /api/notes/{id}`
*   **Create Note (Rich Text):** `POST /api/notes`
*   **Update Note:** `PATCH /api/notes/{id}`
*   **Delete Note:** `DELETE /api/notes/{id}`

### Documents & Files
*   **List Document Versions:** `GET /api/documents`
*   **Get Document Details:** `GET /api/documents/{id}`
*   **Upload Document (Create):** `POST /api/documents/upload`
*   **Approve/Review Document:** `POST /api/documents/{id}/approve`
*   **Delete Document:** `DELETE /api/documents/{id}`
*   **Get External Share Link:** `GET /api/share/{token}`

### Activities & Timeline
*   **List Timeline/Feed:** `GET /api/activities/timeline` (Chronological feed)
*   **Create Generic Activity:** `POST /api/activities`
*   **Log a Call:** `POST /api/activities/log-call`
*   **Log a Meeting:** `POST /api/activities/log-meeting`
*   **Log an Email:** `POST /api/activities/log-email`

### Communications
*   **List Communication Logs:** `GET /api/communications`
*   **Create Communication Entry:** `POST /api/communications`

### System Audit
*   **View Exact System Audit Logs:** `GET /api/audit`

---

## 6. Automation, SLAs & Workflows
**Feature:** Event-trigger policies, assignment groups, and workflow rules.

### Automation & Workflows
*   **List Workflow Rules:** `GET /api/workflows`
*   **Get Workflow Rule Details:** `GET /api/workflows/{id}`
*   **Create Workflow Rule:** `POST /api/workflows`
*   **Update / Toggle Workflow Rule:** `PATCH /api/workflows/{id}`
*   **Delete Workflow Rule:** `DELETE /api/workflows/{id}`

### SLAs & Operations
*   **List Escalation Logs:** `GET /api/slas/escalations`
*   **Resolve Escalation:** `POST /api/slas/escalations/{id}/resolve`
*   **Trigger SLA Breach Check:** `POST /api/slas/check-breaches`

### Assignments & Pools
*   **List Assignment Pools:** `GET /api/assignments/pools`
*   **Create Pool:** `POST /api/assignments/pools`
*   **Delete Pool:** `DELETE /api/assignments/pools/{id}`
*   **Add Member to Pool:** `POST /api/assignments/pools/members/add`
*   **Remove Member from Pool:** `POST /api/assignments/pools/members/remove`
*   **Get Unassigned Records:** `GET /api/assignments/unassigned`
*   **Get Assignment History:** `GET /api/assignments/history`

### Analytics & Reporting
*   **Fetch Report Data (Dashboards):** `GET /api/reports`
*   **Export Report (CSV/PDF):** `GET /api/reports/export`

---

## 7. 🚨 CLIENT PORTAL (External Mode) 🚨
**Feature:** Strict, totally isolated API suite for external clients (vendors/architects). Never leak internal APIs to this group!

*   **Portal Login:** `POST /api/portal/login` (Sets distinct `crm_portal_session` cookie)
*   **List Assigned Projects:** `GET /api/portal/projects`
*   **View Client Project Details:** `GET /api/portal/projects/{id}`
*   **Submit Client Comment:** `POST /api/portal/comments`
*   **Client Upload Document:** `POST /api/portal/upload`
*   *(Internal)* **Admin Invites Client Accounts:** `POST /api/portal/admin/invite`

---

## 8. Dashboard, Search & Billing (Cross-Functional)

### Dashboard Metrics
*   **Get Dashboard Stats (KPIs/Charts):** `GET /api/dashboard/stats`

### Global Search
*   **Global Entity Search:** `GET /api/search` (Search across leads, contacts, projects globally)

### Quotations & Estimates
*   **List Quotations:** `GET /api/quotations`
*   **Create Quotation (with Line Items):** `POST /api/quotations`

### Expenses
*   **List Project Expenses:** `GET /api/expenses`
*   **Log Expense / Receipt Upload:** `POST /api/expenses`

### Notifications
*   **List My Notifications:** `GET /api/notifications`
*   **Mark Notification as Read:** `PATCH /api/notifications/{id}/read`

---

## 9. Frontend Dropdowns & Lookups Guide
**Rule:** Ensure you never require users to manually type UUIDs. Always implement populated dropdowns.

*   **For Relational Values (Users, Projects, Contacts, Roles):** Hit their standard `GET` List API (e.g., `GET /api/users`). Map the response array mapping `item.id` to the `<option>` value and `item.name` (or `item.title`) to the label.
*   **For Static Value Sets (Statuses, Options, Priorities):** Do NOT make REST calls. Import the `docs/frontend-api-contract.json` spec directly into your TypeScript/JS app bundle, and bind your dropdowns statically using the `"lookups"` dictionary provided there.

---

## 10. Global API Behaviors & Standards
To ensure a consistent frontend integration, keep these global rules in mind:

### A. Pagination & Filtering
Most `GET` list endpoints (e.g., `/api/leads`, `/api/projects`, `/api/tasks`) support standard pagination, sorting, and filtering via query parameters:
*   **Pagination:** `?limit=20&offset=0`
*   **Sorting:** `?sort=created_at&sort_direction=DESC`
*   **Filtering:** `?status=IN_PROGRESS&assigned_to=uuid`

### B. File Uploads
When utilizing file upload endpoints like `POST /api/documents/upload` or `POST /api/portal/upload`:
*   **Do NOT send JSON.** You must use `FormData` and set the request headers to `Content-Type: multipart/form-data` (which Axios/Fetch usually handle automatically when you pass a FormData object).
*   Append the actual file and the polymorphic routing details (`entityType`, `entityId`) directly to the FormData object.

### C. Standard Error Handling
All failed requests (400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found) will return a standardized error envelope. 
Set up your Axios/Fetch interceptor to catch these globally and display them in a Toast/Snackbar notification:

```json
{
  "statusCode": 400,
  "message": "Validation failed: 'email' must be a valid email address.",
  "error": "Bad Request"
}
```