SET search_path = crm, public;
-- V010: Leads
CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_number VARCHAR(20) UNIQUE NOT NULL, -- e.g., LEAD-2026-0001
    title VARCHAR(255) NOT NULL,
    description TEXT,
    contact_id UUID REFERENCES contacts(id),
    status lead_status DEFAULT 'new',
    source lead_source DEFAULT 'other',
    estimated_value NUMERIC(15, 2),
    assigned_to UUID REFERENCES users(id),
    follow_up_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ,
    lost_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

