SET search_path = crm, public;

-- V066: Projects Dispatcher Pagination Support
CREATE OR REPLACE FUNCTION fn_project_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_id UUID;
    v_search TEXT := v_data->>'q';
    v_status TEXT := v_data->>'status';
    
    -- Pagination variables
    v_limit INT := COALESCE((v_data->>'limit')::INT, 10);
    v_page INT := COALESCE((v_data->>'page')::INT, 1);
    v_offset INT := (v_page - 1) * v_limit;
    v_total_count INT := 0;
BEGIN
    -- Set session user for audit
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_projects' THEN
            SELECT 
                jsonb_agg(to_jsonb(sub) - 'total_count'),
                COALESCE(MAX(sub.total_count), 0)
            INTO v_res, v_total_count
            FROM (
                SELECT 
                    p.*,
                    u.full_name as manager_name,
                    c.first_name || ' ' || c.last_name as contact_name,
                    COUNT(*) OVER() as total_count
                FROM projects p
                LEFT JOIN users u ON p.project_manager_id = u.id
                LEFT JOIN contacts c ON p.contact_id = c.id
                WHERE p.deleted_at IS NULL
                  AND (v_search IS NULL OR p.title ILIKE '%' || fn_escape_like(v_search) || '%' OR p.project_number ILIKE '%' || fn_escape_like(v_search) || '%')
                  AND (v_status IS NULL OR p.status::TEXT = v_status)
                  -- RBAC: Non-admins see own
                  AND (
                    (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                    OR p.project_manager_id = v_req_by 
                    OR p.project_manager_id IS NULL
                  )
                ORDER BY p.created_at DESC
                LIMIT v_limit
                OFFSET v_offset
            ) sub;
            
            RETURN jsonb_build_object(
                'rid', 's-projects-listed', 
                'statusCode', 200, 
                'data', COALESCE(v_res, '[]'::jsonb),
                'meta', jsonb_build_object(
                    'total', v_total_count,
                    'page', v_page,
                    'limit', v_limit,
                    'totalPages', CEIL(v_total_count::NUMERIC / v_limit)
                )
            );

        WHEN 'create_project' THEN
            INSERT INTO projects (
                project_number, title, description, contact_id, lead_id, project_manager_id, 
                estimated_value, start_date, end_date, status
            ) VALUES (
                generate_project_number(),
                v_data->>'title',
                v_data->>'description',
                (v_data->>'contactId')::UUID,
                (v_data->>'leadId')::UUID,
                COALESCE((v_data->>'projectManagerId')::UUID, v_req_by),
                (v_data->>'estimatedValue')::NUMERIC,
                (v_data->>'startDate')::TIMESTAMPTZ,
                (v_data->>'endDate')::TIMESTAMPTZ,
                COALESCE((v_data->>'status')::project_status, 'planning')
            ) RETURNING id INTO v_id;
            RETURN jsonb_build_object('rid', 's-project-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_id));

        WHEN 'get_project' THEN
            v_id := (v_data->>'id')::UUID;
            SELECT row_to_json(p) INTO v_res FROM (
                SELECT 
                    p.*,
                    (SELECT jsonb_agg(ph) FROM (
                        SELECT * FROM project_phases 
                        WHERE project_id = p.id AND deleted_at IS NULL 
                        ORDER BY sort_order
                    ) ph) as phases,
                    (SELECT jsonb_agg(m) FROM (
                        SELECT * FROM project_milestones 
                        WHERE project_id = p.id AND deleted_at IS NULL 
                        ORDER BY target_date
                    ) m) as milestones,
                    (SELECT jsonb_agg(t) FROM tasks t WHERE t.project_id = p.id AND t.deleted_at IS NULL) as tasks,
                    (SELECT jsonb_agg(d) FROM documents d WHERE d.entity_id = p.id AND d.module_name = 'projects' AND d.deleted_at IS NULL) as documents
                FROM projects p
                WHERE p.id = v_id AND p.deleted_at IS NULL
            ) p;
            
            IF v_res IS NULL THEN RETURN fn_error_envelope('e-project-not-found', 404, 'Project not found'); END IF;
            RETURN jsonb_build_object('rid', 's-project-loaded', 'statusCode', 200, 'data', v_res);

        WHEN 'list_templates' THEN
            SELECT jsonb_agg(t) INTO v_res FROM (
                SELECT * FROM project_templates WHERE deleted_at IS NULL ORDER BY name
            ) t;
            RETURN jsonb_build_object('rid', 's-templates-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
