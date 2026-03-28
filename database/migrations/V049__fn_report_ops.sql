SET search_path = crm, public;
-- V049: Reports Dispatcher
CREATE OR REPLACE FUNCTION fn_report_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'get_summary' THEN
            RETURN jsonb_build_object('rid', 's-report-summary', 'statusCode', 200, 'data', '{}');
        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;

