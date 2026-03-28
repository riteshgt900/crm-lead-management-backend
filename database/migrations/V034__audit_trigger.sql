SET search_path = crm, public;
-- V034: Audit Trigger Function

CREATE OR REPLACE FUNCTION fn_audit_operation()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB := NULL;
    v_new_data JSONB := NULL;
    v_user_id UUID;
BEGIN
    -- Try to get user from local session variable (set by dispatcher)
    BEGIN
        v_user_id := current_setting('crm.current_user_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    IF (TG_OP = 'UPDATE') THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := to_jsonb(NEW);
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := to_jsonb(OLD);
    END IF;

    INSERT INTO audit_logs (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, COALESCE(NEW.id, OLD.id), TG_OP, v_old_data, v_new_data, v_user_id);

    RETURN COALESCE(NEW, OLD);
END; $$ LANGUAGE plpgsql;

-- Triggers for tables to be audited (Selection)
-- Example: CREATE TRIGGER trg_audit_leads AFTER INSERT OR UPDATE OR DELETE ON leads FOR EACH ROW EXECUTE FUNCTION fn_audit_operation();

