SET search_path = crm, public;

-- V050: Dashboard Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_dashboard_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'get_stats' THEN
            SELECT jsonb_build_object(
                'leads', (SELECT jsonb_object_agg(status, count) FROM (SELECT status, count(*) as count FROM leads WHERE deleted_at IS NULL GROUP BY status) s),
                'projects', (SELECT count(*) FROM projects WHERE deleted_at IS NULL AND status = 'active'),
                'revenue', (SELECT COALESCE(SUM(total_amount), 0) FROM quotations WHERE status = 'accepted' AND deleted_at IS NULL),
                'tasks_pending', (SELECT count(*) FROM tasks WHERE status IN ('todo', 'in_progress') AND deleted_at IS NULL)
            ) INTO v_res;
            
            RETURN jsonb_build_object('rid', 's-dashboard-stats', 'statusCode', 200, 'data', v_res);
            
        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
