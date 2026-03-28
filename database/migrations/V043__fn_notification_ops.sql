SET search_path = crm, public;

-- V043: Notifications Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_notification_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'list_notifications' THEN
            SELECT jsonb_agg(n) INTO v_res FROM (
                SELECT * FROM notifications
                WHERE user_id = v_req_by
                ORDER BY created_at DESC
                LIMIT 50
            ) n;
            RETURN jsonb_build_object('rid', 's-notifications-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'mark_as_read' THEN
            UPDATE notifications SET is_read = TRUE 
            WHERE user_id = v_req_by AND ((v_data->>'id') IS NULL OR id = (v_data->>'id')::UUID);
            RETURN jsonb_build_object('rid', 's-notifications-read', 'statusCode', 200, 'data', null);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
