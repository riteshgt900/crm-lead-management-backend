SET search_path = crm, public;
-- V014: Projects
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_number VARCHAR(20) UNIQUE NOT NULL, -- PROJ-YYYY-0001
    title VARCHAR(255) NOT NULL,
    description TEXT,
    lead_id UUID REFERENCES leads(id),
    contact_id UUID REFERENCES contacts(id),
    status project_status DEFAULT 'planning',
    estimated_value NUMERIC(15, 2),
    actual_cost NUMERIC(15, 2) DEFAULT 0,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    project_manager_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

