SET search_path = crm, public;

-- V049: Real Reports Dispatcher Implementation
CREATE OR REPLACE FUNCTION fn_report_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_res JSONB;
    v_type TEXT;
BEGIN
    CASE v_op
        WHEN 'generate_report' THEN
            -- Returns a summary of counts for dashboard/kpi
            SELECT jsonb_build_object(
                'leads', (SELECT count(*) FROM leads WHERE deleted_at IS NULL),
                'projects', (SELECT count(*) FROM projects WHERE deleted_at IS NULL),
                'tasks_overdue', (SELECT count(*) FROM tasks WHERE deleted_at IS NULL AND due_date < NOW() AND status != 'completed')
            ) INTO v_res;
            
            RETURN jsonb_build_object('rid', 's-report-generated', 'statusCode', 200, 'data', v_res);

        WHEN 'export_csv' THEN
            v_type := v_data->>'type';
            
            CASE v_type
                WHEN 'leads' THEN
                    SELECT jsonb_agg(l) INTO v_res FROM (
                        SELECT title, status, source, estimated_value, created_at 
                        FROM leads WHERE deleted_at IS NULL ORDER BY created_at DESC
                    ) l;
                WHEN 'projects' THEN
                    SELECT jsonb_agg(p) INTO v_res FROM (
                        SELECT title, status, estimated_value, created_at 
                        FROM projects WHERE deleted_at IS NULL ORDER BY created_at DESC
                    ) p;
                ELSE
                    RETURN fn_error_envelope('e-invalid-type', 400, 'Invalid report type');
            END CASE;

            RETURN jsonb_build_object('rid', 's-report-exported', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
