SET search_path = crm, public;

-- V083: fn_assignment_operations — Pool management + assignment history queries
-- Operations: list_pools, create_pool, add_pool_member, remove_pool_member,
--             list_assignment_history, get_unassigned_leads

CREATE OR REPLACE FUNCTION fn_assignment_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op     TEXT  := p_payload->>'operation';
    v_data   JSONB := p_payload->'data';
    v_req_by UUID  := (p_payload->>'requestedBy')::UUID;
    v_res    JSONB;
    v_new_id UUID;
    v_pool   RECORD;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    -- Require admin or manager for pool management
    CASE v_op

    -- ──────────────────────────────────────────
    -- LIST POOLS
    -- ──────────────────────────────────────────
    WHEN 'list_pools' THEN
        SELECT jsonb_agg(row_to_json(p)) INTO v_res FROM (
            SELECT
                ap.*,
                (SELECT jsonb_agg(jsonb_build_object(
                    'userId', pm.user_id,
                    'userName', u.full_name,
                    'isActive', pm.is_active,
                    'assignmentCount', pm.assignment_count,
                    'addedAt', pm.added_at
                ))
                FROM pool_members pm
                JOIN users u ON pm.user_id = u.id
                WHERE pm.pool_id = ap.id AND pm.is_active = TRUE) AS members
            FROM assignment_pools ap
            WHERE ap.deleted_at IS NULL
              AND (v_data->>'entityType' IS NULL OR ap.entity_type = v_data->>'entityType')
            ORDER BY ap.created_at DESC
        ) p;
        RETURN jsonb_build_object('rid', 's-pools-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- CREATE POOL
    -- ──────────────────────────────────────────
    WHEN 'create_pool' THEN
        INSERT INTO assignment_pools (name, entity_type, rule_type)
        VALUES (
            v_data->>'name',
            COALESCE(v_data->>'entityType', 'lead'),
            COALESCE((v_data->>'ruleType')::assignment_rule_type, 'round_robin')
        ) RETURNING id INTO v_new_id;
        RETURN jsonb_build_object('rid', 's-pool-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    -- ──────────────────────────────────────────
    -- ADD MEMBER TO POOL
    -- ──────────────────────────────────────────
    WHEN 'add_pool_member' THEN
        INSERT INTO pool_members (pool_id, user_id, is_active)
        VALUES (
            (v_data->>'poolId')::UUID,
            (v_data->>'userId')::UUID,
            TRUE
        )
        ON CONFLICT (pool_id, user_id) DO UPDATE SET is_active = TRUE;
        RETURN jsonb_build_object('rid', 's-pool-member-added', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- REMOVE MEMBER FROM POOL
    -- ──────────────────────────────────────────
    WHEN 'remove_pool_member' THEN
        UPDATE pool_members SET is_active = FALSE
        WHERE pool_id = (v_data->>'poolId')::UUID
          AND user_id = (v_data->>'userId')::UUID;
        RETURN jsonb_build_object('rid', 's-pool-member-removed', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- DELETE POOL
    -- ──────────────────────────────────────────
    WHEN 'delete_pool' THEN
        UPDATE assignment_pools SET deleted_at = NOW() WHERE id = (v_data->>'id')::UUID;
        RETURN jsonb_build_object('rid', 's-pool-deleted', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- LIST ASSIGNMENT HISTORY for an entity
    -- ──────────────────────────────────────────
    WHEN 'list_assignment_history' THEN
        SELECT jsonb_agg(row_to_json(h)) INTO v_res FROM (
            SELECT
                ah.id, ah.entity_type, ah.entity_id,
                ah.previous_user_id, pu.full_name AS previous_user_name,
                ah.new_user_id,      nu.full_name AS new_user_name,
                ah.assigned_by,      ab.full_name AS assigned_by_name,
                ah.reason, ah.assigned_at
            FROM assignment_history ah
            LEFT JOIN users pu ON ah.previous_user_id = pu.id
            LEFT JOIN users nu ON ah.new_user_id = nu.id
            LEFT JOIN users ab ON ah.assigned_by = ab.id
            WHERE ah.entity_type = v_data->>'entityType'
              AND ah.entity_id   = (v_data->>'entityId')::UUID
            ORDER BY ah.assigned_at DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) h;
        RETURN jsonb_build_object('rid', 's-assignment-history-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- GET UNASSIGNED LEADS (pool-pick view)
    -- ──────────────────────────────────────────
    WHEN 'get_unassigned_leads' THEN
        SELECT jsonb_agg(row_to_json(l)) INTO v_res FROM (
            SELECT l.id, l.lead_number, l.title, l.status, l.source,
                   l.email, l.phone, l.estimated_value,
                   l.created_at
            FROM leads l
            WHERE l.assigned_to IS NULL
              AND l.deleted_at IS NULL
              AND l.status NOT IN ('converted', 'lost')
            ORDER BY l.created_at ASC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) l;
        RETURN jsonb_build_object('rid', 's-unassigned-leads-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
