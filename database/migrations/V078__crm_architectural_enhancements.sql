SET search_path = crm, public;

-- V078: CRM Architectural Enhancements
-- Introduces: Opportunity (Deal) Layer, Activity Timeline, Notes, Assignment Pools,
--             SLA Policies, Escalation Logs, Assignment History, Lead Conversion Traceability

-- ─────────────────────────────────────────────
-- 1. ENUMS
-- ─────────────────────────────────────────────
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'opportunity_stage') THEN
        CREATE TYPE opportunity_stage AS ENUM (
            'prospecting',
            'proposal',
            'negotiation',
            'won',
            'lost'
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_type') THEN
        CREATE TYPE activity_type AS ENUM (
            'call',
            'meeting',
            'email',
            'task',
            'note',
            'system_event'
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_rule_type') THEN
        CREATE TYPE assignment_rule_type AS ENUM (
            'round_robin',
            'pool',
            'manual'
        );
    END IF;
END $$;

-- ─────────────────────────────────────────────
-- 2. SEQUENCES
-- ─────────────────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS opportunity_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_opportunity_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'OPP-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('opportunity_number_seq')::TEXT, 4, '0');
END; $$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────
-- 3. OPPORTUNITIES (DEAL LAYER)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS opportunities (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_number   VARCHAR(20) UNIQUE NOT NULL,
    title                VARCHAR(255) NOT NULL,
    description          TEXT,
    lead_id              UUID REFERENCES leads(id),
    account_id           UUID REFERENCES accounts(id),
    contact_id           UUID REFERENCES contacts(id),
    stage                opportunity_stage NOT NULL DEFAULT 'prospecting',
    amount               NUMERIC(15, 2) NOT NULL DEFAULT 0,
    expected_close_date  DATE,
    probability          INT NOT NULL DEFAULT 0 CHECK (probability >= 0 AND probability <= 100),
    assigned_to          UUID REFERENCES users(id),
    lost_reason          TEXT,
    won_at               TIMESTAMPTZ,
    lost_at              TIMESTAMPTZ,
    metadata             JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at           TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_opportunities_lead_active        ON opportunities (lead_id)     WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_opportunities_account_active     ON opportunities (account_id)  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_opportunities_assigned_active    ON opportunities (assigned_to) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_opportunities_stage_active       ON opportunities (stage)       WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_opportunities_close_date_active  ON opportunities (expected_close_date) WHERE deleted_at IS NULL;

-- ─────────────────────────────────────────────
-- 4. LEAD CONVERSION TRACEABILITY
-- ─────────────────────────────────────────────
ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS converted_account_id     UUID REFERENCES accounts(id),
    ADD COLUMN IF NOT EXISTS converted_contact_id     UUID REFERENCES contacts(id),
    ADD COLUMN IF NOT EXISTS converted_opportunity_id UUID REFERENCES opportunities(id);

-- Link projects back to the Opportunity that generated them
ALTER TABLE projects
    ADD COLUMN IF NOT EXISTS opportunity_id UUID REFERENCES opportunities(id);

CREATE INDEX IF NOT EXISTS idx_leads_opp_conversion_active ON leads (converted_opportunity_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_projects_opportunity_active  ON projects (opportunity_id)       WHERE deleted_at IS NULL;

-- ─────────────────────────────────────────────
-- 5. ACTIVITY / UNIFIED TIMELINE
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activities (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type   VARCHAR(120) NOT NULL,   -- 'lead', 'opportunity', 'project', 'task', 'contact', 'account'
    entity_id     UUID NOT NULL,
    type          activity_type NOT NULL,
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    performed_by  UUID REFERENCES users(id),
    activity_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_activities_entity_active ON activities (entity_type, entity_id, activity_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activities_performer_active ON activities (performed_by) WHERE deleted_at IS NULL;

-- ─────────────────────────────────────────────
-- 6. NOTES MODULE
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(120) NOT NULL,   -- 'lead', 'opportunity', 'project', 'task', 'contact', 'account'
    entity_id   UUID NOT NULL,
    content     TEXT NOT NULL,
    created_by  UUID REFERENCES users(id),
    is_pinned   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notes_entity_active ON notes (entity_type, entity_id, is_pinned DESC, created_at DESC) WHERE deleted_at IS NULL;

-- ─────────────────────────────────────────────
-- 7. ASSIGNMENT HISTORY
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS assignment_history (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type      VARCHAR(120) NOT NULL,  -- 'lead', 'opportunity', 'project', 'task'
    entity_id        UUID NOT NULL,
    previous_user_id UUID REFERENCES users(id),
    new_user_id      UUID REFERENCES users(id),
    assigned_by      UUID REFERENCES users(id),
    reason           TEXT,
    assigned_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assignment_history_entity ON assignment_history (entity_type, entity_id, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_assignment_history_user   ON assignment_history (new_user_id, assigned_at DESC);

-- ─────────────────────────────────────────────
-- 8. ASSIGNMENT POOLS (Round Robin / Pool Pick / Manual)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS assignment_pools (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(255) NOT NULL,
    entity_type  VARCHAR(120) NOT NULL DEFAULT 'lead',  -- which entity this pool serves
    rule_type    assignment_rule_type NOT NULL DEFAULT 'round_robin',
    current_index INT NOT NULL DEFAULT 0,               -- pointer for round-robin
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    metadata     JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS pool_members (
    pool_id          UUID NOT NULL REFERENCES assignment_pools(id) ON DELETE CASCADE,
    user_id          UUID NOT NULL REFERENCES users(id),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    assignment_count INT NOT NULL DEFAULT 0,
    added_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (pool_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_assignment_pools_entity_active ON assignment_pools (entity_type, is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_pool_members_pool_active       ON pool_members (pool_id, is_active);

-- ─────────────────────────────────────────────
-- 9. SLA POLICIES
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sla_policies (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  VARCHAR(255) NOT NULL,
    entity_type           VARCHAR(120) NOT NULL,  -- 'lead', 'opportunity', 'task', 'project'
    condition_json        JSONB NOT NULL DEFAULT '{}'::jsonb,  -- e.g. { "priority": "critical" }
    due_time_hours        INT NOT NULL DEFAULT 24,
    escalation_time_hours INT NOT NULL DEFAULT 48,
    notify_manager        BOOLEAN NOT NULL DEFAULT TRUE,
    escalation_user_id    UUID REFERENCES users(id),  -- override escalation target
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at            TIMESTAMPTZ
);

-- ─────────────────────────────────────────────
-- 10. ESCALATION LOGS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS escalation_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     VARCHAR(120) NOT NULL,
    entity_id       UUID NOT NULL,
    sla_policy_id   UUID REFERENCES sla_policies(id),
    escalated_from  UUID REFERENCES users(id),
    escalated_to    UUID REFERENCES users(id),
    reason          TEXT,
    status          VARCHAR(50) NOT NULL DEFAULT 'open',  -- 'open', 'acknowledged', 'resolved'
    escalated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_escalation_logs_entity_active ON escalation_logs (entity_type, entity_id, escalated_at DESC);
CREATE INDEX IF NOT EXISTS idx_escalation_logs_status        ON escalation_logs (status) WHERE status != 'resolved';

-- ─────────────────────────────────────────────
-- 11. ATTACH TRIGGERS (updated_at, audit)
-- ─────────────────────────────────────────────
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'opportunities',
        'notes',
        'assignment_pools',
        'sla_policies'
    ]
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at_%I ON crm.%I', t, t);
        EXECUTE format(
            'CREATE TRIGGER trg_set_updated_at_%I BEFORE UPDATE ON crm.%I FOR EACH ROW EXECUTE FUNCTION crm.fn_set_updated_at()',
            t, t
        );
    END LOOP;
END;
$$;

DO $$
DECLARE
    t TEXT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'crm'
          AND p.proname = 'fn_audit_operation'
    ) THEN
        FOREACH t IN ARRAY ARRAY[
            'opportunities',
            'notes',
            'assignment_history',
            'assignment_pools',
            'pool_members',
            'sla_policies',
            'escalation_logs'
        ]
        LOOP
            IF EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'crm' AND table_name = t
            ) THEN
                EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%I ON crm.%I', t, t);
                EXECUTE format(
                    'CREATE TRIGGER trg_audit_%I AFTER INSERT OR UPDATE OR DELETE ON crm.%I FOR EACH ROW EXECUTE FUNCTION crm.fn_audit_operation()',
                    t, t
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;
