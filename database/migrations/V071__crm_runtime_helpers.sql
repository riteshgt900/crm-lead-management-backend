SET search_path = crm, public;

CREATE OR REPLACE FUNCTION fn_runtime_success(
    p_rid TEXT,
    p_status INT,
    p_data JSONB,
    p_message TEXT DEFAULT 'Operation successful',
    p_meta JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_build_object(
        'rid', p_rid,
        'statusCode', p_status,
        'data', COALESCE(p_data, 'null'::jsonb),
        'message', p_message,
        'meta', jsonb_build_object('timestamp', NOW()) || COALESCE(p_meta, '{}'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION fn_runtime_is_admin(
    p_requested_by UUID,
    p_role TEXT DEFAULT NULL,
    p_permissions JSONB DEFAULT '[]'::jsonb
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_role TEXT := lower(COALESCE(p_role, ''));
BEGIN
    IF v_role IN ('admin', 'super_admin', 'superadmin', 'owner') THEN
        RETURN TRUE;
    END IF;

    IF p_permissions @> '["settings:manage"]'::jsonb
       OR p_permissions @> '["rbac:manage"]'::jsonb
       OR p_permissions @> '["users:manage"]'::jsonb THEN
        RETURN TRUE;
    END IF;

    IF p_requested_by IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM users u
        JOIN roles r ON r.id = u.role_id
        WHERE u.id = p_requested_by
          AND u.deleted_at IS NULL
          AND r.slug IN ('admin', 'super_admin', 'superadmin', 'owner')
    );
END;
$$;

CREATE OR REPLACE FUNCTION fn_runtime_literal(p_value JSONB, p_data_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_type TEXT := lower(COALESCE(NULLIF(p_data_type, ''), 'text'));
    v_scalar TEXT;
BEGIN
    IF p_value IS NULL OR p_value = 'null'::jsonb THEN
        RETURN 'NULL';
    END IF;

    IF v_type !~ '^[a-z_][a-z0-9_]*(\[\])?$' THEN
        RAISE EXCEPTION 'Unsafe data type: %', p_data_type;
    END IF;

    IF jsonb_typeof(p_value) IN ('object', 'array') THEN
        RETURN format('%L::jsonb', p_value::text);
    END IF;

    v_scalar := p_value #>> '{}';

    CASE v_type
        WHEN 'text', 'varchar', 'character varying', 'string' THEN
            RETURN format('%L', v_scalar);
        WHEN 'uuid' THEN
            RETURN format('%L::uuid', v_scalar);
        WHEN 'int', 'int4', 'integer' THEN
            RETURN format('%L::integer', v_scalar);
        WHEN 'bigint', 'int8' THEN
            RETURN format('%L::bigint', v_scalar);
        WHEN 'numeric', 'decimal', 'float', 'float8' THEN
            RETURN format('%L::numeric', v_scalar);
        WHEN 'boolean', 'bool' THEN
            RETURN format('%L::boolean', v_scalar);
        WHEN 'date' THEN
            RETURN format('%L::date', v_scalar);
        WHEN 'timestamp', 'timestamptz', 'timestamp with time zone' THEN
            RETURN format('%L::timestamptz', v_scalar);
        WHEN 'json', 'jsonb' THEN
            RETURN format('%L::jsonb', p_value::text);
        ELSE
            RETURN format('%L::%s', v_scalar, v_type);
    END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_record_tags(p_entity_key TEXT, p_record_id UUID)
RETURNS JSONB
LANGUAGE sql
AS $$
    SELECT COALESCE(
        jsonb_agg(rt.tag ORDER BY lower(rt.tag)),
        '[]'::jsonb
    )
    FROM record_tags rt
    WHERE rt.entity_key = p_entity_key
      AND rt.record_id = p_record_id
      AND rt.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_sync_record_tags(
    p_entity_key TEXT,
    p_record_id UUID,
    p_tags JSONB,
    p_created_by UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_tag TEXT;
BEGIN
    UPDATE record_tags
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE entity_key = p_entity_key
      AND record_id = p_record_id
      AND deleted_at IS NULL;

    IF p_tags IS NULL OR jsonb_typeof(p_tags) <> 'array' THEN
        RETURN;
    END IF;

    FOR v_tag IN
        SELECT DISTINCT NULLIF(btrim(value), '')
        FROM jsonb_array_elements_text(p_tags) AS value
    LOOP
        IF v_tag IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO record_tags (entity_key, record_id, tag, created_by)
        VALUES (p_entity_key, p_record_id, v_tag, p_created_by);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_custom_field_values(p_entity_key TEXT, p_record_id UUID)
RETURNS JSONB
LANGUAGE sql
AS $$
    SELECT COALESCE(
        jsonb_object_agg(cfd.field_key, cfv.value_json),
        '{}'::jsonb
    )
    FROM custom_field_values cfv
    JOIN custom_field_definitions cfd ON cfd.id = cfv.definition_id
    WHERE cfv.entity_key = p_entity_key
      AND cfv.record_id = p_record_id
      AND cfv.deleted_at IS NULL
      AND cfd.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_upsert_custom_field_values(
    p_entity_key TEXT,
    p_record_id UUID,
    p_values JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_item RECORD;
    v_definition_id UUID;
BEGIN
    IF p_values IS NULL OR jsonb_typeof(p_values) <> 'object' THEN
        RETURN;
    END IF;

    FOR v_item IN
        SELECT key, value
        FROM jsonb_each(p_values)
    LOOP
        SELECT id
        INTO v_definition_id
        FROM custom_field_definitions
        WHERE entity_key = p_entity_key
          AND field_key = v_item.key
          AND is_enabled = TRUE
          AND deleted_at IS NULL
        ORDER BY sort_order, created_at
        LIMIT 1;

        IF v_definition_id IS NULL THEN
            CONTINUE;
        END IF;

        UPDATE custom_field_values
        SET value_json = v_item.value,
            updated_at = NOW(),
            deleted_at = NULL
        WHERE entity_key = p_entity_key
          AND record_id = p_record_id
          AND definition_id = v_definition_id
          AND deleted_at IS NULL;

        IF NOT FOUND THEN
            INSERT INTO custom_field_values (entity_key, record_id, definition_id, value_json)
            VALUES (p_entity_key, p_record_id, v_definition_id, v_item.value);
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_task_dependencies(p_task_id UUID, p_dependency_ids JSONB)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_dependency_id UUID;
BEGIN
    UPDATE task_dependencies
    SET deleted_at = NOW()
    WHERE task_id = p_task_id
      AND deleted_at IS NULL;

    IF p_dependency_ids IS NULL OR jsonb_typeof(p_dependency_ids) <> 'array' THEN
        RETURN;
    END IF;

    FOR v_dependency_id IN
        SELECT DISTINCT NULLIF(value, '')::uuid
        FROM jsonb_array_elements_text(p_dependency_ids) AS value
    LOOP
        IF v_dependency_id IS NULL OR v_dependency_id = p_task_id THEN
            CONTINUE;
        END IF;

        INSERT INTO task_dependencies (task_id, depends_on_task_id)
        VALUES (p_task_id, v_dependency_id);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_task_watchers(p_task_id UUID, p_watcher_ids JSONB)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    UPDATE task_watchers
    SET deleted_at = NOW()
    WHERE task_id = p_task_id
      AND deleted_at IS NULL;

    IF p_watcher_ids IS NULL OR jsonb_typeof(p_watcher_ids) <> 'array' THEN
        RETURN;
    END IF;

    FOR v_user_id IN
        SELECT DISTINCT NULLIF(value, '')::uuid
        FROM jsonb_array_elements_text(p_watcher_ids) AS value
    LOOP
        IF v_user_id IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO task_watchers (task_id, user_id)
        VALUES (p_task_id, v_user_id);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_quotation_items(p_quotation_id UUID, p_items JSONB)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_item JSONB;
    v_quantity NUMERIC;
    v_unit_price NUMERIC;
    v_total NUMERIC := 0;
    v_sort_order INT := 1;
BEGIN
    DELETE FROM quotation_items
    WHERE quotation_id = p_quotation_id;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RETURN 0;
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items) AS value
    LOOP
        v_quantity := COALESCE(NULLIF(v_item->>'quantity', '')::numeric, 1);
        v_unit_price := COALESCE(NULLIF(v_item->>'unitPrice', '')::numeric, NULLIF(v_item->>'unit_price', '')::numeric, 0);

        INSERT INTO quotation_items (
            quotation_id,
            description,
            quantity,
            unit_price,
            total_price,
            sort_order
        )
        VALUES (
            p_quotation_id,
            COALESCE(v_item->>'description', 'Item ' || v_sort_order),
            v_quantity,
            v_unit_price,
            v_quantity * v_unit_price,
            v_sort_order
        );

        v_total := v_total + (v_quantity * v_unit_price);
        v_sort_order := v_sort_order + 1;
    END LOOP;

    RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION fn_clone_project_template(p_project_id UUID, p_template_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_phase_count INT := 0;
    v_task_count INT := 0;
BEGIN
    INSERT INTO project_phases (
        project_id,
        template_id,
        name,
        description,
        sort_order,
        status,
        start_date,
        end_date
    )
    SELECT
        p_project_id,
        p_template_id,
        pp.name,
        pp.description,
        pp.sort_order,
        COALESCE(pp.status, 'planning'::project_status),
        pp.start_date,
        pp.end_date
    FROM project_phases pp
    WHERE pp.template_id = p_template_id
      AND pp.deleted_at IS NULL;

    GET DIAGNOSTICS v_phase_count = ROW_COUNT;

    INSERT INTO tasks (
        task_number,
        project_id,
        title,
        description,
        status,
        priority,
        estimated_hours,
        is_template
    )
    SELECT
        generate_task_number(),
        p_project_id,
        t.title,
        t.description,
        COALESCE(t.status, 'todo'::task_status),
        COALESCE(t.priority, 'medium'::task_priority),
        t.estimated_hours,
        FALSE
    FROM tasks t
    WHERE t.is_template = TRUE
      AND t.project_id IS NULL
      AND t.deleted_at IS NULL;

    GET DIAGNOSTICS v_task_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'phaseCount', v_phase_count,
        'taskCount', v_task_count
    );
END;
$$;

CREATE OR REPLACE FUNCTION fn_runtime_enrich_record(p_entity_key TEXT, p_record JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_record_id UUID := NULLIF(p_record->>'id', '')::uuid;
    v_result JSONB := COALESCE(p_record, '{}'::jsonb);
BEGIN
    IF v_record_id IS NULL THEN
        RETURN v_result;
    END IF;

    v_result := v_result
        || jsonb_build_object('tags', fn_get_record_tags(p_entity_key, v_record_id))
        || jsonb_build_object('customFields', fn_get_custom_field_values(p_entity_key, v_record_id));

    CASE p_entity_key
        WHEN 'task' THEN
            v_result := v_result
                || jsonb_build_object(
                    'dependencyIds',
                    COALESCE((
                        SELECT jsonb_agg(depends_on_task_id ORDER BY depends_on_task_id)
                        FROM task_dependencies
                        WHERE task_id = v_record_id
                          AND deleted_at IS NULL
                    ), '[]'::jsonb)
                )
                || jsonb_build_object(
                    'watcherIds',
                    COALESCE((
                        SELECT jsonb_agg(user_id ORDER BY user_id)
                        FROM task_watchers
                        WHERE task_id = v_record_id
                          AND deleted_at IS NULL
                    ), '[]'::jsonb)
                );
        WHEN 'quotation' THEN
            v_result := v_result
                || jsonb_build_object(
                    'lineItems',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', qi.id,
                                'description', qi.description,
                                'quantity', qi.quantity,
                                'unitPrice', qi.unit_price,
                                'totalPrice', qi.total_price,
                                'sortOrder', qi.sort_order
                            )
                            ORDER BY qi.sort_order
                        )
                        FROM quotation_items qi
                        WHERE qi.quotation_id = v_record_id
                    ), '[]'::jsonb)
                );
        WHEN 'document' THEN
            v_result := v_result
                || jsonb_build_object(
                    'versions',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', dv.id,
                                'versionNo', dv.version_no,
                                'versionLabel', dv.version_label,
                                'status', dv.status,
                                'fileName', dv.file_name,
                                'filePath', dv.file_path,
                                'fileType', dv.file_type,
                                'fileSize', dv.file_size,
                                'approvedBy', dv.approved_by,
                                'approvedAt', dv.approved_at,
                                'createdAt', dv.created_at
                            )
                            ORDER BY dv.version_no DESC
                        )
                        FROM document_versions dv
                        WHERE dv.document_id = v_record_id
                          AND dv.deleted_at IS NULL
                    ), '[]'::jsonb)
                );
        WHEN 'project' THEN
            v_result := v_result
                || jsonb_build_object(
                    'stakeholders',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', ps.id,
                                'accountId', ps.account_id,
                                'contactId', ps.contact_id,
                                'roleKey', ps.role_key,
                                'isPrimary', ps.is_primary,
                                'notes', ps.notes
                            )
                            ORDER BY ps.is_primary DESC, ps.created_at ASC
                        )
                        FROM project_stakeholders ps
                        WHERE ps.project_id = v_record_id
                          AND ps.deleted_at IS NULL
                    ), '[]'::jsonb)
                );
        ELSE
            NULL;
    END CASE;

    RETURN v_result;
END;
$$;
