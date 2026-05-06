# CRM Platform — Frontend Project Scope

## 1. System Overview
The backend provides a comprehensive, centralized **CRM + Project Management** API designed for high-end B2B operations. The primary objective is to manage the full customer lifecycle: from initial prospecting, through rigorous deal pipelines, into active project execution, all while maintaining strict auditability, SLA compliance, and communication monitoring.

---

## 2. Core Business Workflows

### 2.1 The Deal Pipeline (CRM Foundation)
The system no longer converts Leads directly to Projects. The strict business flow is:
`Lead → Opportunity (Deal) → Project`

1. **Leads (`/api/leads`)**: Initial prospects. Capture incoming interest, auto-assign via round-robin pools, and track via SLA policies.
2. **Opportunities (`/api/opportunities`)**: Once a lead is qualified, it is converted to an Opportunity. This conversion automatically handles deduplication of Accounts and Contacts. The opportunity progresses through a Kanban-compatible stage pipeline (`prospecting`, `proposal`, `negotiation`).
3. **Projects (`/api/projects`)**: When an Opportunity is marked as "Won", a Project is automatically created (optionally cloning a predefined Template).

### 2.2 Reusable Universal Components
The backend relies heavily on polymorphic data relationships to avoid duplicating UI logic. The frontend should build **one robust universal component** for each of the following:

- **Activities Timeline (`/api/activities`)**: A unified, chronological feed merging calls, meetings, emails, and system events. Pass `entityType` and `entityId` to render history for *any* Lead, Opportunity, or Project.
- **Notes (`/api/notes`)**: Rich-text, pinnable notes attachable to any entity.
- **Documents (`/api/documents`)**: Version-controlled attachment storage, including approval logic.

---

## 3. High-Level Module Scope

### 3.1 Workspace & Analytics
- ✅ **Dashboard**: High-level statistical aggregates (Lead counts by status, Active Projects, Expected Revenue, Pending Tasks).
- ✅ **Reports**: Configurable CSV/JSON exports (e.g., "Pipeline Overview", "SLA Breaches").

### 3.2 CRM & Pipeline
- ✅ **Leads Management**: List, detail view, status changes. Needs integration with the Assignment Pool picker for manual reassignment or self-claiming.
- ✅ **Opportunities Management**: Deal tracking boards (Kanban UI). Track estimated revenue, probability, and expected close dates.
- ✅ **Accounts & Contacts**: Standard B2B address book. Organizations (Accounts) and the people inside them (Contacts). 

### 3.3 Project Execution
- ✅ **Projects & Templates**: Execution tracking. Can load milestones and tasks from predefined templates.
- ✅ **Tasks**: Hierarchical action items associated with projects. Includes dependencies, time tracking, and status boards (To-Do, In Progress, Done).

### 3.4 Workflow & Automation
- ✅ **SLA Policies (`/api/slas`)**: Configurable timers (e.g., "Contact new lead in 4 hours"). The backend runs a cron job to flag breaches. The frontend should highlight breached entities in red.
- ✅ **Assignment Pools (`/api/assignments/pools`)**: Define round-robin teams. Used by the backend to automatically assign new leads to available agents.
- ✅ **Workflow Triggers (`/api/workflows`)**: Custom "If This Then That" rules (e.g., When Lead is converted -> Send Email to Manager).

### 3.5 Financials & Communication
- ✅ **Quotations**: Proposal generation with line items, tax calculations, and status progression (Draft -> Sent -> Accepted -> Rejected).
- ✅ **Expenses**: Cost tracking (reimbursable vs. billable) mapped to projects.
- ✅ **Communications**: Email/Call/Meeting logging separate from the unified Activity timeline (used for dedicated scheduling or logging outbound attempts).

### 3.6 Security & Admin Settings
- ✅ **Role-Based Access Control (RBAC)**: Deep permissions model (`slug: 'leads:manage'`) and `super_admin` hierarchy. Full User CRUD and role assignments. The backend serves the current user's capabilities; the frontend must conditionally render sidebar menus and action buttons based on these slugs.
- ✅ **Lookup Values**: All dropdown mappings (Lead Sources, Project Types, Stages, Priorities, Colors) are dynamic. Use the `lookups` block from `frontend-api-contract.json` to populate `<select>` inputs rather than hardcoding them in React/Angular.

### 3.7 Client Portal (V2 Completed)
- ✅ **Guest Auth**: Secure, isolated login for external clients/vendors without consuming full user licenses.
- ✅ **Project Access**: Read-only tracking of active phases, milestones, and high-level health metrics.
- ✅ **Collaboration**: Client commenting on authorized tasks properties.
- ✅ **Document Sharing**: Secure upload and approval flows for external documentation.

### 3.8 Universal Components
- ✅ **Activities Timeline (`/api/activities`)**: A unified, chronological feed merging calls, meetings, emails, and system events. Pass `entityType` and `entityId` to render history for *any* Lead, Opportunity, or Project.
- ✅ **Notes (`/api/notes`)**: Rich-text, pinnable notes attachable to any entity.
- ✅ **Documents (`/api/documents`)**: Version-controlled attachment storage, including approval logic.

### 3.9 System Activity & Audit
- ✅ **Audit Trail**: Full change history automatically tracked via PostgreSQL triggers.

### 3.10 Integrations (Optional)
- [ ] Email providers (Gmail / Outlook OAuth)
- [ ] Messaging platforms (Slack / WhatsApp)
- [ ] Cloud Storage Swaps (S3/Azure)


---

## 4. Frontend Integration Technical Requirements
1. **Cookie-Based Sessions (`crm_session`)**: 
   - No JWT/Bearer tokens are utilized.
   - You MUST set `withCredentials: true` (or `credentials: 'include'`) on every single Fetch/Axios request to attach the security cookie.
2. **Response Envelope**: Every backend response rigidly follows the format:
   ```json
   {
     "rid": "s-entity-action",
     "statusCode": 200,
     "data": { ... },
     "message": "Action successful",
     "meta": { "timestamp": "..." }
   }
   ```
3. **Pivotal Schema Contract**: The entire application's data models, endpoints, required fields, validations, and dynamic menus are generated programmatically. **Always reference `frontend-api-contract.json` to build the UI elements.**
