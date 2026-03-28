SET search_path = crm, public;
-- V060: Seed Admin User
INSERT INTO roles (name, slug, priority) 
VALUES ('Super Admin', 'admin', 100) 
ON CONFLICT (slug) DO NOTHING;

INSERT INTO users (email, password_hash, full_name, role_id)
SELECT 'admin@crm.local', crypt('Admin@123', gen_salt('bf')), 'System Admin', id
FROM roles WHERE slug = 'admin'
ON CONFLICT (email) WHERE deleted_at IS NULL DO NOTHING;

-- Seed default permissions
INSERT INTO permissions (module, action, slug)
VALUES 
('dashboard', 'view', 'dashboard:view'),
('leads', 'manage', 'leads:manage'),
('projects', 'manage', 'projects:manage'),
('tasks', 'manage', 'tasks:manage'),
('contacts', 'manage', 'contacts:manage'),
('documents', 'manage', 'documents:manage'),
('quotations', 'manage', 'quotations:manage'),
('expenses', 'manage', 'expenses:manage'),
('reports', 'manage', 'reports:manage'),
('settings', 'manage', 'settings:manage')
ON CONFLICT (slug) DO NOTHING;

-- Map permissions to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.slug = 'admin'
ON CONFLICT DO NOTHING;

