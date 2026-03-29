SET search_path = crm, public;

-- V052: Audit Dispatcher Functional Implementation (Physical Schema Mapping)
CREATE OR REPLACE FUNCTION fn_audit_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'list_logs' THEN
            SELECT jsonb_agg(l) INTO v_res FROM (
                SELECT 
                    al.*,
                    u.full_name as user_name
                FROM audit_logs al
                LEFT JOIN users u ON al.changed_by = u.id
                WHERE ((v_data->>'entityType') IS NULL OR al.table_name = (v_data->>'entityType'))
                  AND ((v_data->>'entityId') IS NULL OR al.record_id = (v_data->>'entityId')::UUID)
                ORDER BY al.changed_at DESC
                LIMIT COALESCE((v_data->>'limit')::INT, 50)
            ) l;
            RETURN jsonb_build_object('rid', 's-audit-logs-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));
        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
