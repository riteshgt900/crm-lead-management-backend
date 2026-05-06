# CRM Backend — Technical Architecture & Design Patterns
**Date**: 2026-04-29  
**Version**: 1.0

---

## 1. CORE ARCHITECTURAL PATTERNS

### 1.1 "Thin Nest, Thick PostgreSQL" Pattern

This is the **non-negotiable** architectural law:

```
┌─────────────────────────────────────────────────────────────┐
│                    NestJS Layer (Thin)                      │
├─────────────────────────────────────────────────────────────┤
│ • Controllers: DTO validation, session checks               │
│ • Services: Pass-through to database layer                  │
│ • Guards: Session validation, RBAC checks                   │
│ • Interceptors: Response envelope wrapping                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL Layer (Thick)                       │
├─────────────────────────────────────────────────────────────┤
│ • Dispatcher Functions: ALL business logic                  │
│ • Triggers: Audit trails, soft deletes, cascades           │
│ • Indexes: Performance optimization (GIN, B-tree)          │
│ • Constraints: Data integrity enforcement                  │
└─────────────────────────────────────────────────────────────┘
```

**Why?**
- **Single Source of Truth**: Business logic in one place (database)
- **Consistency**: All clients (web, mobile, API) execute same logic
- **Auditability**: Triggers capture all changes automatically
- **Performance**: Database-level optimizations, connection pooling
- **Scalability**: Stateless NestJS servers, database handles concurrency

### 1.2 Request Lifecycle

```
1. Client Request (with crm_session cookie)
   ↓
2. SessionGuard
   - Validates cookie via fn_auth_operations('validate_session')
   - Populates req.user { id, roleId, roleName, permissions[] }
   ↓
3. Controller
   - Validates DTO (class-validator)
   - Checks @Permissions('module:action') decorator
   - Calls Service method
   ↓
4. Service
   - Pass-through: return this.db.callDispatcher(fnName, payload)
   ↓
5. DatabaseService
   - Checks ALLOWED_FUNCTIONS whitelist
   - Calls PostgreSQL dispatcher function
   ↓
6. PostgreSQL Dispatcher
   - Executes business logic
   - Returns JSONB response: { success, data, errors }
   ↓
7. ResponseInterceptor
   - Wraps response in envelope: { rid, statusCode, data, message, meta }
   ↓
8. Client Response
```

### 1.3 Response Envelope (Universal Format)

Every response follows this structure:

```typescript
interface ApiResponse<T> {
  rid: string;              // Request ID (e.g., "s-lead-create")
  statusCode: number;       // HTTP status code
  data: T;                  // Actual payload
  message: string;          // Human-readable message
  errors: ErrorDetail[] | null;  // Validation/business errors
  meta: {
    timestamp: string;      // ISO 8601 timestamp
    [key: string]: any;     // Additional metadata
  };
}
```

**Example Success Response:**
```json
{
  "rid": "s-lead-create",
  "statusCode": 201,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Acme Corp",
    "email": "contact@acme.com",
    "status": "new",
    "created_at": "2026-04-29T05:45:48Z"
  },
  "message": "Lead created successfully",
  "errors": null,
  "meta": {
    "timestamp": "2026-04-29T05:45:48.892Z"
  }
}
```

**Example Error Response:**
```json
{
  "rid": "s-lead-create",
  "statusCode": 400,
  "data": null,
  "message": "Validation failed",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ],
  "meta": {
    "timestamp": "2026-04-29T05:45:48.892Z"
  }
}
```

---

## 2. AUTHENTICATION & AUTHORIZATION

### 2.1 Session-Based Authentication (No JWT)

**Why No JWT?**
- Sessions are stateful (easier to revoke)
- HttpOnly cookies prevent XSS attacks
- Server-side session management for compliance
- Simpler logout (just delete session)

**Flow:**
```
1. POST /auth/login { email, password }
   ↓
2. fn_auth_operations('login', { email, password })
   - Hash password with bcrypt
   - Validate against users table
   - Create session record
   - Return session token
   ↓
3. Set HttpOnly cookie: crm_session=<token>
   - Secure: true (production only)
   - SameSite: Lax
   - HttpOnly: true
   - MaxAge: 604800000 (7 days)
   ↓
4. Subsequent requests include cookie automatically
   ↓
5. SessionGuard validates cookie on every request
```

### 2.2 RBAC (Role-Based Access Control)

**Hierarchy:**
```
super_admin (Ultimate authority)
    ↓
admin (Broad access, cannot modify super_admin)
    ↓
manager (Team management, reporting)
    ↓
team_member (Standard user)
    ↓
external (Guest/vendor access)
```

**Permission Model:**
```
Permission Slug Format: "module:action"

Examples:
- leads:view, leads:create, leads:edit, leads:delete, leads:convert
- opportunities:view, opportunities:create, opportunities:edit, opportunities:delete
- projects:view, projects:create, projects:edit, projects:delete
- tasks:view, tasks:create, tasks:edit, tasks:delete
- users:manage, roles:manage, permissions:manage
- reports:view, reports:export
```

**Implementation:**
```typescript
// In Controller
@Post('leads')
@Permissions('leads:create')
async createLead(@Body() dto: CreateLeadDto) {
  return this.leadsService.create(dto);
}

// PermissionsGuard checks req.user.permissions[]
// If permission not found, returns 403 Forbidden
```

**Permission Caching:**
```
1. User logs in
2. fn_auth_operations('login') returns permissions[]
3. Stored in req.user.permissions (in-memory)
4. Checked on every @Permissions() decorator
5. No database query per request (performance)
```

---

## 3. DATABASE DESIGN PATTERNS

### 3.1 Soft Deletes (Never Hard Delete)

**Pattern:**
```sql
-- Instead of: DELETE FROM leads WHERE id = $1;
-- Use: UPDATE leads SET deleted_at = NOW() WHERE id = $1;

-- All queries automatically filter:
SELECT * FROM leads WHERE deleted_at IS NULL;
```

**Benefits:**
- Audit trail preserved
- Data recovery possible
- Compliance with retention policies
- No cascading deletes

### 3.2 Dispatcher Functions (Business Logic)

**Pattern:**
```sql
CREATE OR REPLACE FUNCTION fn_lead_operations(
  p_operation VARCHAR,
  p_payload JSONB
) RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  CASE p_operation
    WHEN 'create' THEN
      v_result := create_lead(p_payload);
    WHEN 'update' THEN
      v_result := update_lead(p_payload);
    WHEN 'convert' THEN
      v_result := convert_lead(p_payload);
    ELSE
      RETURN fn_error_envelope('invalid_operation', 400, 'Unknown operation');
  END CASE;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
```

**Benefits:**
- Single entry point per module
- Atomic transactions
- Consistent error handling
- Audit trail via triggers
- Reusable across clients

### 3.3 Audit Triggers

**Pattern:**
```sql
CREATE TRIGGER trg_audit_leads
AFTER INSERT OR UPDATE OR DELETE ON leads
FOR EACH ROW
EXECUTE FUNCTION fn_audit_trigger('leads');

-- fn_audit_trigger captures:
-- - old_values (before update/delete)
-- - new_values (after insert/update)
-- - operation (INSERT/UPDATE/DELETE)
-- - user_id (from session)
-- - timestamp (NOW())
```

**Benefits:**
- Complete change history
- Compliance & legal holds
- Debugging & troubleshooting
- No manual logging needed

### 3.4 Polymorphic Relationships

**Pattern:**
```sql
-- Activities table (works for ANY entity)
CREATE TABLE activities (
  id UUID PRIMARY KEY,
  entity_type VARCHAR(50),  -- 'lead', 'opportunity', 'project'
  entity_id UUID,           -- ID of the entity
  activity_type VARCHAR(50), -- 'call', 'meeting', 'email', 'note'
  description TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ
);

-- Query activities for ANY entity:
SELECT * FROM activities 
WHERE entity_type = 'lead' AND entity_id = $1
ORDER BY created_at DESC;
```

**Benefits:**
- Single component in frontend
- Reduced code duplication
- Flexible entity relationships
- Easy to extend

---

## 4. API DESIGN PATTERNS

### 4.1 RESTful Conventions

**Standard CRUD:**
```
GET    /api/leads              → List all leads
POST   /api/leads              → Create lead
GET    /api/leads/:id          → Get lead detail
PATCH  /api/leads/:id          → Update lead
DELETE /api/leads/:id          → Delete (soft) lead
```

**Custom Actions:**
```
POST   /api/leads/:id/convert  → Convert lead to opportunity
POST   /api/leads/:id/assign   → Assign lead to user
POST   /api/leads/:id/claim    → Self-claim lead
PATCH  /api/leads/:id/status   → Update status with reason
```

**Bulk Operations:**
```
POST   /api/leads/bulk         → Bulk update (status, assignment)
```

### 4.2 Query Parameters

**Filtering:**
```
GET /api/leads?status=new&source=website
GET /api/opportunities?stage=prospecting&assignedTo=user-123
```

**Pagination:**
```
GET /api/leads?page=1&limit=20
GET /api/projects?offset=0&limit=50
```

**Sorting:**
```
GET /api/leads?sort=created_at:desc
GET /api/tasks?sort=priority:desc,due_date:asc
```

**Search:**
```
GET /api/search?q=acme&type=lead,opportunity
POST /api/search/advanced { filters, sort, pagination }
```

### 4.3 Error Handling

**HTTP Status Codes:**
```
200 OK              → Successful GET/PATCH
201 Created         → Successful POST
204 No Content      → Successful DELETE
400 Bad Request     → Validation error
401 Unauthorized    → Missing/invalid session
403 Forbidden       → Insufficient permissions
404 Not Found       → Resource not found
409 Conflict        → Business logic violation
500 Internal Error  → Unexpected server error
```

**Error Response Format:**
```json
{
  "rid": "s-lead-create",
  "statusCode": 400,
  "data": null,
  "message": "Validation failed",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format"
    },
    {
      "field": "name",
      "message": "Name is required"
    }
  ],
  "meta": {
    "timestamp": "2026-04-29T05:45:48.892Z"
  }
}
```

---

## 5. DATA VALIDATION PATTERNS

### 5.1 DTO Validation (NestJS)

**Pattern:**
```typescript
import { IsEmail, IsNotEmpty, IsEnum, MinLength } from 'class-validator';

export class CreateLeadDto {
  @IsNotEmpty()
  @MinLength(3)
  name: string;

  @IsEmail()
  email: string;

  @IsEnum(['website', 'referral', 'social_media', 'cold_call', 'email_campaign', 'event', 'partner', 'other'])
  source: string;

  phone?: string;
  company?: string;
}
```

**Benefits:**
- Type-safe validation
- Automatic error messages
- Whitelist/forbid unknown properties
- Transformation (trim, lowercase)

### 5.2 Database Constraints

**Pattern:**
```sql
-- NOT NULL constraints
ALTER TABLE leads ADD CONSTRAINT chk_name_not_empty CHECK (name != '');

-- UNIQUE constraints
ALTER TABLE users ADD CONSTRAINT uq_email UNIQUE (email);

-- FOREIGN KEY constraints
ALTER TABLE leads ADD CONSTRAINT fk_assigned_to 
  FOREIGN KEY (assigned_to) REFERENCES users(id);

-- CHECK constraints
ALTER TABLE tasks ADD CONSTRAINT chk_priority 
  CHECK (priority IN ('low', 'medium', 'high', 'critical'));

-- DEFAULT values
ALTER TABLE leads ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
```

**Benefits:**
- Data integrity at database level
- Prevents invalid data entry
- Consistent across all clients
- Performance (indexes on constraints)

---

## 6. PERFORMANCE OPTIMIZATION PATTERNS

### 6.1 Indexing Strategy

**Pattern:**
```sql
-- B-tree indexes (default, for equality/range queries)
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_assigned_to ON leads(assigned_to);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);

-- Composite indexes (for common filter combinations)
CREATE INDEX idx_leads_status_assigned ON leads(status, assigned_to);

-- GIN indexes (for full-text search)
CREATE INDEX idx_leads_search ON leads USING GIN(
  to_tsvector('english', name || ' ' || email || ' ' || company)
);

-- Partial indexes (for soft deletes)
CREATE INDEX idx_leads_active ON leads(id) WHERE deleted_at IS NULL;
```

**Benefits:**
- Fast queries (O(log n) instead of O(n))
- Reduced disk I/O
- Better query planner decisions

### 6.2 Query Optimization

**Pattern:**
```sql
-- ❌ Bad: N+1 queries
SELECT * FROM leads;
-- Then loop and query: SELECT * FROM contacts WHERE lead_id = $1;

-- ✅ Good: Single query with JOIN
SELECT l.*, c.* FROM leads l
LEFT JOIN contacts c ON l.id = c.lead_id
WHERE l.deleted_at IS NULL;

-- ✅ Better: Use dispatcher function
SELECT fn_lead_operations('get_with_contacts', '{"lead_id": "..."}');
```

### 6.3 Connection Pooling

**Pattern:**
```typescript
// DatabaseModule uses pg.Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,              // Max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

**Benefits:**
- Reuse connections (expensive to create)
- Prevent connection exhaustion
- Better resource utilization

---

## 7. SECURITY PATTERNS

### 7.1 SQL Injection Prevention

**Pattern:**
```typescript
// ❌ Bad: String interpolation
const query = `SELECT * FROM leads WHERE id = '${leadId}'`;

// ✅ Good: Parameterized queries
const query = 'SELECT * FROM leads WHERE id = $1';
const result = await pool.query(query, [leadId]);

// ✅ Better: Use format() with identifiers
const query = format('SELECT * FROM %I WHERE %I = %L', 'leads', 'id', leadId);
```

### 7.2 CORS & CSRF Protection

**Pattern:**
```typescript
// main.ts
app.enableCors({
  origin: process.env.CORS_ORIGIN,  // Whitelist specific origins
  credentials: true,                 // Allow cookies
  methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type'],
});

// Helmet.js adds CSRF tokens automatically
app.use(helmet());
```

### 7.3 Rate Limiting

**Pattern:**
```typescript
// app.module.ts
ThrottlerModule.forRoot([
  {
    ttl: 60000,      // 1 minute
    limit: 100,      // 100 requests
  },
]),

// Custom rate limiting for auth routes
@UseGuards(ThrottlerGuard)
@Post('auth/login')
async login(@Body() dto: LoginDto) {
  // Max 5 requests per minute
}
```

---

## 8. TESTING PATTERNS

### 8.1 Unit Testing (Services)

**Pattern:**
```typescript
describe('LeadsService', () => {
  let service: LeadsService;
  let db: DatabaseService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        LeadsService,
        {
          provide: DatabaseService,
          useValue: { callDispatcher: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<LeadsService>(LeadsService);
    db = module.get<DatabaseService>(DatabaseService);
  });

  it('should create a lead', async () => {
    const dto = { name: 'Acme', email: 'contact@acme.com' };
    jest.spyOn(db, 'callDispatcher').mockResolvedValue({
      success: true,
      data: { id: '123', ...dto },
    });

    const result = await service.create(dto);
    expect(result.data.name).toBe('Acme');
  });
});
```

### 8.2 E2E Testing

**Pattern:**
```typescript
describe('Leads (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('POST /leads should create a lead', () => {
    return request(app.getHttpServer())
      .post('/api/leads')
      .set('Cookie', 'crm_session=valid_token')
      .send({ name: 'Acme', email: 'contact@acme.com' })
      .expect(201)
      .expect((res) => {
        expect(res.body.data.id).toBeDefined();
      });
  });
});
```

---

## 9. DEPLOYMENT PATTERNS

### 9.1 Environment Configuration

**Pattern:**
```env
# .env.production
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@prod-db:5432/crm_prod
SESSION_SECRET=<strong-random-secret>
CORS_ORIGIN=https://crm.example.com
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USER=apikey
MAIL_PASS=<sendgrid-api-key>
```

### 9.2 Build & Start

**Pattern:**
```bash
# Build
npm run build

# Start production
npm run start:prod

# With PM2 (process manager)
pm2 start dist/main.js --name "crm-backend" --instances max
```

---

## 10. MIGRATION PATTERNS

### 10.1 Migration Versioning

**Pattern:**
```
database/migrations/
├── V000__schema.sql
├── V001__extensions.sql
├── V002__enums.sql
├── ...
├── V085__crm_new_modules_seed.sql
├── V086__client_portal_schema.sql
└── V087__fn_portal_ops.sql
```

**Rules:**
- Always increment version number
- Never modify existing migrations
- Use `CREATE OR REPLACE FUNCTION` for function updates
- Include rollback logic in comments

### 10.2 Migration Execution

**Pattern:**
```bash
# Run all pending migrations
npm run db:migrate

# Seed initial data
npm run db:seed

# Dump schema
npm run db:dump
```

---

## 11. MONITORING & LOGGING PATTERNS

### 11.1 Operation Logging

**Pattern:**
```sql
-- ai_operation_logs table
INSERT INTO ai_operation_logs (
  operation_name,
  status,
  input_payload,
  output_payload,
  error_message,
  created_at
) VALUES (
  'create_lead',
  'success',
  '{"name": "Acme", "email": "contact@acme.com"}',
  '{"id": "123", "name": "Acme", ...}',
  NULL,
  NOW()
);
```

### 11.2 Audit Trail

**Pattern:**
```sql
-- audit_logs table (auto-populated by triggers)
SELECT * FROM audit_logs
WHERE entity_type = 'leads'
  AND entity_id = '123'
ORDER BY created_at DESC;

-- Returns:
-- { old_values, new_values, operation, user_id, timestamp }
```

---

## 12. COMMON GOTCHAS & SOLUTIONS

### Gotcha 1: N+1 Query Problem
**Solution**: Use JOINs or dispatcher functions that fetch related data in one query.

### Gotcha 2: Missing Soft Delete Filter
**Solution**: Always include `WHERE deleted_at IS NULL` in queries.

### Gotcha 3: Unvalidated User Input
**Solution**: Use DTOs with class-validator, never trust client data.

### Gotcha 4: Hardcoded Business Logic in NestJS
**Solution**: Move ALL logic to PostgreSQL dispatchers.

### Gotcha 5: Missing RBAC Checks
**Solution**: Use @Permissions() decorator on every protected endpoint.

### Gotcha 6: Unencrypted Passwords
**Solution**: Always use bcrypt (never store plain text).

### Gotcha 7: Missing Audit Trail
**Solution**: Triggers automatically capture all changes.

### Gotcha 8: Hardcoded Configuration
**Solution**: Use environment variables via ConfigService.

---

**End of Technical Architecture Document**
