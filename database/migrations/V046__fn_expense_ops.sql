SET search_path = crm, public;

-- V046: Expenses Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_expense_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_id UUID;
    v_project_id UUID;
    v_search TEXT := v_data->>'q';
BEGIN
    -- Set session user for audit
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_expenses' THEN
            SELECT jsonb_agg(e) INTO v_res FROM (
                SELECT 
                    e.*,
                    p.title as project_title,
                    u.full_name as logged_by_name
                FROM expenses e
                LEFT JOIN projects p ON e.project_id = p.id
                LEFT JOIN users u ON e.logged_by = u.id
                WHERE e.deleted_at IS NULL
                  -- Filters
                  AND ((v_data->>'projectId') IS NULL OR e.project_id = (v_data->>'projectId')::UUID)
                  AND (v_search IS NULL OR e.description ILIKE '%' || fn_escape_like(v_search) || '%')
                ORDER BY e.expense_date DESC
            ) e;
            RETURN jsonb_build_object('rid', 's-expenses-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'create_expense' THEN
            v_project_id := (v_data->>'projectId')::UUID;
            
            INSERT INTO expenses (
                project_id, category, amount, description, expense_date, logged_by, status
            ) VALUES (
                v_project_id,
                (v_data->>'category')::expense_category,
                (v_data->>'amount')::NUMERIC,
                v_data->>'description',
                COALESCE((v_data->>'expenseDate')::DATE, CURRENT_DATE),
                v_req_by,
                'approved' -- Automatic approval for skeleton/simplicity
            ) RETURNING id INTO v_id;

            -- Automated Roll-up: Update project actual cost
            IF v_project_id IS NOT NULL THEN
                UPDATE projects 
                SET actual_cost = (SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE project_id = v_project_id AND deleted_at IS NULL)
                WHERE id = v_project_id;
            END IF;

            RETURN jsonb_build_object('rid', 's-expense-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_id));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
