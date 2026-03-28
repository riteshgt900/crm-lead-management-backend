SET search_path = crm, public;

-- V038: Leads Dispatcher Functional Implementation (FIXED)
CREATE OR REPLACE FUNCTION fn_lead_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_lead RECORD;
    v_new_lead_id UUID;
    v_new_project_id UUID;
    v_search TEXT := v_data->>'q';
    v_status TEXT := v_data->>'status';
BEGIN
    -- Set session user for audit trigger
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_leads' THEN
            SELECT jsonb_agg(l) INTO v_res FROM (
                SELECT 
                    l.*,
                    u.full_name as assigned_to_name,
                    c.first_name || ' ' || c.last_name as contact_name
                FROM leads l
                LEFT JOIN users u ON l.assigned_to = u.id
                LEFT JOIN contacts c ON l.contact_id = c.id
                WHERE l.deleted_at IS NULL
                  AND (v_search IS NULL OR l.title ILIKE '%' || fn_escape_like(v_search) || '%')
                  AND (v_status IS NULL OR l.status::TEXT = v_status)
                  -- RBAC: Non-admins see own or unassigned
                  AND (
                    (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                    OR l.assigned_to = v_req_by 
                    OR l.assigned_to IS NULL
                  )
                ORDER BY l.created_at DESC
                LIMIT COALESCE((v_data->>'limit')::INT, 50)
                OFFSET COALESCE((v_data->>'offset')::INT, 0)
            ) l;
            RETURN jsonb_build_object('rid', 's-leads-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'create_lead' THEN
            INSERT INTO leads (
                lead_number, title, description, contact_id, 
                estimated_value, assigned_to, source, status
            ) VALUES (
                generate_lead_number(),
                v_data->>'title',
                v_data->>'description',
                (v_data->>'contactId')::UUID,
                (v_data->>'estimatedValue')::NUMERIC,
                (v_data->>'assignedTo')::UUID,
                COALESCE((v_data->>'source')::lead_source, 'other'),
                COALESCE((v_data->>'status')::lead_status, 'new')
            ) RETURNING id INTO v_new_lead_id;

            -- Trigger workflow
            PERFORM fn_trigger_workflow('lead_created', v_new_lead_id);

            RETURN jsonb_build_object('rid', 's-lead-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_new_lead_id));

        WHEN 'update_status' THEN
            SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID;
            IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

            UPDATE leads SET 
                status = (v_data->>'status')::lead_status,
                updated_at = NOW()
            WHERE id = v_lead.id;

            INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, reason)
            VALUES (v_lead.id, v_lead.status, (v_data->>'status')::lead_status, v_req_by, v_data->>'reason');

            -- Trigger workflow
            PERFORM fn_trigger_workflow('status_changed', v_lead.id);

            RETURN jsonb_build_object('rid', 's-lead-status-updated', 'statusCode', 200, 'data', null);

        WHEN 'convert_lead' THEN
            SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID;
            IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

            -- Arch Decision: Require Contact before conversion
            IF v_lead.contact_id IS NULL THEN
                RETURN fn_error_envelope('e-contact-required', 400, 'A contact must be assigned before a lead can be converted to a project.');
            END IF;

            -- 1. Create Project
            INSERT INTO projects (
                project_number, title, description, lead_id, contact_id, 
                estimated_value, project_manager_id
            ) VALUES (
                generate_project_number(),
                'Project for: ' || v_lead.title,
                v_lead.description,
                v_lead.id,
                v_lead.contact_id,
                v_lead.estimated_value,
                v_lead.assigned_to
            ) RETURNING id INTO v_new_project_id;

            -- 2. Update Lead
            UPDATE leads SET status = 'converted', converted_at = NOW() WHERE id = v_lead.id;

            -- 3. Trigger workflow
            PERFORM fn_trigger_workflow('lead_converted', v_lead.id);

            RETURN jsonb_build_object('rid', 's-lead-converted', 'statusCode', 200, 'data', jsonb_build_object('projectId', v_new_project_id));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
