# Frontend (FE) Integration Guide — CRM Platform

## 1. STRATEGIC CONTEXT

This guide is for the Frontend team and their AI assistant to build a production CRM frontend that integrates with this backend.

### Key Architecture Facts
- **Auth**: Cookie-based sessions (`crm_session`, HttpOnly). **No JWT. No Bearer tokens.**
- **Credential Requirement**: EVERY HTTP request from the FE MUST include `withCredentials: true`.
- **Business Flow**: `Lead → Opportunity → Project → Tasks` (not Lead → Project directly).
- **Breaking Change**: `POST /leads/:id/convert` now returns `{ opportunityId, accountId, contactId }` — NOT a `projectId`.

---

## 2. INTEGRATION ASSETS

### A. Machine-Readable API Contract
**→ Share [`docs/frontend-api-contract.json`](./frontend-api-contract.json) with the FE AI assistant.**

This single JSON file contains:
- All entity schemas with field-level metadata (label, type, required, filterable, etc.)
- All dropdown/lookup values with colors for UI rendering
- Complete API endpoint registry with request/response samples
- Navigation menus and module structure
- Permission slugs for RBAC-driven UI
- Report definitions

### B. Response Envelope (Every API Response)
```json
{
  "rid":        "s-opportunity-won",
  "statusCode": 200,
  "data":       { "projectId": "uuid-..." },
  "message":    "Opportunity closed as Won. Project created.",
  "meta":       { "timestamp": "2026-03-29T..." }
}
```

### C. Live Swagger Docs
- **URL**: `http://localhost:3000/api/docs`
- **Portable JSON**: `docs/openapi.json` (importable into Postman/Insomnia)

---

## 3. FRONTEND IMPLEMENTATION GUIDE

### Cookie Interceptor (Angular)
```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authReq = req.clone({ withCredentials: true });
  return next(authReq);
};
```

### React / Next.js Equivalent
```typescript
// Use in every fetch call
fetch('/api/leads', {
  credentials: 'include',  // Critical: sends the crm_session cookie
  headers: { 'Content-Type': 'application/json' }
});
```

### RBAC-Driven UI Rendering
1. On login, call `GET /auth/profile`.
2. Response includes `permissions: ['leads:manage', 'projects:manage', 'opportunities:manage', ...]`.
3. Use this array to show/hide sidebar items, action buttons, form fields.
4. Example: Only render "Create Opportunity" button if `permissions.includes('opportunities:manage')`.

---

## 4. KEY UI FLOWS

### 4.1 Lead → Opportunity Conversion Flow
```
1. User opens Lead detail page
2. User clicks "Convert Lead" button
3. FE POSTs to: POST /leads/:id/convert
   Body: { accountName, contactEmail, opportunityTitle, amount, expectedCloseDate }
4. Backend returns: { opportunityId, accountId, contactId }
5. FE redirects to: /opportunities/:opportunityId
```

### 4.2 Opportunity → Project Flow
```
1. User opens Opportunity detail page
2. User clicks "Mark as Won" button
3. FE POSTs to: POST /opportunities/:id/win
   Body: { projectTitle, projectDescription, templateId, projectManagerId }
4. Backend returns: { projectId }
5. FE redirects to: /projects/:projectId
```

### 4.3 Activity Timeline (Universal)
```
The same component can render the timeline for ANY entity:
GET /activities?entityType=lead&entityId=<uuid>
GET /activities?entityType=opportunity&entityId=<uuid>
GET /activities?entityType=project&entityId=<uuid>

Each activity has: { type: 'call'|'meeting'|'email'|'note'|'system_event', title, description, performedByName, activityDate }
```

### 4.4 Notes Panel (Universal)
```
Same pattern as activities — works for any entity:
GET  /notes?entityType=project&entityId=<uuid>
POST /notes  → { entityType, entityId, content, isPinned }
POST /notes/:id/pin  → toggle pin
```

### 4.5 Assignment Pool Picker
```
1. Admin creates pool: POST /assignments/pools → { name, entityType: 'lead', ruleType: 'round_robin' }
2. Admin adds members: POST /assignments/pools/members/add → { poolId, userId }
3. Pool auto-assigns leads on creation (no FE action needed)
4. Agents can see unassigned leads: GET /assignments/unassigned
5. Agent can claim: POST /leads/:id/claim
```

---

## 5. ENTITY DETAIL PAGE STRUCTURE

Every detail page (Lead, Opportunity, Project, Task) should have these standard tabs:

| Tab | Data Source | Description |
|-----|-------------|-------------|
| **Overview** | Entity GET endpoint | Core fields, status, key dates |
| **Activities** | `GET /activities?entityType=X&entityId=Y` | Timeline of calls, meetings, emails, events |
| **Notes** | `GET /notes?entityType=X&entityId=Y` | Pinnable note panel |
| **Documents** | `GET /documents?entityType=X&entityId=Y` | File attachments |
| **Assignment History** | `GET /assignments/history?entityType=X&entityId=Y` | Who was it assigned to and when |
| **Related** | Entity-specific (e.g., Opportunity → Projects, Lead → Opportunity) | Cross-entity links |

---

## 6. DROPDOWN / LOOKUP SYSTEM

All dropdowns are driven by `lookups` in `frontend-api-contract.json`. Do NOT hardcode values.

```typescript
// Example: render Stage dropdown for Opportunity
const opportunityStages = contract.lookups.opportunity_stage;
// Returns: [{ key: 'prospecting', label: 'Prospecting', color: '#2563eb' }, ...]

// Use the color for Kanban column headers, status badges, etc.
```

**New Lookups Added:**
- `opportunity_stage`: `prospecting`, `proposal`, `negotiation`, `won`, `lost`
- `activity_type`: `call`, `meeting`, `email`, `task`, `note`, `system_event`
- `assignment_rule`: `round_robin`, `pool`, `manual`

---

## 7. COMPLETE SIDEBAR NAVIGATION STRUCTURE

```json
[
  { "label": "Dashboard",      "route": "/dashboard",       "permission": "dashboard:view",      "icon": "dashboard" },
  { "label": "Leads",          "route": "/leads",            "permission": "leads:manage",         "icon": "funnel" },
  { "label": "Opportunities",  "route": "/opportunities",    "permission": "opportunities:manage", "icon": "briefcase" },
  { "label": "Projects",       "route": "/projects",         "permission": "projects:manage",      "icon": "folder" },
  { "label": "Tasks",          "route": "/tasks",            "permission": "tasks:manage",         "icon": "check-square" },
  { "label": "Contacts",       "route": "/contacts",         "permission": "contacts:manage",      "icon": "users" },
  { "label": "Accounts",       "route": "/accounts",         "permission": "contacts:manage",      "icon": "building" },
  { "label": "Activities",     "route": "/activities",       "permission": "activities:manage",    "icon": "activity" },
  { "label": "Documents",      "route": "/documents",        "permission": "documents:manage",     "icon": "file" },
  { "label": "Communications", "route": "/communications",   "permission": "communications:manage","icon": "message" },
  { "label": "Quotations",     "route": "/quotations",       "permission": "quotations:manage",    "icon": "receipt" },
  { "label": "Expenses",       "route": "/expenses",         "permission": "expenses:manage",      "icon": "dollar" },
  { "label": "Reports",        "route": "/reports",          "permission": "reports:view",         "icon": "bar-chart" },
  { "label": "Settings",       "route": "/settings",         "permission": "settings:manage",      "icon": "settings",
    "children": [
      { "label": "Users & Roles",     "route": "/settings/rbac" },
      { "label": "Assignment Pools",  "route": "/settings/assignments" },
      { "label": "SLA Policies",      "route": "/settings/slas" },
      { "label": "Workflows",         "route": "/settings/workflows" },
      { "label": "Lookup Values",     "route": "/settings/lookups" }
    ]
  }
]
```

---

## 8. AI PROMPT TEMPLATE FOR FE TEAM

Copy-paste this to your AI assistant when starting the frontend project:

```
We are building a CRM frontend. The backend is NestJS with PostgreSQL and cookie-based sessions (HttpOnly).

CRITICAL RULES:
1. All HTTP requests MUST include: withCredentials: true
2. Auth is sessionCookie (crm_session), NOT JWT
3. Business Flow: Lead → Opportunity → Project (NOT Lead → Project directly)
4. Every API response is: { rid, statusCode, data, message, meta }

API Base URL: http://localhost:3000/api

I'm attaching frontend-api-contract.json which contains:
- All entities with field schemas (labels, types, validations, lookup keys)
- All dropdown values with colors (use for badges, Kanban columns, status chips)
- Complete endpoint registry with request/response samples
- Navigation structure with permission guards
- Report definitions

Please build the following modules first in this order:
1. Auth Service (login/logout/profile + RBAC permissions guard)
2. Lead List & Detail pages (with Activity timeline + Notes panel)
3. Opportunity Pipeline (Kanban by stage with drag-to-update-stage)
4. Project Detail (tabs: Overview, Tasks, Documents, Activities, Notes)
5. Settings → Assignment Pools
6. Settings → SLA Policies
```

---

## 9. API ENDPOINT QUICK REFERENCE

| Module | Create | List | Detail | Action |
|--------|--------|------|--------|--------|
| Auth | `POST /auth/login` | — | `GET /auth/profile` | `POST /auth/logout` |
| Leads | `POST /leads` | `GET /leads` | `GET /leads/:id` | `POST /leads/:id/convert` |
| Opportunities | `POST /opportunities` | `GET /opportunities` | `POST /opportunities/get` | `POST /opportunities/:id/win` |
| Projects | `POST /projects` | `GET /projects` | `GET /projects/:id` | `POST /projects/:id/status` |
| Tasks | `POST /tasks` | `GET /tasks` | `GET /tasks/:id` | `PATCH /tasks/:id/status` |
| Activities | `POST /activities` | `GET /activities` | — | `POST /activities/log-call` |
| Notes | `POST /notes` | `GET /notes` | `GET /notes/:id` | `POST /notes/:id/pin` |
| Assignments | `POST /assignments/pools` | `GET /assignments/pools` | — | `POST /assignments/pools/members/add` |
| SLAs | `POST /slas/policies` | `GET /slas/policies` | — | `POST /slas/check-breaches` |
| Documents | `POST /documents/upload` | `GET /documents` | `GET /documents/:id` | `POST /documents/:id/approve` |
| Reports | — | `GET /reports` | `GET /reports/:key` | `GET /reports/:key/csv` |
| RBAC | `POST /rbac/roles` | `GET /rbac/roles` | `GET /rbac/roles/:id` | `POST /rbac/roles/:id/permissions` |
