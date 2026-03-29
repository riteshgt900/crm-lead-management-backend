SET search_path = crm, public;

-- V069: Missing Ops & Safe UUID Caster Overrides
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
    
    v_page INT := COALESCE((v_data->>'page')::INT, 1);
    v_limit INT := COALESCE((v_data->>'limit')::INT, 50);
    v_offset INT := (v_page - 1) * v_limit;
    v_total_count INT := 0;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_leads' THEN
            SELECT COALESCE(jsonb_agg(sub.r), '[]'::jsonb), COALESCE(MAX(sub.tc), 0) INTO v_res, v_total_count
            FROM (
                SELECT 
                    row_to_json(l) as r,
                    COUNT(*) OVER() as tc
                FROM (
                    SELECT 
                        ld.*,
                        u.full_name as assigned_to_name,
                        c.first_name || ' ' || c.last_name as contact_name
                    FROM leads ld
                    LEFT JOIN users u ON ld.assigned_to = u.id
                    LEFT JOIN contacts c ON ld.contact_id = c.id
                    WHERE ld.deleted_at IS NULL
                      AND (v_search IS NULL OR ld.title ILIKE '%' || fn_escape_like(v_search) || '%')
                      AND (v_status IS NULL OR ld.status::TEXT = v_status)
                      AND (
                        (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                        OR ld.assigned_to = v_req_by 
                        OR ld.assigned_to IS NULL
                      )
                    ORDER BY ld.created_at DESC
                    LIMIT v_limit OFFSET v_offset
                ) l
            ) sub;
            RETURN jsonb_build_object(
                'rid', 's-leads-listed', 
                'statusCode', 200, 
                'data', v_res,
                'meta', jsonb_build_object(
                    'total', v_total_count,
                    'page', v_page,
                    'limit', v_limit,
                    'totalPages', CEIL(v_total_count::NUMERIC / v_limit)
                )
            );

        WHEN 'get_lead' THEN
            SELECT row_to_json(ld) INTO v_res FROM (
                SELECT 
                    l.*,
                    u.full_name as assigned_to_name,
                    c.first_name || ' ' || c.last_name as contact_name
                FROM leads l
                LEFT JOIN users u ON l.assigned_to = u.id
                LEFT JOIN contacts c ON l.contact_id = c.id
                WHERE l.id = NULLIF(v_data->>'id', '')::UUID AND l.deleted_at IS NULL
            ) ld;
            IF v_res IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;
            RETURN jsonb_build_object('rid', 's-lead-retrieved', 'statusCode', 200, 'data', v_res);

        WHEN 'create_lead' THEN
            INSERT INTO leads (
                lead_number, title, description, contact_id, 
                estimated_value, assigned_to, source, status
            ) VALUES (
                generate_lead_number(),
                v_data->>'title',
                NULLIF(v_data->>'description', ''),
                NULLIF(v_data->>'contactId', '')::UUID,
                NULLIF(v_data->>'estimatedValue', '')::NUMERIC,
                NULLIF(v_data->>'assignedTo', '')::UUID,
                COALESCE(NULLIF(v_data->>'source', '')::lead_source, 'other'),
                COALESCE(NULLIF(v_data->>'status', '')::lead_status, 'new')
            ) RETURNING id INTO v_new_lead_id;
            PERFORM fn_trigger_workflow('lead_created', v_new_lead_id);
            RETURN jsonb_build_object('rid', 's-lead-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_new_lead_id));
        
        WHEN 'update_lead' THEN
            SELECT * INTO v_lead FROM leads WHERE id = NULLIF(v_data->>'id', '')::UUID;
            IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

            UPDATE leads SET 
                title = COALESCE(NULLIF(v_data->>'title', ''), title),
                description = COALESCE(NULLIF(v_data->>'description', ''), description),
                contact_id = COALESCE(NULLIF(v_data->>'contactId', '')::UUID, contact_id),
                estimated_value = COALESCE(NULLIF(v_data->>'estimatedValue', '')::NUMERIC, estimated_value),
                assigned_to = COALESCE(NULLIF(v_data->>'assignedTo', '')::UUID, assigned_to),
                source = COALESCE(NULLIF(v_data->>'source', '')::lead_source, source),
                status = COALESCE(NULLIF(v_data->>'status', '')::lead_status, status),
                updated_at = NOW()
            WHERE id = v_lead.id;
            
            INSERT INTO audit_logs (id, table_name, record_id, action, changed_by, changes)
            VALUES (gen_random_uuid(), 'leads', v_lead.id, 'UPDATE_LEAD', v_req_by, v_data);
            RETURN jsonb_build_object('rid', 's-lead-updated', 'statusCode', 200, 'data', null);

        WHEN 'update_status' THEN
            SELECT * INTO v_lead FROM leads WHERE id = NULLIF(v_data->>'id', '')::UUID;
            IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;
            UPDATE leads SET status = NULLIF(v_data->>'status', '')::lead_status, updated_at = NOW() WHERE id = v_lead.id;
            INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, reason)
            VALUES (v_lead.id, v_lead.status, NULLIF(v_data->>'status', '')::lead_status, v_req_by, v_data->>'reason');
            PERFORM fn_trigger_workflow('status_changed', v_lead.id);
            RETURN jsonb_build_object('rid', 's-lead-status-updated', 'statusCode', 200, 'data', null);

        WHEN 'bulk_update' THEN
            UPDATE leads SET 
                status = COALESCE(NULLIF(v_data->>'status', '')::lead_status, status),
                assigned_to = COALESCE(NULLIF(v_data->>'assignedTo', '')::UUID, assigned_to),
                updated_at = NOW()
            WHERE id IN (
                SELECT (value)::UUID 
                FROM jsonb_array_elements_text(v_data->'ids')
            );
            RETURN jsonb_build_object('rid', 's-leads-bulk-updated', 'statusCode', 200, 'data', null);

        WHEN 'convert_lead' THEN
            SELECT * INTO v_lead FROM leads WHERE id = NULLIF(v_data->>'id', '')::UUID;
            IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;
            IF v_lead.contact_id IS NULL THEN
                RETURN fn_error_envelope('e-contact-required', 400, 'A contact must be assigned before a lead can be converted to a project.');
            END IF;

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

            IF NULLIF(v_data->>'templateId', '') IS NOT NULL THEN
                INSERT INTO project_phases (project_id, name, description, sort_order, status)
                SELECT v_new_project_id, name, description, sort_order, 'planning'
                FROM project_phases
                WHERE template_id = NULLIF(v_data->>'templateId', '')::UUID AND deleted_at IS NULL;

                INSERT INTO tasks (project_id, title, description, status, priority, is_template)
                SELECT v_new_project_id, title, description, 'todo', priority, FALSE
                FROM tasks
                WHERE is_template = TRUE AND project_id IS NULL
                  AND NULLIF(v_data->>'templateId', '')::UUID IS NOT NULL;
            END IF;

            UPDATE leads SET status = 'converted', converted_at = NOW() WHERE id = v_lead.id;
            PERFORM fn_trigger_workflow('lead_converted', v_lead.id);
            RETURN jsonb_build_object('rid', 's-lead-converted', 'statusCode', 200, 'data', jsonb_build_object('projectId', v_new_project_id));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;


CREATE OR REPLACE FUNCTION fn_task_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_new_task_id UUID;
    v_search TEXT := v_data->>'q';
    v_status TEXT := v_data->>'status';
    v_project_id UUID := NULLIF(v_data->>'projectId', '')::UUID;
    v_page INT := COALESCE((v_data->>'page')::INT, 1);
    v_limit INT := COALESCE((v_data->>'limit')::INT, 50);
    v_offset INT := (v_page - 1) * v_limit;
    v_total_count INT := 0;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_tasks' THEN
            SELECT COALESCE(jsonb_agg(sub.r), '[]'::jsonb), COALESCE(MAX(sub.tc), 0) INTO v_res, v_total_count
            FROM (
                SELECT 
                    row_to_json(t) as r,
                    COUNT(*) OVER() as tc
                FROM (
                    SELECT 
                        tk.*,
                        u.full_name as assigned_to_name,
                        p.title as project_name
                    FROM tasks tk
                    LEFT JOIN users u ON tk.assigned_to = u.id
                    LEFT JOIN projects p ON tk.project_id = p.id
                    WHERE tk.deleted_at IS NULL AND tk.is_template = FALSE
                      AND (v_search IS NULL OR tk.title ILIKE '%' || fn_escape_like(v_search) || '%')
                      AND (v_status IS NULL OR tk.status::TEXT = v_status)
                      AND (v_project_id IS NULL OR tk.project_id = v_project_id)
                      AND (
                        (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                        OR tk.assigned_to = v_req_by 
                        OR p.project_manager_id = v_req_by
                        OR tk.assigned_to IS NULL
                      )
                    ORDER BY tk.created_at DESC
                    LIMIT v_limit OFFSET v_offset
                ) t
            ) sub;
            RETURN jsonb_build_object(
                'rid', 's-tasks-listed', 
                'statusCode', 200, 
                'data', v_res,
                'meta', jsonb_build_object('total', v_total_count, 'page', v_page, 'limit', v_limit, 'totalPages', CEIL(v_total_count::NUMERIC / v_limit))
            );

        WHEN 'create_task' THEN
            INSERT INTO tasks (
                project_id, title, description, assigned_to, 
                due_date, priority, status
            ) VALUES (
                NULLIF(v_data->>'projectId', '')::UUID,
                v_data->>'title',
                NULLIF(v_data->>'description', ''),
                NULLIF(v_data->>'assignedTo', '')::UUID,
                NULLIF(v_data->>'dueDate', '')::TIMESTAMPTZ,
                COALESCE(NULLIF(v_data->>'priority', '')::task_priority, 'medium'),
                COALESCE(NULLIF(v_data->>'status', '')::task_status, 'todo')
            ) RETURNING id INTO v_new_task_id;
            PERFORM fn_trigger_workflow('task_created', v_new_task_id);
            RETURN jsonb_build_object('rid', 's-task-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_new_task_id));

        WHEN 'update_status' THEN
            UPDATE tasks SET 
                status = NULLIF(v_data->>'status', '')::task_status,
                updated_at = NOW()
            WHERE id = NULLIF(v_data->>'id', '')::UUID;
            PERFORM fn_trigger_workflow('task_status_changed', NULLIF(v_data->>'id', '')::UUID);
            RETURN jsonb_build_object('rid', 's-task-status-updated', 'statusCode', 200, 'data', null);

        WHEN 'update_task' THEN
            UPDATE tasks SET 
                title = COALESCE(NULLIF(v_data->>'title', ''), title),
                description = COALESCE(NULLIF(v_data->>'description', ''), description),
                assigned_to = COALESCE(NULLIF(v_data->>'assignedTo', '')::UUID, assigned_to),
                priority = COALESCE(NULLIF(v_data->>'priority', '')::task_priority, priority),
                status = COALESCE(NULLIF(v_data->>'status', '')::task_status, status),
                due_date = COALESCE(NULLIF(v_data->>'dueDate', '')::TIMESTAMPTZ, due_date),
                updated_at = NOW()
            WHERE id = NULLIF(v_data->>'id', '')::UUID;
            PERFORM fn_trigger_workflow('task_updated', NULLIF(v_data->>'id', '')::UUID);
            RETURN jsonb_build_object('rid', 's-task-updated', 'statusCode', 200, 'data', null);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;


CREATE OR REPLACE FUNCTION fn_project_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_new_project_id UUID;
    v_search TEXT := v_data->>'q';
    v_status TEXT := v_data->>'status';
    
    v_page INT := COALESCE((v_data->>'page')::INT, 1);
    v_limit INT := COALESCE((v_data->>'limit')::INT, 50);
    v_offset INT := (v_page - 1) * v_limit;
    v_total_count INT := 0;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_projects' THEN
            SELECT COALESCE(jsonb_agg(sub.r), '[]'::jsonb), COALESCE(MAX(sub.tc), 0) INTO v_res, v_total_count
            FROM (
                SELECT 
                    row_to_json(pr) as r,
                    COUNT(*) OVER() as tc
                FROM (
                    SELECT 
                        p.*,
                        u.full_name as project_manager_name,
                        c.first_name || ' ' || c.last_name as client_name
                    FROM projects p
                    LEFT JOIN users u ON p.project_manager_id = u.id
                    LEFT JOIN contacts c ON p.contact_id = c.id
                    WHERE p.deleted_at IS NULL
                      AND (v_search IS NULL OR p.title ILIKE '%' || fn_escape_like(v_search) || '%')
                      AND (v_status IS NULL OR p.status::TEXT = v_status)
                      AND (
                        (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                        OR p.project_manager_id = v_req_by 
                        OR EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = v_req_by)
                      )
                    ORDER BY p.created_at DESC
                    LIMIT v_limit OFFSET v_offset
                ) pr
            ) sub;
            RETURN jsonb_build_object(
                'rid', 's-projects-listed', 
                'statusCode', 200, 
                'data', v_res,
                'meta', jsonb_build_object('total', v_total_count, 'page', v_page, 'limit', v_limit, 'totalPages', CEIL(v_total_count::NUMERIC / v_limit))
            );

        WHEN 'create_project' THEN
            INSERT INTO projects (
                project_number, title, description,
                status, lead_id, contact_id, 
                estimated_value, project_manager_id
            ) VALUES (
                generate_project_number(),
                v_data->>'title',
                NULLIF(v_data->>'description', ''),
                COALESCE(NULLIF(v_data->>'status', '')::project_status, 'draft'),
                NULLIF(v_data->>'leadId', '')::UUID,
                NULLIF(v_data->>'contactId', '')::UUID,
                NULLIF(v_data->>'estimatedValue', '')::NUMERIC,
                NULLIF(v_data->>'projectManagerId', '')::UUID
            ) RETURNING id INTO v_new_project_id;
            RETURN jsonb_build_object('rid', 's-project-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_new_project_id));

        WHEN 'update_project' THEN
            UPDATE projects SET 
                title = COALESCE(NULLIF(v_data->>'title', ''), title),
                description = COALESCE(NULLIF(v_data->>'description', ''), description),
                status = COALESCE(NULLIF(v_data->>'status', '')::project_status, status),
                contact_id = COALESCE(NULLIF(v_data->>'contactId', '')::UUID, contact_id),
                estimated_value = COALESCE(NULLIF(v_data->>'estimatedValue', '')::NUMERIC, estimated_value),
                project_manager_id = COALESCE(NULLIF(v_data->>'projectManagerId', '')::UUID, project_manager_id),
                updated_at = NOW()
            WHERE id = NULLIF(v_data->>'id', '')::UUID;
            RETURN jsonb_build_object('rid', 's-project-updated', 'statusCode', 200, 'data', null);

        WHEN 'get_project' THEN
            SELECT row_to_json(pr) INTO v_res FROM (
                SELECT p.*, u.full_name as project_manager_name, c.first_name || ' ' || c.last_name as client_name
                FROM projects p
                LEFT JOIN users u ON p.project_manager_id = u.id
                LEFT JOIN contacts c ON p.contact_id = c.id
                WHERE p.id = NULLIF(v_data->>'id', '')::UUID AND p.deleted_at IS NULL
            ) pr;
            IF v_res IS NULL THEN RETURN fn_error_envelope('e-project-not-found', 404, 'Project not found'); END IF;
            RETURN jsonb_build_object('rid', 's-project-retrieved', 'statusCode', 200, 'data', v_res);

        WHEN 'list_templates' THEN
            SELECT jsonb_agg(pt) INTO v_res FROM (
                SELECT id, name, description, estimated_duration_days
                FROM project_templates WHERE deleted_at IS NULL
            ) pt;
            RETURN jsonb_build_object('rid', 's-templates-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
