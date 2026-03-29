SET search_path = crm, public;

-- V082: fn_activity_operations — Unified Activity/Timeline Feed
-- Operations: list_activities, create_activity, log_call, log_meeting, log_email

CREATE OR REPLACE FUNCTION fn_activity_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op     TEXT  := p_payload->>'operation';
    v_data   JSONB := p_payload->'data';
    v_req_by UUID  := (p_payload->>'requestedBy')::UUID;
    v_res    JSONB;
    v_new_id UUID;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op

    -- ──────────────────────────────────────────
    -- LIST ACTIVITIES for an entity
    -- ──────────────────────────────────────────
    WHEN 'list_activities' THEN
        SELECT jsonb_agg(row_to_json(a)) INTO v_res FROM (
            SELECT
                a.id, a.entity_type, a.entity_id,
                a.type, a.title, a.description,
                a.performed_by, u.full_name AS performed_by_name,
                a.activity_date, a.metadata,
                a.created_at
            FROM activities a
            LEFT JOIN users u ON a.performed_by = u.id
            WHERE a.entity_type = v_data->>'entityType'
              AND a.entity_id   = (v_data->>'entityId')::UUID
              AND a.deleted_at IS NULL
              AND (v_data->>'type' IS NULL OR a.type::TEXT = v_data->>'type')
            ORDER BY a.activity_date DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) a;
        RETURN jsonb_build_object('rid', 's-activities-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- LIST GLOBAL TIMELINE (recent across all entities for a user)
    -- ──────────────────────────────────────────
    WHEN 'list_global_timeline' THEN
        SELECT jsonb_agg(row_to_json(a)) INTO v_res FROM (
            SELECT
                a.id, a.entity_type, a.entity_id,
                a.type, a.title, a.description,
                a.performed_by, u.full_name AS performed_by_name,
                a.activity_date, a.metadata
            FROM activities a
            LEFT JOIN users u ON a.performed_by = u.id
            WHERE a.deleted_at IS NULL
              AND (
                  (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                  OR a.performed_by = v_req_by
              )
            ORDER BY a.activity_date DESC
            LIMIT COALESCE((v_data->>'limit')::INT, 30)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) a;
        RETURN jsonb_build_object('rid', 's-timeline-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- LOG CALL
    -- ──────────────────────────────────────────
    WHEN 'log_call' THEN
        IF v_data->>'entityType' IS NULL OR v_data->>'entityId' IS NULL THEN
            RETURN fn_error_envelope('e-activity-invalid', 400, 'entityType and entityId are required');
        END IF;

        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by, activity_date, metadata)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            'call',
            COALESCE(v_data->>'title', 'Call logged'),
            v_data->>'description',
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            COALESCE(v_data->'metadata', '{}'::jsonb)
        ) RETURNING id INTO v_new_id;

        -- Also log into communications for backward compatibility
        INSERT INTO communications (module_name, entity_id, entity_type, type, subject, content,
                                    direction, performed_by, performed_at, channel, summary)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            v_data->>'entityType',
            'call',
            COALESCE(v_data->>'title', 'Call'),
            v_data->>'description',
            COALESCE(v_data->>'direction', 'outbound'),
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            'call',
            v_data->>'description'
        );

        RETURN jsonb_build_object('rid', 's-call-logged', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    -- ──────────────────────────────────────────
    -- LOG MEETING
    -- ──────────────────────────────────────────
    WHEN 'log_meeting' THEN
        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by, activity_date, metadata)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            'meeting',
            COALESCE(v_data->>'title', 'Meeting logged'),
            v_data->>'description',
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            COALESCE(v_data->'metadata', '{}'::jsonb)
        ) RETURNING id INTO v_new_id;

        INSERT INTO communications (module_name, entity_id, entity_type, type, subject, content,
                                    direction, performed_by, performed_at, channel, summary)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            v_data->>'entityType',
            'meeting',
            COALESCE(v_data->>'title', 'Meeting'),
            v_data->>'description',
            'outbound',
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            'meeting',
            v_data->>'description'
        );

        RETURN jsonb_build_object('rid', 's-meeting-logged', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    -- ──────────────────────────────────────────
    -- LOG EMAIL
    -- ──────────────────────────────────────────
    WHEN 'log_email' THEN
        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by, activity_date, metadata)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            'email',
            COALESCE(v_data->>'title', 'Email logged'),
            v_data->>'description',
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            COALESCE(v_data->'metadata', '{}'::jsonb)
        ) RETURNING id INTO v_new_id;

        INSERT INTO communications (module_name, entity_id, entity_type, type, subject, content,
                                    direction, performed_by, performed_at, channel, summary)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            v_data->>'entityType',
            'email',
            COALESCE(v_data->>'title', 'Email'),
            v_data->>'description',
            COALESCE(v_data->>'direction', 'outbound'),
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            'email',
            v_data->>'description'
        );

        RETURN jsonb_build_object('rid', 's-email-logged', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    -- ──────────────────────────────────────────
    -- GENERIC CREATE ACTIVITY
    -- ──────────────────────────────────────────
    WHEN 'create_activity' THEN
        IF v_data->>'entityType' IS NULL OR v_data->>'entityId' IS NULL OR v_data->>'type' IS NULL THEN
            RETURN fn_error_envelope('e-activity-invalid', 400, 'entityType, entityId and type are required');
        END IF;

        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by, activity_date, metadata)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            (v_data->>'type')::activity_type,
            COALESCE(v_data->>'title', 'Activity'),
            v_data->>'description',
            v_req_by,
            COALESCE((v_data->>'activityDate')::TIMESTAMPTZ, NOW()),
            COALESCE(v_data->'metadata', '{}'::jsonb)
        ) RETURNING id INTO v_new_id;

        RETURN jsonb_build_object('rid', 's-activity-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
