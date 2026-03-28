SET search_path = crm, public;

-- V051: Search Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_search_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_search TEXT := v_data->>'q';
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'global_search' THEN
            IF v_search IS NULL OR length(v_search) < 2 THEN 
                RETURN jsonb_build_object('rid', 's-search-empty', 'statusCode', 200, 'data', '[]');
            END IF;

            SELECT jsonb_agg(r) INTO v_res FROM (
                -- Leads
                SELECT id, title as label, 'Lead' as type, created_at FROM leads 
                WHERE deleted_at IS NULL AND title ILIKE '%' || fn_escape_like(v_search) || '%'
                UNION ALL
                -- Contacts
                SELECT id, first_name || ' ' || last_name as label, 'Contact' as type, created_at FROM contacts 
                WHERE deleted_at IS NULL AND (first_name || ' ' || last_name) ILIKE '%' || fn_escape_like(v_search) || '%'
                UNION ALL
                -- Projects
                SELECT id, title as label, 'Project' as type, created_at FROM projects 
                WHERE deleted_at IS NULL AND title ILIKE '%' || fn_escape_like(v_search) || '%'
                ORDER BY created_at DESC
                LIMIT 20
            ) r;

            RETURN jsonb_build_object('rid', 's-search-results', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
