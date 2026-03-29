SET search_path = crm, public;

-- V065: Tasks Dispatcher Pagination Support
CREATE OR REPLACE FUNCTION fn_task_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_id UUID;
    v_search TEXT := v_data->>'q';
    v_project_id UUID := (v_data->>'projectId')::UUID;
    
    -- Pagination variables
    v_limit INT := COALESCE((v_data->>'limit')::INT, 10);
    v_page INT := COALESCE((v_data->>'page')::INT, 1);
    v_offset INT := (v_page - 1) * v_limit;
    v_total_count INT := 0;
BEGIN
    -- Set session user for audit
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_tasks' THEN
            SELECT 
                jsonb_agg(to_jsonb(sub) - 'total_count'),
                COALESCE(MAX(sub.total_count), 0)
            INTO v_res, v_total_count
            FROM (
                SELECT 
                    t.*,
                    u.full_name as assigned_to_name,
                    COUNT(*) OVER() as total_count
                FROM tasks t
                LEFT JOIN users u ON t.assigned_to = u.id
                WHERE t.deleted_at IS NULL
                  AND (v_project_id IS NULL OR t.project_id = v_project_id)
                  AND (v_search IS NULL OR t.title ILIKE '%' || fn_escape_like(v_search) || '%' OR t.task_number ILIKE '%' || fn_escape_like(v_search) || '%')
                ORDER BY t.created_at ASC
                LIMIT v_limit
                OFFSET v_offset
            ) sub;
            
            RETURN jsonb_build_object(
                'rid', 's-tasks-listed', 
                'statusCode', 200, 
                'data', COALESCE(v_res, '[]'::jsonb),
                'meta', jsonb_build_object(
                    'total', v_total_count,
                    'page', v_page,
                    'limit', v_limit,
                    'totalPages', CEIL(v_total_count::NUMERIC / v_limit)
                )
            );

        WHEN 'create_task' THEN
            INSERT INTO tasks (
                task_number, project_id, title, description, assigned_to, 
                priority, status, start_date, due_date
            ) VALUES (
                generate_task_number(),
                (v_data->>'projectId')::UUID,
                v_data->>'title',
                v_data->>'description',
                (v_data->>'assignedTo')::UUID,
                COALESCE((v_data->>'priority')::task_priority, 'medium'),
                COALESCE((v_data->>'status')::task_status, 'todo'),
                (v_data->>'startDate')::TIMESTAMPTZ,
                (v_data->>'dueDate')::TIMESTAMPTZ
            ) RETURNING id INTO v_id;
            
            -- Trigger workflow
            PERFORM fn_trigger_workflow('task_created', v_id);

            RETURN jsonb_build_object('rid', 's-task-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_id));

        WHEN 'update_status' THEN
            UPDATE tasks SET 
                status = (v_data->>'status')::task_status,
                updated_at = NOW()
            WHERE id = (v_data->>'id')::UUID;
            
            RETURN jsonb_build_object('rid', 's-task-status-updated', 'statusCode', 200, 'data', null);

        WHEN 'update_task' THEN
            UPDATE tasks SET 
                title = COALESCE(v_data->>'title', title),
                description = COALESCE(v_data->>'description', description),
                assigned_to = COALESCE((v_data->>'assignedTo')::UUID, assigned_to),
                priority = COALESCE((v_data->>'priority')::task_priority, priority),
                status = COALESCE((v_data->>'status')::task_status, status),
                due_date = COALESCE((v_data->>'dueDate')::TIMESTAMPTZ, due_date),
                updated_at = NOW()
            WHERE id = (v_data->>'id')::UUID;
            
            RETURN jsonb_build_object('rid', 's-task-updated', 'statusCode', 200, 'data', null);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
