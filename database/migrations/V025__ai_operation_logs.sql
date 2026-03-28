SET search_path = crm, public;
-- V025: AI Operation Logs
CREATE TABLE IF NOT EXISTS ai_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID,
    user_prompt TEXT,
    files_modified TEXT[],
    summary TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- pending, success, fail
    error_details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

