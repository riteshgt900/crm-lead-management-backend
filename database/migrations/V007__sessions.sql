SET search_path = crm, public;

-- V007: Sessions Table - Optimized for lookup
DROP TABLE IF EXISTS sessions CASCADE;
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    token UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE, -- Faster for lookup in skeleton
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for lookup
CREATE INDEX idx_sessions_token ON sessions(token);
