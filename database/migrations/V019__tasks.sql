SET search_path = crm, public;
-- V019: Tasks
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_number VARCHAR(20) UNIQUE NOT NULL, -- TASK-YYYY-0001
    project_id UUID REFERENCES projects(id),
    phase_id UUID REFERENCES project_phases(id),
    milestone_id UUID REFERENCES project_milestones(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status task_status DEFAULT 'todo',
    priority task_priority DEFAULT 'medium',
    assigned_to UUID REFERENCES users(id),
    reporter_id UUID REFERENCES users(id),
    due_date TIMESTAMPTZ,
    start_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    estimated_hours NUMERIC(8, 2),
    actual_hours NUMERIC(8, 2) DEFAULT 0,
    parent_task_id UUID REFERENCES tasks(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

