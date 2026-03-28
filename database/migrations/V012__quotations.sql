SET search_path = crm, public;
-- V012: Quotations
CREATE TABLE IF NOT EXISTS quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_number VARCHAR(20) UNIQUE NOT NULL, -- QUOT-YYYY-0001
    lead_id UUID REFERENCES leads(id),
    contact_id UUID REFERENCES contacts(id),
    status quotation_status DEFAULT 'draft',
    total_amount NUMERIC(15, 2) DEFAULT 0,
    valid_until TIMESTAMPTZ,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

