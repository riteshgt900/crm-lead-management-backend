SET search_path = crm, public;
-- V035: fn_error_envelope helper

CREATE OR REPLACE FUNCTION fn_error_envelope(p_rid TEXT, p_status INT, p_msg TEXT, p_errors JSONB DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql AS $$
BEGIN
    RETURN jsonb_build_object(
        'rid', p_rid,
        'statusCode', p_status,
        'message', p_msg,
        'errors', p_errors,
        'data', NULL,
        'meta', jsonb_build_object('timestamp', NOW())
    );
END; $$;

