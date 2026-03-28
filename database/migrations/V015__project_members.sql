SET search_path = crm, public;
-- V015: Project Members
CREATE TABLE IF NOT EXISTS project_members (
    project_id UUID REFERENCES projects(id),
    user_id UUID REFERENCES users(id),
    role_description VARCHAR(100),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (project_id, user_id)
);

