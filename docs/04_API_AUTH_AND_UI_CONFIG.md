# 04_API_AUTH_AND_UI_CONFIG.md
# CRM Platform — API Contracts, Authentication & UI Config

## 1. AUTHENTICATION (Cookie-Based Sessions)
- **Strategy**: HttpOnly Cookie (`crm_session`). **No JWT. No Bearer tokens.**
- **Security**: `Secure: true` in production, `SameSite: Lax`, `HttpOnly: true`.
- **Frontend Requirement**: Every HTTP request MUST include `withCredentials: true`.
- **Flow**:
  - `POST /auth/login` → Sets `crm_session` cookie.
  - `SessionGuard` validates cookie via `fn_auth_operations('validate_session')`.
  - `req.user` populated with: `{ id, roleId, roleName, permissions[] }`.
- **RBAC**: Use `@Permissions('module:action')` decorator. `PermissionsGuard` checks slugs against `req.user.permissions[]`.

---

## 2. RATE LIMITING
- **Global**: 100 requests/min (ThrottlerModule)
- **Auth Routes** (`/auth/*`): 5 requests/min (brute-force prevention)

---

## 3. COMPLETE API ENDPOINT REGISTRY

### Auth & Sessions
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `POST` | `/auth/login` | Login with email/password, sets cookie | Public |
| `POST` | `/auth/logout` | Destroy session | Session |
| `GET`  | `/auth/profile` | Current user + permissions[] | Session |
| `POST` | `/auth/change-password` | Password change (requires old password) | Session |
| `POST` | `/auth/forgot-password` | Send reset link to email | Public |
| `POST` | `/auth/reset-password` | Reset password with token | Public |

### Users
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/users` | List users | Admin |
| `POST` | `/users/invite` | Invite user | Admin |
| `GET`  | `/users/:id` | Get user profile | Admin/Self |
| `PATCH`| `/users/:id` | Update user | Admin/Self |

### RBAC & Permissions
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/rbac/permissions` | List all permission slugs | Admin |
| `GET`  | `/rbac/roles` | List all roles | Admin |
| `POST` | `/rbac/roles` | Create custom role | Admin |
| `GET`  | `/rbac/roles/:id` | Get role with permissions | Admin |
| `POST` | `/rbac/roles/:id/permissions` | Assign permissions to role | Admin |
| `DELETE`| `/rbac/roles/:id/permissions/:permId` | Remove permission from role | Admin |

### Leads (Updated — Opportunity-First Conversion)
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/leads` | List leads (RBAC-filtered) | Session |
| `POST` | `/leads` | Create lead (auto-assigns from pool if no assignedTo) | Session |
| `GET`  | `/leads/:id` | Lead detail with notes + activities + history | Session |
| `PATCH`| `/leads/:id` | Update lead fields | Session |
| `PATCH`| `/leads/:id/status` | Update status + reason | Session |
| `POST` | `/leads/bulk` | Bulk status/assignment update | Session |
| `POST` | `/leads/:id/convert` | **Convert lead → creates Opportunity** (NOT Project) | Session |
| `POST` | `/leads/:id/assign` | Manually assign lead to user | Manager/Admin |
| `POST` | `/leads/:id/claim` | Self-claim unassigned lead from pool | Session |

> [!IMPORTANT]
> **Breaking Change from v1**: `POST /leads/:id/convert` now returns `{ opportunityId, accountId, contactId }` — NOT a projectId. The Project is auto-created when the Opportunity is marked Won.

### Opportunities (Deal Pipeline) — NEW
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/opportunities` | List opportunities (RBAC-filtered, stage filter) | Session |
| `POST` | `/opportunities/get` | Get opportunity detail with related data | Session |
| `POST` | `/opportunities` | Create standalone opportunity | Session |
| `PATCH`| `/opportunities/:id` | Update opportunity fields | Session |
| `POST` | `/opportunities/:id/stage` | Move to pipeline stage | Session |
| `POST` | `/opportunities/:id/win` | **Mark Won → auto-creates Project** | Session |
| `POST` | `/opportunities/:id/lose` | Mark Lost with reason | Session |
| `POST` | `/opportunities/:id/assign` | Re-assign opportunity to user | Manager/Admin |
| `DELETE`| `/opportunities/:id` | Soft delete opportunity | Admin |

### Contacts
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/contacts` | List contacts with filters | Session |
| `POST` | `/contacts` | Create contact | Session |
| `GET`  | `/contacts/:id` | Contact detail | Session |
| `PATCH`| `/contacts/:id` | Update contact | Session |
| `DELETE`| `/contacts/:id` | Soft delete | Admin |
| `POST` | `/contacts/:id/addresses` | Add address | Session |

### Accounts
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/api/data/account` | List accounts | Session |
| `POST` | `/api/data/account/create` | Create account | Session |
| `POST` | `/api/data/account/update` | Update account | Session |
| `POST` | `/api/data/account/delete` | Soft delete | Admin |

### Projects
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/projects` | List projects | Session |
| `POST` | `/projects` | Create project | Manager/Admin |
| `GET`  | `/projects/:id` | Project detail with phases + milestones | Session |
| `PATCH`| `/projects/:id` | Update project | Manager/Admin |
| `POST` | `/projects/:id/status` | Change project status | Manager/Admin |
| `GET`  | `/projects/:id/tasks` | List project tasks (Kanban view) | Session |
| `GET`  | `/projects/:id/phases` | List phases with milestones | Session |
| `GET`  | `/projects/:id/members` | List project members | Session |
| `POST` | `/projects/:id/members` | Add project member | Manager/Admin |
| `GET`  | `/projects/:id/activity` | Project chronological activity feed | Session |
| `GET`  | `/projects/:id/documents` | Project documents list | Session |
| `GET`  | `/projects/:id/stakeholders` | Project stakeholders | Session |

### Tasks
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/tasks` | List tasks with filters | Session |
| `POST` | `/tasks` | Create task | Session |
| `GET`  | `/tasks/:id` | Task detail + comments + time logs | Session |
| `PATCH`| `/tasks/:id` | Update task | Session |
| `PATCH`| `/tasks/:id/status` | Change task status | Session |
| `POST` | `/tasks/:id/comments` | Add comment | Session |
| `POST` | `/tasks/:id/time-log` | Log time spent | Session |
| `DELETE`| `/tasks/:id` | Soft delete | Admin/PM |

### Activities (Unified Timeline) — NEW
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/activities` | List activities for an entity (`?entityType=lead&entityId=uuid`) | Session |
| `GET`  | `/activities/timeline` | Global timeline for current user | Session |
| `POST` | `/activities/log-call` | Log a call (also writes to communications) | Session |
| `POST` | `/activities/log-meeting` | Log a meeting | Session |
| `POST` | `/activities/log-email` | Log an email | Session |
| `POST` | `/activities` | Create generic activity | Session |

### Notes — NEW
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/notes` | List notes for entity (`?entityType=project&entityId=uuid`) | Session |
| `GET`  | `/notes/:id` | Get single note | Session |
| `POST` | `/notes` | Create note on any entity | Session |
| `PATCH`| `/notes/:id` | Update note content or pin status | Session (Own) |
| `POST` | `/notes/:id/pin` | Toggle pin status | Session (Own) |
| `DELETE`| `/notes/:id` | Soft delete | Session (Own/Admin) |

### Assignments & Pools — NEW
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/assignments/pools` | List all assignment pools with members | Admin |
| `POST` | `/assignments/pools` | Create pool | Admin |
| `DELETE`| `/assignments/pools/:id` | Delete pool | Admin |
| `POST` | `/assignments/pools/members/add` | Add user to pool | Admin |
| `POST` | `/assignments/pools/members/remove` | Remove user from pool | Admin |
| `GET`  | `/assignments/history` | Assignment history for entity | Session |
| `GET`  | `/assignments/unassigned` | Unassigned leads available for pool-pick | Session |

### SLA Policies & Escalations — NEW
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/slas/policies` | List SLA policies | Admin |
| `POST` | `/slas/policies` | Create SLA policy | Admin |
| `PATCH`| `/slas/policies/:id` | Update policy | Admin |
| `DELETE`| `/slas/policies/:id` | Delete policy | Admin |
| `POST` | `/slas/check-breaches` | Trigger SLA breach check (cron-callable) | Admin |
| `GET`  | `/slas/escalations` | List escalation logs | Admin |
| `POST` | `/slas/escalations/:id/resolve` | Mark escalation resolved | Admin |

### Documents
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `POST` | `/documents/upload` | Upload document (multipart/form-data) | Session |
| `GET`  | `/documents` | List documents (filterable by entity) | Session |
| `GET`  | `/documents/:id` | Document detail + version history | Session |
| `POST` | `/documents/:id/approve` | Approve document | Manager/Admin |
| `POST` | `/documents/:id/share` | Create share token | Session |
| `GET`  | `/documents/share/:token` | Access shared document | Public (token) |

### Communications (Legacy — use Activities for new features)
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `POST` | `/communications` | Log call/meeting/email | Session |
| `GET`  | `/communications` | List communications for entity | Session |

### Quotations & Expenses
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `POST` | `/quotations` | Create quotation with line items | Session |
| `GET`  | `/quotations` | List quotations | Session |
| `GET`  | `/quotations/:id` | Quotation detail | Session |
| `PATCH`| `/quotations/:id/status` | Update quotation status | Session |
| `POST` | `/expenses` | Log expense with receipt | Session |
| `GET`  | `/expenses` | List project expenses | Session |

### Reports & Dashboard
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/reports` | List available reports | Session |
| `GET`  | `/reports/:key` | Run and return report data | Session |
| `GET`  | `/reports/:key/csv` | Export report as CSV | Session |
| `GET`  | `/dashboard` | KPI summary (leads, opportunities, projects, tasks) | Session |

### Search
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/search?q=...` | Global full-text search | Session |

### Runtime / Configuration
| Method | Route | Description | Auth |
|--------|-------|-------------|------|
| `GET`  | `/runtime/metadata` | Full UI config: entities, fields, lookups, endpoints | Session |
| `GET`  | `/runtime/lookups` | All lookup sets and values | Session |
| `GET`  | `/runtime/entity/:key` | Entity UI config + field schema | Session |

---

## 4. RESPONSE & ERROR CONVENTIONS

### Success Envelope
```json
{
  "rid":        "s-opportunity-created",
  "statusCode": 201,
  "data":       { "id": "uuid", "opportunityNumber": "OPP-2026-0001" },
  "message":    "Opportunity created successfully",
  "meta":       { "timestamp": "2026-03-29T..." }
}
```

### Error Envelope
```json
{
  "rid":        "e-lead-already-converted",
  "statusCode": 400,
  "data":       null,
  "message":    "Lead has already been converted to an Opportunity",
  "errors":     []
}
```

### Comprehensive RID Registry
| Status | RID | Cause |
|--------|-----|-------|
| 200 | `s-leads-listed` | Leads list returned |
| 201 | `s-lead-created` | Lead created |
| 200 | `s-lead-updated` | Lead updated |
| 200 | `s-lead-status-updated` | Lead status changed |
| 200 | `s-lead-converted` | Lead converted to Opportunity |
| 200 | `s-lead-assigned` | Lead assigned to user |
| 200 | `s-lead-claimed` | Lead claimed from pool |
| 200 | `s-opportunities-listed` | Opportunities listed |
| 201 | `s-opportunity-created` | Opportunity created |
| 200 | `s-opportunity-updated` | Opportunity updated |
| 200 | `s-opportunity-stage-updated` | Opportunity stage changed |
| 200 | `s-opportunity-won` | Opportunity won, Project created |
| 200 | `s-opportunity-lost` | Opportunity marked lost |
| 200 | `s-opportunity-assigned` | Opportunity reassigned |
| 200 | `s-activities-listed` | Activities listed |
| 201 | `s-call-logged` | Call logged to timeline |
| 201 | `s-meeting-logged` | Meeting logged to timeline |
| 201 | `s-email-logged` | Email logged to timeline |
| 200 | `s-notes-listed` | Notes listed |
| 201 | `s-note-created` | Note created |
| 200 | `s-note-updated` | Note updated |
| 200 | `s-note-pinned` | Note pin toggled |
| 200 | `s-pools-listed` | Assignment pools listed |
| 201 | `s-pool-created` | Pool created |
| 200 | `s-pool-member-added` | User added to pool |
| 200 | `s-assignment-history-listed` | Assignment history listed |
| 200 | `s-sla-policies-listed` | SLA policies listed |
| 201 | `s-sla-policy-created` | SLA policy created |
| 200 | `s-sla-check-complete` | SLA breach check completed |
| 200 | `s-escalations-listed` | Escalation logs listed |
| 200 | `s-escalation-resolved` | Escalation resolved |
| 400 | `e-lead-already-converted` | Lead has existing Opportunity |
| 400 | `e-lead-not-claimable` | Lead already assigned or not found |
| 400 | `e-opportunity-closed` | Cannot change closed Opportunity stage |
| 400 | `e-opportunity-already-closed` | Attempt to close already-closed deal |
| 401 | `e-unauthorized` | No valid session |
| 403 | `e-forbidden` | Insufficient permissions |
| 403 | `e-note-forbidden` | Cannot edit/delete another user's note |
| 404 | `e-lead-not-found` | Lead not found |
| 404 | `e-opportunity-not-found` | Opportunity not found |
| 404 | `e-note-not-found` | Note not found |
| 400 | `e-invalid-op` | Unknown operation sent to dispatcher |

---

## 5. PAGINATION STANDARD
All list endpoints accept:
```typescript
{ page?: number, limit?: number, offset?: number, q?: string, sortBy?: string, sortOrder?: 'ASC'|'DESC' }
```

---

## 6. FIELD NAMING CONVENTION
- **JSON Payloads (API)**: `camelCase` (e.g., `assignedTo`, `expectedCloseDate`)
- **Database Columns**: `snake_case` (e.g., `assigned_to`, `expected_close_date`)
- **URL Params**: `camelCase` (e.g., `:leadId`, `:projectId`)
