SET search_path = crm, public;
-- V027: Workflow Executions
CREATE TABLE IF NOT EXISTS workflow_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES workflow_rules(id),
    entity_id UUID NOT NULL, -- The ID of the record that triggered the rule
    status VARCHAR(20) DEFAULT ' pending', -- pending, completed, failed
    result JSONB,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

