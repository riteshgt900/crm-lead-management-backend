SET search_path = crm, public;

-- V040: Contacts Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_contact_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_id UUID;
    v_search TEXT := v_data->>'q';
BEGIN
    -- Set session user for audit
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_contacts' THEN
            SELECT jsonb_agg(c) INTO v_res FROM (
                SELECT * FROM contacts
                WHERE deleted_at IS NULL
                  AND (v_search IS NULL OR 
                       (first_name || ' ' || last_name) ILIKE '%' || fn_escape_like(v_search) || '%' OR
                       email ILIKE '%' || fn_escape_like(v_search) || '%')
                ORDER BY created_at DESC
                LIMIT COALESCE((v_data->>'limit')::INT, 50)
                OFFSET COALESCE((v_data->>'offset')::INT, 0)
            ) c;
            RETURN jsonb_build_object('rid', 's-contacts-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'create_contact' THEN
            INSERT INTO contacts (
                first_name, last_name, email, phone, company_name, job_title
            ) VALUES (
                v_data->>'firstName',
                v_data->>'lastName',
                v_data->>'email',
                v_data->>'phone',
                v_data->>'companyName',
                v_data->>'jobTitle'
            ) RETURNING id INTO v_id;
            RETURN jsonb_build_object('rid', 's-contact-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_id));

        WHEN 'get_contact' THEN
            v_id := (v_data->>'id')::UUID;
            SELECT row_to_json(c) INTO v_res FROM (
                SELECT 
                    c.*,
                    (SELECT jsonb_agg(l) FROM leads l WHERE l.contact_id = c.id AND l.deleted_at IS NULL) as leads,
                    (SELECT jsonb_agg(p) FROM projects p WHERE p.contact_id = c.id AND p.deleted_at IS NULL) as projects
                FROM contacts c
                WHERE c.id = v_id AND c.deleted_at IS NULL
            ) c;
            
            IF v_res IS NULL THEN RETURN fn_error_envelope('e-contact-not-found', 404, 'Contact not found'); END IF;
            RETURN jsonb_build_object('rid', 's-contact-loaded', 'statusCode', 200, 'data', v_res);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
