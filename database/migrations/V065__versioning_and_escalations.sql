SET search_path = crm, public;

-- V065: Document Versioning & Task Escalations (Phase 13 Remediation)

-- 1. Document Version Control
-- Allows per-file history as required by the Scope.docx.
ALTER TABLE documents ADD COLUMN IF NOT EXISTS version_number INT DEFAULT 1;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS parent_document_id UUID REFERENCES documents(id);

-- 2. Task Template Indicator
-- Allows cloning tasks from Project Templates.
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_template BOOLEAN DEFAULT FALSE;

-- 3. Escalations Cache / Triggers
-- Function to identify overdue tasks for the Escalation Flow.
CREATE OR REPLACE FUNCTION fn_escalate_overdue_tasks()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_task_count INT;
BEGIN
    -- Identify tasks that are past their due_date and still in non-completed status
    WITH overdue AS (
        SELECT id, title, project_id, assigned_to
        FROM tasks
        WHERE due_date < NOW()
          AND status NOT IN ('completed', 'cancelled')
          AND deleted_at IS NULL
    )
    -- This would normally trigger notifications or alerts.
    -- For now, we return the count to signal the automation engine.
    SELECT count(*) INTO v_task_count FROM overdue;
    
    RETURN jsonb_build_object('rid', 's-escalations-processed', 'count', v_task_count);
END; $$;
