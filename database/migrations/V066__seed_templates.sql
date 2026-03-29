SET search_path = crm, public;

-- V066: Seed Project Templates for E2E and Initial Setup
INSERT INTO project_templates (name, description, category)
VALUES 
    ('Standard Villa Construction', 'Complete lifecycle for a standard villa: Design, Permitting, Construction, Handover.', 'Construction'),
    ('Commercial Fit-out', 'Standard workflow for office or shop interior fit-outs.', 'Commercial')
ON CONFLICT (name) DO NOTHING;

-- Seed Phases for the Standard Villa
WITH villa AS (SELECT id FROM project_templates WHERE name = 'Standard Villa Construction')
INSERT INTO project_phases (template_id, name, description, sort_order, status)
SELECT villa.id, 'Design & Architectural', 'Initial planning and layout approval', 1, 'planning'::project_status FROM villa
UNION ALL
SELECT villa.id, 'Tendering & Procurement', 'Selecting vendors and materials', 2, 'planning'::project_status FROM villa
UNION ALL
SELECT villa.id, 'Groundwork & RCC', 'Excavation and foundation', 3, 'planning'::project_status FROM villa;
