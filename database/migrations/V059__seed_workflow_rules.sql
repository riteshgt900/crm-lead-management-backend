SET search_path = crm, public;
-- V059: Seed Workflow Rules
INSERT INTO workflow_rules (name, trigger_event, actions)
VALUES 
('Auto-Project on Convert', 'lead_converted', '[{"action": "create_project"}]'::jsonb),
('Overdue Task Alert', 'task_overdue', '[{"action": "send_notification"}]'::jsonb)
ON CONFLICT DO NOTHING;

