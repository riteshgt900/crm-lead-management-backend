SET search_path = crm, public;

-- V061: Workflow Trigger Helper
CREATE OR REPLACE FUNCTION fn_trigger_workflow(
    p_event TEXT,
    p_entity_id UUID,
    p_payload JSONB DEFAULT '{}'
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_rule RECORD;
BEGIN
    -- For each active rule matching the event title or trigger_event
    FOR v_rule IN SELECT * FROM workflow_rules WHERE trigger_event = p_event AND is_active = TRUE AND deleted_at IS NULL
    LOOP
        -- Queue the execution
        INSERT INTO workflow_executions (rule_id, entity_id, status)
        VALUES (v_rule.id, p_entity_id, 'pending');
        
        RAISE NOTICE 'Workflow triggered: % (Event: %) for entity %', v_rule.name, p_event, p_entity_id;
    END LOOP;
END; $$;
