SET search_path = crm, public;
-- V086__client_portal_schema.sql

-- Portal Users
CREATE TABLE IF NOT EXISTS portal_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portal Project Access
CREATE TABLE IF NOT EXISTS portal_project_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portal_user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    can_view BOOLEAN DEFAULT true,
    can_comment BOOLEAN DEFAULT false,
    can_upload BOOLEAN DEFAULT false,
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(portal_user_id, project_id)
);

-- Portal Sessions
CREATE TABLE IF NOT EXISTS portal_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portal_user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add is_external flag to Notes/Comments and Documents
DO $$
BEGIN
    BEGIN
        ALTER TABLE notes ADD COLUMN is_external BOOLEAN DEFAULT false;
    EXCEPTION
        WHEN undefined_table THEN
            RAISE NOTICE 'table notes does not exist, skipping';
        WHEN duplicate_column THEN
            RAISE NOTICE 'column is_external already exists in notes';
    END;

    BEGIN
        ALTER TABLE documents ADD COLUMN is_external BOOLEAN DEFAULT false;
    EXCEPTION
        WHEN duplicate_column THEN
            RAISE NOTICE 'column is_external already exists in documents';
    END;
END $$;
