SET search_path = crm, public;

CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(80) NOT NULL DEFAULT 'company',
    industry VARCHAR(120),
    website TEXT,
    owner_id UUID REFERENCES users(id),
    primary_address TEXT,
    billing_address TEXT,
    tax_id VARCHAR(100),
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS contact_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    label VARCHAR(80) NOT NULL DEFAULT 'primary',
    address_line1 TEXT,
    address_line2 TEXT,
    city VARCHAR(120),
    state VARCHAR(120),
    country VARCHAR(120),
    postal_code VARCHAR(40),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS project_stakeholders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    account_id UUID REFERENCES accounts(id),
    contact_id UUID REFERENCES contacts(id),
    role_key VARCHAR(120) NOT NULL DEFAULT 'stakeholder',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL,
    version_label VARCHAR(120),
    file_name VARCHAR(255),
    file_path TEXT,
    file_type VARCHAR(120),
    file_size BIGINT,
    status document_status NOT NULL DEFAULT 'draft',
    uploaded_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS lookup_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    set_key VARCHAR(120) NOT NULL,
    label VARCHAR(255) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS lookup_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    set_id UUID NOT NULL REFERENCES lookup_sets(id) ON DELETE CASCADE,
    value_key VARCHAR(120) NOT NULL,
    label VARCHAR(255) NOT NULL,
    value_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    color VARCHAR(40),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS custom_field_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    field_key VARCHAR(120) NOT NULL,
    label VARCHAR(255) NOT NULL,
    data_type VARCHAR(60) NOT NULL,
    lookup_set_key VARCHAR(120),
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_filterable BOOLEAN NOT NULL DEFAULT TRUE,
    is_listed BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    default_value_json JSONB DEFAULT 'null'::jsonb,
    config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS custom_field_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    record_id UUID NOT NULL,
    definition_id UUID NOT NULL REFERENCES custom_field_definitions(id) ON DELETE CASCADE,
    value_json JSONB NOT NULL DEFAULT 'null'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ui_entity_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    label VARCHAR(255) NOT NULL,
    table_name VARCHAR(120) NOT NULL,
    primary_key VARCHAR(120) NOT NULL DEFAULT 'id',
    title_column VARCHAR(120),
    default_sort_column VARCHAR(120) NOT NULL DEFAULT 'created_at',
    permission_slug VARCHAR(120) NOT NULL,
    form_key VARCHAR(120) NOT NULL,
    route_base VARCHAR(255) NOT NULL,
    supports_tags BOOLEAN NOT NULL DEFAULT FALSE,
    supports_custom_fields BOOLEAN NOT NULL DEFAULT TRUE,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    list_config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    sample_payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ui_field_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    field_key VARCHAR(120) NOT NULL,
    label VARCHAR(255) NOT NULL,
    column_name VARCHAR(120),
    data_type VARCHAR(60) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_filterable BOOLEAN NOT NULL DEFAULT TRUE,
    is_sortable BOOLEAN NOT NULL DEFAULT TRUE,
    is_readonly BOOLEAN NOT NULL DEFAULT FALSE,
    include_in_list BOOLEAN NOT NULL DEFAULT TRUE,
    include_in_detail BOOLEAN NOT NULL DEFAULT TRUE,
    include_in_create BOOLEAN NOT NULL DEFAULT TRUE,
    include_in_update BOOLEAN NOT NULL DEFAULT TRUE,
    lookup_set_key VARCHAR(120),
    default_value_json JSONB DEFAULT 'null'::jsonb,
    sample_value_json JSONB DEFAULT 'null'::jsonb,
    config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS api_endpoint_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint_key VARCHAR(160) NOT NULL,
    entity_key VARCHAR(120),
    action_key VARCHAR(160),
    dispatcher_fn VARCHAR(160),
    permission_slug VARCHAR(120),
    form_key VARCHAR(120),
    http_method VARCHAR(12) NOT NULL,
    route_path VARCHAR(255) NOT NULL,
    auth_mode VARCHAR(40) NOT NULL DEFAULT 'session',
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    request_schema_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_schema_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    filter_schema_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    sample_payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS report_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_key VARCHAR(160) NOT NULL,
    label VARCHAR(255) NOT NULL,
    description TEXT,
    query_sql TEXT,
    definition_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_materialized BOOLEAN NOT NULL DEFAULT FALSE,
    schedule_cron VARCHAR(120),
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS saved_filters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    owner_id UUID REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    filter_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS record_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_key VARCHAR(120) NOT NULL,
    record_id UUID NOT NULL,
    tag VARCHAR(120) NOT NULL,
    color VARCHAR(40),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS task_dependencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    depends_on_task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    dependency_type VARCHAR(60) NOT NULL DEFAULT 'blocks',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS task_watchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

ALTER TABLE leads ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS primary_contact_id UUID REFERENCES contacts(id);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS category VARCHAR(120);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS stage VARCHAR(120);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS probability INTEGER NOT NULL DEFAULT 0;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS expected_close_at TIMESTAMPTZ;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS next_follow_up_at TIMESTAMPTZ;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS budget_min NUMERIC(14,2);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS budget_max NUMERIC(14,2);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS requirement_summary TEXT;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS phone VARCHAR(60);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

ALTER TABLE contacts ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS alt_phone VARCHAR(60);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS designation VARCHAR(120);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS timezone VARCHAR(80);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS city VARCHAR(120);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS state VARCHAR(120);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS country VARCHAR(120);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS postal_code VARCHAR(40);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id);
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE projects ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES project_templates(id);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS project_type VARCHAR(120);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS health VARCHAR(40);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS budget NUMERIC(14,2);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS percent_complete NUMERIC(5,2) NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS planned_start_at TIMESTAMPTZ;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS escalation_sla_hours INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS entity_type VARCHAR(120);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS category VARCHAR(120);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS version_label VARCHAR(120);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS approval_required BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS share_mode VARCHAR(40) NOT NULL DEFAULT 'internal';
ALTER TABLE documents ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS controlled_document BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE quotations ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id);
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS currency VARCHAR(12) NOT NULL DEFAULT 'INR';
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS tax_mode VARCHAR(40) NOT NULL DEFAULT 'exclusive';
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS discount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS terms TEXT;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS revision_no INTEGER NOT NULL DEFAULT 1;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS subtotal_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS vendor_id UUID REFERENCES contacts(id);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS receipt_document_id UUID REFERENCES documents(id);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE communications ADD COLUMN IF NOT EXISTS entity_type VARCHAR(120);
ALTER TABLE communications ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE communications ADD COLUMN IF NOT EXISTS participant_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE communications ADD COLUMN IF NOT EXISTS next_action_at TIMESTAMPTZ;
ALTER TABLE communications ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE communications ADD COLUMN IF NOT EXISTS channel VARCHAR(60);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS payload JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE workflow_rules ADD COLUMN IF NOT EXISTS entity_key VARCHAR(120);
ALTER TABLE workflow_rules ADD COLUMN IF NOT EXISTS schedule_cron VARCHAR(120);
ALTER TABLE workflow_rules ADD COLUMN IF NOT EXISTS report_key VARCHAR(160);
ALTER TABLE workflow_rules ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

UPDATE documents
SET entity_type = COALESCE(entity_type, module_name),
    version_label = COALESCE(version_label, 'v' || COALESCE(version_number, version, 1)::text)
WHERE entity_type IS NULL
   OR version_label IS NULL;

INSERT INTO accounts (name, type, notes)
SELECT DISTINCT c.company_name, 'company', 'Backfilled from contacts.company_name'
FROM contacts c
WHERE c.company_name IS NOT NULL
  AND btrim(c.company_name) <> ''
  AND NOT EXISTS (
      SELECT 1
      FROM accounts a
      WHERE lower(a.name) = lower(c.company_name)
        AND a.deleted_at IS NULL
  );

UPDATE contacts c
SET account_id = a.id
FROM accounts a
WHERE c.account_id IS NULL
  AND c.company_name IS NOT NULL
  AND lower(a.name) = lower(c.company_name)
  AND a.deleted_at IS NULL;

UPDATE leads
SET primary_contact_id = COALESCE(primary_contact_id, contact_id),
    owner_id = COALESCE(leads.owner_id, leads.assigned_to),
    next_follow_up_at = COALESCE(leads.next_follow_up_at, leads.follow_up_at),
    account_id = COALESCE(leads.account_id, c.account_id),
    email = COALESCE(leads.email, c.email),
    phone = COALESCE(leads.phone, c.phone)
FROM contacts c
WHERE leads.contact_id = c.id;

UPDATE projects
SET account_id = COALESCE(projects.account_id, c.account_id),
    budget = COALESCE(projects.budget, projects.estimated_value),
    percent_complete = COALESCE(projects.percent_complete, 0)
FROM contacts c
WHERE projects.contact_id = c.id;

INSERT INTO project_stakeholders (project_id, account_id, contact_id, role_key, is_primary)
SELECT p.id, p.account_id, p.contact_id, 'primary_contact', TRUE
FROM projects p
WHERE p.contact_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM project_stakeholders ps
      WHERE ps.project_id = p.id
        AND ps.contact_id = p.contact_id
        AND ps.deleted_at IS NULL
  );

INSERT INTO contact_addresses (contact_id, label, address_line1, city, state, country, postal_code, is_primary)
SELECT c.id, 'primary', c.address, c.city, c.state, c.country, c.postal_code, TRUE
FROM contacts c
WHERE c.address IS NOT NULL
  AND btrim(c.address) <> ''
  AND NOT EXISTS (
      SELECT 1
      FROM contact_addresses ca
      WHERE ca.contact_id = c.id
        AND ca.is_primary = TRUE
        AND ca.deleted_at IS NULL
  );

INSERT INTO document_versions (
    document_id,
    version_no,
    version_label,
    file_name,
    file_path,
    file_type,
    file_size,
    status,
    uploaded_by,
    approved_by,
    approved_at,
    notes
)
SELECT
    d.id,
    COALESCE(d.version_number, d.version, 1),
    COALESCE(d.version_label, 'v' || COALESCE(d.version_number, d.version, 1)::text),
    d.file_name,
    d.file_path,
    d.file_type,
    d.file_size,
    d.status,
    d.uploaded_by,
    d.approved_by,
    d.approved_at,
    'Backfilled from documents'
FROM documents d
WHERE NOT EXISTS (
    SELECT 1
    FROM document_versions dv
    WHERE dv.document_id = d.id
      AND dv.version_no = COALESCE(d.version_number, d.version, 1)
      AND dv.deleted_at IS NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_lookup_sets_key_active
    ON lookup_sets (set_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_lookup_values_set_value_active
    ON lookup_values (set_id, value_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_custom_field_definitions_entity_field_active
    ON custom_field_definitions (entity_key, field_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_custom_field_values_entity_record_definition_active
    ON custom_field_values (entity_key, record_id, definition_id)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ui_entity_configs_entity_key_active
    ON ui_entity_configs (entity_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ui_field_configs_entity_field_active
    ON ui_field_configs (entity_key, field_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_api_endpoint_registry_endpoint_key_active
    ON api_endpoint_registry (endpoint_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_report_definitions_key_active
    ON report_definitions (report_key)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_record_tags_entity_record_tag_active
    ON record_tags (entity_key, record_id, lower(tag))
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_task_dependencies_pair_active
    ON task_dependencies (task_id, depends_on_task_id)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_task_watchers_pair_active
    ON task_watchers (task_id, user_id)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_document_versions_document_version_active
    ON document_versions (document_id, version_no)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_project_stakeholders_unique_active
    ON project_stakeholders (project_id, contact_id, role_key)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_accounts_owner_active ON accounts (owner_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_account_active ON contacts (account_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_leads_account_stage_active ON leads (account_id, stage) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_leads_owner_status_active ON leads (owner_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_projects_account_status_active ON projects (account_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_project_status_active ON tasks (project_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_documents_entity_active ON documents (entity_id, entity_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_document_versions_document_active ON document_versions (document_id, version_no DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_saved_filters_entity_owner_active ON saved_filters (entity_key, owner_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_custom_field_values_entity_record_active ON custom_field_values (entity_key, record_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lookup_values_set_enabled_active ON lookup_values (set_id, is_enabled, sort_order) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_leads_search_trgm
    ON leads
    USING gin ((COALESCE(title, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(email, '') || ' ' || COALESCE(phone, '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_contacts_search_trgm
    ON contacts
    USING gin ((COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' || COALESCE(email, '') || ' ' || COALESCE(company_name, '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_projects_search_trgm
    ON projects
    USING gin ((COALESCE(title, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(location, '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_documents_search_trgm
    ON documents
    USING gin ((COALESCE(title, '') || ' ' || COALESCE(file_name, '') || ' ' || COALESCE(category, '')) gin_trgm_ops);

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN
        SELECT table_name
        FROM information_schema.columns
        WHERE table_schema = 'crm'
          AND column_name = 'updated_at'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at_%I ON crm.%I', t.table_name, t.table_name);
        EXECUTE format(
            'CREATE TRIGGER trg_set_updated_at_%I BEFORE UPDATE ON crm.%I FOR EACH ROW EXECUTE FUNCTION crm.fn_set_updated_at()',
            t.table_name,
            t.table_name
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
            'accounts',
            'contact_addresses',
            'contacts',
            'leads',
            'projects',
            'project_stakeholders',
            'tasks',
            'task_dependencies',
            'task_watchers',
            'documents',
            'document_versions',
            'quotations',
            'expenses',
            'communications',
            'workflow_rules',
            'lookup_sets',
            'lookup_values',
            'custom_field_definitions',
            'custom_field_values',
            'saved_filters',
            'record_tags',
            'api_endpoint_registry',
            'report_definitions'
        ]
        LOOP
            IF EXISTS (
                SELECT 1
                FROM information_schema.tables
                WHERE table_schema = 'crm'
                  AND table_name = t
            ) THEN
                EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%I ON crm.%I', t, t);
                EXECUTE format(
                    'CREATE TRIGGER trg_audit_%I AFTER INSERT OR UPDATE OR DELETE ON crm.%I FOR EACH ROW EXECUTE FUNCTION crm.fn_audit_operation()',
                    t,
                    t
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;
