# 04_API_AND_AUTH.md
# CRM for Lead Management — API Contracts & Authentication

## 1. AUTHENTICATION (Cookie-Based)
- **Strategy**: HttpOnly Cookie (`crm_session`). **No JWT.**
- **Security**: `Secure: true` (prod), `SameSite: Lax`, `HttpOnly: true`.
- **Flow**:
    - `POST /auth/login` -> Sets cookie.
    - `SessionGuard` -> Extracts cookie, calls `fn_auth_operations('validate_session')`.
    - `req.user` -> Populated with `id`, `roleId`, `roleName`, `permissions[]` (slug strings).
- **Authorization**: Use the `@Permissions('module:action')` decorator. The `PermissionsGuard` must check if the slug exists in `req.user.permissions[]`.

---

## 2. SYSTEM RATE LIMITING
- **Global API**: `@nestjs/throttler` (e.g., 100 requests per minute).
- **Auth Routes (`/auth/*`)**: Strict limit (e.g., 5 requests per minute) to prevent brute force attacks.

---

## 3. API ENDPOINT REGISTRY

### Auth & User
| Method | Route | Desc | Role |
| :--- | :--- | :--- | :--- |
| POST | `/auth/login` | Login | Public |
| GET  | `/auth/profile` | My Profile (Returns user + `permissions[]` for UI rendering) | Session |
| POST | `/users/invite` | Invite User | Admin |

### UI Configuration & Dynamic RBAC (Super Admin Only)
*These APIs power the "Settings" UI where Super Admins configure what each role can see.*
| Method | Route | Desc | Role |
| :--- | :--- | :--- | :--- |
| GET  | `/rbac/permissions` | List all available modules/tabs | Super Admin |
| GET  | `/rbac/roles` | List Roles | Super Admin |
| POST | `/rbac/roles` | Create new custom Role | Super Admin |
| POST | `/rbac/roles/:id/permissions`| Assign permissions to a specific role | Super Admin |

### Sales & Projects
| Method | Route | Desc |
| :--- | :--- | :--- |
| POST | `/leads` | Create Lead |
| PATCH | `/leads/:id/status` | Update status + follow-up date |
| POST | `/leads/bulk` | Update status/owner for multiple IDs |
| POST | `/leads/:id/convert` | Convert to Project + Contact |
| GET  | `/projects/:id/tasks` | List Project Tasks |
| POST | `/quotations` | Create Estimate |

### Collaboration & Finance
| Method | Route | Desc |
| :--- | :--- | :--- |
| POST | `/documents/upload` | File Upload |
| POST | `/communications` | Log Call/Meeting |
| POST | `/expenses` | Log Project Expense |

---

## 3. DTO & VALIDATION CONTRACTS
All inputs use `class-validator` decorators.

### Global Pagination & Query Standard
Every `GET /list` endpoint must accept and parse the following query parameters:
```typescript
class PaginationQueryDto {
    @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number = 1;
    @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number = 20;
    @IsOptional() @IsString() sortBy?: string = 'created_at';
    @IsOptional() @IsEnum(['ASC', 'DESC']) sortOrder?: 'ASC' | 'DESC' = 'DESC';
}
```
}
```
*Note: The NestJS Service must pass these directly to the SQL Dispatcher. Use `camelCase` for all route parameters (e.g., `:leadId`, `:projectId`).*

### Example: CreateLeadDto
```typescript
export class CreateLeadDto {
    @IsString() @MaxLength(255) title: string;
    @IsEnum(LeadSource) source: LeadSource;
    @IsNumber() @IsPositive() estimatedValue: number;
    @IsOptional() @IsUUID() contactId?: string;
}
```

---

## 4. ERROR & SUCCESS REGISTRY
All results use the `rid` (Response ID) convention for frontend mapping.
- **Success Prefix**: `s-` (e.g., `s-lead-created`)
- **Error Prefix**: `e-` (e.g., `e-unauthorized`)

| Status | rid | Message |
| :--- | :--- | :--- |
| 401 | `e-unauthorized` | Authentication required |
| 403 | `e-forbidden` | Insufficient permissions |
| 404 | `e-lead-not-found` | Resource does not exist |
| 409 | `e-email-exists` | Account already exists |
| 400 | `e-validation-failed` | DTO validation logic failed |

---

## 5. RESPONSE ENVELOPE
```json
{
  "rid": "s-lead-created",
  "statusCode": 201,
  "data": { "id": "uuid", "leadNumber": "LEAD-001" },
  "message": "Lead created successfully",
  "meta": { "timestamp": "..." }
}
```
