SET search_path = crm, public;

-- V084: fn_sla_operations — SLA Policy CRUD + Escalation Management
-- Operations: list_sla_policies, create_sla_policy, update_sla_policy, delete_sla_policy,
--             check_sla_breaches (cron-callable), list_escalations, resolve_escalation

CREATE OR REPLACE FUNCTION fn_sla_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op     TEXT  := p_payload->>'operation';
    v_data   JSONB := p_payload->'data';
    v_req_by UUID  := (p_payload->>'requestedBy')::UUID;
    v_res    JSONB;
    v_new_id UUID;
    v_policy RECORD;
    v_entity RECORD;
    v_escalation_count INT := 0;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op

    -- ──────────────────────────────────────────
    -- LIST SLA POLICIES
    -- ──────────────────────────────────────────
    WHEN 'list_sla_policies' THEN
        SELECT jsonb_agg(row_to_json(p)) INTO v_res FROM (
            SELECT sp.*, u.full_name AS escalation_user_name
            FROM sla_policies sp
            LEFT JOIN users u ON sp.escalation_user_id = u.id
            WHERE sp.deleted_at IS NULL
              AND (v_data->>'entityType' IS NULL OR sp.entity_type = v_data->>'entityType')
            ORDER BY sp.created_at DESC
        ) p;
        RETURN jsonb_build_object('rid', 's-sla-policies-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- CREATE SLA POLICY
    -- ──────────────────────────────────────────
    WHEN 'create_sla_policy' THEN
        INSERT INTO sla_policies (
            name, entity_type, condition_json,
            due_time_hours, escalation_time_hours,
            notify_manager, escalation_user_id
        ) VALUES (
            v_data->>'name',
            v_data->>'entityType',
            COALESCE(v_data->'conditionJson', '{}'::jsonb),
            COALESCE((v_data->>'dueTimeHours')::INT, 24),
            COALESCE((v_data->>'escalationTimeHours')::INT, 48),
            COALESCE((v_data->>'notifyManager')::BOOLEAN, TRUE),
            (v_data->>'escalationUserId')::UUID
        ) RETURNING id INTO v_new_id;
        RETURN jsonb_build_object('rid', 's-sla-policy-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    -- ──────────────────────────────────────────
    -- UPDATE SLA POLICY
    -- ──────────────────────────────────────────
    WHEN 'update_sla_policy' THEN
        UPDATE sla_policies SET
            name                  = COALESCE(v_data->>'name', name),
            condition_json        = COALESCE(v_data->'conditionJson', condition_json),
            due_time_hours        = COALESCE((v_data->>'dueTimeHours')::INT, due_time_hours),
            escalation_time_hours = COALESCE((v_data->>'escalationTimeHours')::INT, escalation_time_hours),
            notify_manager        = COALESCE((v_data->>'notifyManager')::BOOLEAN, notify_manager),
            escalation_user_id    = COALESCE((v_data->>'escalationUserId')::UUID, escalation_user_id),
            is_active             = COALESCE((v_data->>'isActive')::BOOLEAN, is_active)
        WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        RETURN jsonb_build_object('rid', 's-sla-policy-updated', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- DELETE SLA POLICY
    -- ──────────────────────────────────────────
    WHEN 'delete_sla_policy' THEN
        UPDATE sla_policies SET deleted_at = NOW() WHERE id = (v_data->>'id')::UUID;
        RETURN jsonb_build_object('rid', 's-sla-policy-deleted', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- CHECK SLA BREACHES (cron-targeted)
    -- Evaluates tasks and leads against active SLA policies and creates escalation_logs
    -- ──────────────────────────────────────────
    WHEN 'check_sla_breaches' THEN
        -- Tasks SLA check (entity_type = 'task')
        FOR v_policy IN
            SELECT * FROM sla_policies
            WHERE entity_type = 'task' AND is_active = TRUE AND deleted_at IS NULL
        LOOP
            FOR v_entity IN
                SELECT
                    t.id, t.title, t.assigned_to,
                    t.created_at,
                    t.created_at + (v_policy.escalation_time_hours || ' hours')::INTERVAL AS sla_breach_at
                FROM tasks t
                WHERE t.deleted_at IS NULL
                  AND t.completed_at IS NULL
                  AND t.status NOT IN ('completed', 'cancelled')
                  AND NOW() > t.created_at + (v_policy.escalation_time_hours || ' hours')::INTERVAL
                  -- Only tasks not yet escalated under this policy
                  AND NOT EXISTS (
                      SELECT 1 FROM escalation_logs el
                      WHERE el.entity_type = 'task'
                        AND el.entity_id = t.id
                        AND el.sla_policy_id = v_policy.id
                        AND el.status != 'resolved'
                  )
                -- Apply condition_json filters (simple priority filter example)
                  AND (
                      v_policy.condition_json->>'priority' IS NULL OR
                      t.priority::TEXT = v_policy.condition_json->>'priority'
                  )
            LOOP
                -- Determine escalation target
                INSERT INTO escalation_logs (
                    entity_type, entity_id, sla_policy_id,
                    escalated_from, escalated_to, reason, status
                ) VALUES (
                    'task',
                    v_entity.id,
                    v_policy.id,
                    v_entity.assigned_to,
                    COALESCE(v_policy.escalation_user_id,
                        (SELECT u.id FROM users u JOIN roles r ON u.role_id = r.id WHERE r.slug = 'admin' LIMIT 1)),
                    'SLA breach: task overdue by policy "' || v_policy.name || '"',
                    'open'
                );

                -- Insert notification
                INSERT INTO notifications (user_id, title, message, entity_type, entity_id)
                SELECT
                    COALESCE(v_policy.escalation_user_id,
                        (SELECT u.id FROM users u JOIN roles r ON u.role_id = r.id WHERE r.slug = 'admin' LIMIT 1)),
                    'SLA Breach: ' || v_entity.title,
                    'Task "' || v_entity.title || '" has breached the SLA policy "' || v_policy.name || '"',
                    'task',
                    v_entity.id;

                v_escalation_count := v_escalation_count + 1;
            END LOOP;
        END LOOP;

        -- Lead SLA check (entity_type = 'lead')
        FOR v_policy IN
            SELECT * FROM sla_policies
            WHERE entity_type = 'lead' AND is_active = TRUE AND deleted_at IS NULL
        LOOP
            FOR v_entity IN
                SELECT l.id, l.title, l.assigned_to, l.created_at
                FROM leads l
                WHERE l.deleted_at IS NULL
                  AND l.status NOT IN ('converted', 'lost')
                  AND NOW() > l.created_at + (v_policy.escalation_time_hours || ' hours')::INTERVAL
                  AND NOT EXISTS (
                      SELECT 1 FROM escalation_logs el
                      WHERE el.entity_type = 'lead'
                        AND el.entity_id = l.id
                        AND el.sla_policy_id = v_policy.id
                        AND el.status != 'resolved'
                  )
            LOOP
                INSERT INTO escalation_logs (
                    entity_type, entity_id, sla_policy_id,
                    escalated_from, escalated_to, reason, status
                ) VALUES (
                    'lead', v_entity.id, v_policy.id,
                    v_entity.assigned_to,
                    COALESCE(v_policy.escalation_user_id,
                        (SELECT u.id FROM users u JOIN roles r ON u.role_id = r.id WHERE r.slug = 'admin' LIMIT 1)),
                    'SLA breach: lead unactioned by policy "' || v_policy.name || '"',
                    'open'
                );

                INSERT INTO notifications (user_id, title, message, entity_type, entity_id)
                SELECT
                    COALESCE(v_policy.escalation_user_id,
                        (SELECT u.id FROM users u JOIN roles r ON u.role_id = r.id WHERE r.slug = 'admin' LIMIT 1)),
                    'SLA Breach: Lead ' || v_entity.title,
                    'Lead "' || v_entity.title || '" has exceeded allowed response time',
                    'lead',
                    v_entity.id;

                v_escalation_count := v_escalation_count + 1;
            END LOOP;
        END LOOP;

        RETURN jsonb_build_object('rid', 's-sla-check-complete', 'statusCode', 200,
            'data', jsonb_build_object('escalationsCreated', v_escalation_count));

    -- ──────────────────────────────────────────
    -- LIST ESCALATIONS
    -- ──────────────────────────────────────────
    WHEN 'list_escalations' THEN
        SELECT jsonb_agg(row_to_json(e)) INTO v_res FROM (
            SELECT
                el.id, el.entity_type, el.entity_id,
                el.sla_policy_id, sp.name AS sla_policy_name,
                el.escalated_from, ef.full_name AS escalated_from_name,
                el.escalated_to,   et.full_name AS escalated_to_name,
                el.reason, el.status,
                el.escalated_at, el.resolved_at
            FROM escalation_logs el
            LEFT JOIN sla_policies sp ON el.sla_policy_id = sp.id
            LEFT JOIN users ef ON el.escalated_from = ef.id
            LEFT JOIN users et ON el.escalated_to   = et.id
            WHERE (v_data->>'status' IS NULL OR el.status = v_data->>'status')
              AND (v_data->>'entityType' IS NULL OR el.entity_type = v_data->>'entityType')
            ORDER BY el.escalated_at DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) e;
        RETURN jsonb_build_object('rid', 's-escalations-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- RESOLVE ESCALATION
    -- ──────────────────────────────────────────
    WHEN 'resolve_escalation' THEN
        UPDATE escalation_logs SET
            status      = 'resolved',
            resolved_at = NOW()
        WHERE id = (v_data->>'id')::UUID;
        RETURN jsonb_build_object('rid', 's-escalation-resolved', 'statusCode', 200, 'data', null);

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
