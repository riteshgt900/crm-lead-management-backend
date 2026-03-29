SET search_path = crm, public;

-- V081: fn_notes_operations — Universal Notes for any entity
-- Operations: list_notes, get_note, create_note, update_note, pin_note, delete_note

CREATE OR REPLACE FUNCTION fn_notes_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op     TEXT  := p_payload->>'operation';
    v_data   JSONB := p_payload->'data';
    v_req_by UUID  := (p_payload->>'requestedBy')::UUID;
    v_res    JSONB;
    v_note   RECORD;
    v_new_id UUID;
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op

    WHEN 'list_notes' THEN
        SELECT jsonb_agg(row_to_json(n)) INTO v_res FROM (
            SELECT
                n.id, n.entity_type, n.entity_id,
                n.content, n.is_pinned,
                n.created_by, u.full_name AS created_by_name,
                n.created_at, n.updated_at
            FROM notes n
            LEFT JOIN users u ON n.created_by = u.id
            WHERE n.entity_type = v_data->>'entityType'
              AND n.entity_id   = (v_data->>'entityId')::UUID
              AND n.deleted_at IS NULL
            ORDER BY n.is_pinned DESC, n.created_at DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) n;
        RETURN jsonb_build_object('rid', 's-notes-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    WHEN 'get_note' THEN
        SELECT row_to_json(n) INTO v_res FROM (
            SELECT n.*, u.full_name AS created_by_name
            FROM notes n
            LEFT JOIN users u ON n.created_by = u.id
            WHERE n.id = (v_data->>'id')::UUID AND n.deleted_at IS NULL
        ) n;
        IF v_res IS NULL THEN RETURN fn_error_envelope('e-note-not-found', 404, 'Note not found'); END IF;
        RETURN jsonb_build_object('rid', 's-note-loaded', 'statusCode', 200, 'data', v_res);

    WHEN 'create_note' THEN
        IF v_data->>'entityType' IS NULL OR v_data->>'entityId' IS NULL OR v_data->>'content' IS NULL THEN
            RETURN fn_error_envelope('e-note-invalid', 400, 'entityType, entityId and content are required');
        END IF;

        INSERT INTO notes (entity_type, entity_id, content, created_by, is_pinned)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            v_data->>'content',
            v_req_by,
            COALESCE((v_data->>'isPinned')::BOOLEAN, FALSE)
        ) RETURNING id INTO v_new_id;

        -- Mirror to activity timeline
        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by)
        VALUES (
            v_data->>'entityType',
            (v_data->>'entityId')::UUID,
            'note',
            'Note added',
            left(v_data->>'content', 120),
            v_req_by
        );

        RETURN jsonb_build_object('rid', 's-note-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_id));

    WHEN 'update_note' THEN
        SELECT * INTO v_note FROM notes WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_note.id IS NULL THEN RETURN fn_error_envelope('e-note-not-found', 404, 'Note not found'); END IF;

        -- Only creator or admin can edit
        IF v_note.created_by <> v_req_by THEN
            IF (SELECT r.slug FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = v_req_by) <> 'admin' THEN
                RETURN fn_error_envelope('e-note-forbidden', 403, 'You can only edit your own notes');
            END IF;
        END IF;

        UPDATE notes SET
            content  = COALESCE(v_data->>'content', content),
            is_pinned = COALESCE((v_data->>'isPinned')::BOOLEAN, is_pinned)
        WHERE id = v_note.id;

        RETURN jsonb_build_object('rid', 's-note-updated', 'statusCode', 200, 'data', null);

    WHEN 'pin_note' THEN
        SELECT id INTO v_new_id FROM notes WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_new_id IS NULL THEN RETURN fn_error_envelope('e-note-not-found', 404, 'Note not found'); END IF;

        UPDATE notes SET is_pinned = NOT is_pinned WHERE id = v_new_id;
        RETURN jsonb_build_object('rid', 's-note-pinned', 'statusCode', 200, 'data', null);

    WHEN 'delete_note' THEN
        SELECT * INTO v_note FROM notes WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_note.id IS NULL THEN RETURN fn_error_envelope('e-note-not-found', 404, 'Note not found'); END IF;

        IF v_note.created_by <> v_req_by THEN
            IF (SELECT r.slug FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = v_req_by) <> 'admin' THEN
                RETURN fn_error_envelope('e-note-forbidden', 403, 'You can only delete your own notes');
            END IF;
        END IF;

        UPDATE notes SET deleted_at = NOW() WHERE id = v_note.id;
        RETURN jsonb_build_object('rid', 's-note-deleted', 'statusCode', 200, 'data', null);

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
