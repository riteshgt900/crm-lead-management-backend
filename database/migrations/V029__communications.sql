SET search_path = crm, public;
-- V029: Communications
CREATE TABLE IF NOT EXISTS communications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_name VARCHAR(50), -- leads, projects, etc.
    entity_id UUID,
    contact_id UUID REFERENCES contacts(id),
    type communication_type NOT NULL,
    subject VARCHAR(255),
    content TEXT,
    direction VARCHAR(10) DEFAULT 'outbound', -- inbound, outbound
    performed_by UUID REFERENCES users(id),
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

