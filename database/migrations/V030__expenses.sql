SET search_path = crm, public;
-- V030: Expenses
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id),
    category expense_category NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    description TEXT,
    expense_date DATE DEFAULT CURRENT_DATE,
    logged_by UUID REFERENCES users(id),
    receipt_url TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, reimbursed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

