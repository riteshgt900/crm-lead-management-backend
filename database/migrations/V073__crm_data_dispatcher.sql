SET search_path = crm, public;

CREATE OR REPLACE FUNCTION fn_data_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = crm, public
AS $$
DECLARE
    v_entity RECORD;
    v_field RECORD;
    v_operation TEXT := lower(COALESCE(p_payload->>'operation', 'list'));
    v_data JSONB := COALESCE(p_payload->'data', '{}'::jsonb);
    v_entity_key TEXT := COALESCE(NULLIF(p_payload->>'entityKey', ''), NULLIF(v_data->>'entityKey', ''));
    v_requested_by UUID := NULLIF(p_payload->>'requestedBy', '')::uuid;
    v_role TEXT := COALESCE(p_payload->>'role', '');
    v_permissions JSONB := COALESCE(p_payload->'permissions', '[]'::jsonb);
    v_table TEXT;
    v_pk TEXT;
    v_sort_column TEXT;
    v_sort_order TEXT := CASE WHEN lower(COALESCE(v_data->>'sortOrder', 'desc')) = 'asc' THEN 'ASC' ELSE 'DESC' END;
    v_page INT := GREATEST(COALESCE(NULLIF(v_data->>'page', '')::int, 1), 1);
    v_limit INT := LEAST(GREATEST(COALESCE(NULLIF(v_data->>'limit', '')::int, 20), 1), 200);
    v_offset INT;
    v_q TEXT := NULLIF(v_data->>'q', '');
    v_id UUID := NULLIF(v_data->>'id', '')::uuid;
    v_where TEXT := 'deleted_at IS NULL';
    v_sql TEXT;
    v_rows JSONB;
    v_record JSONB;
    v_total BIGINT := 0;
    v_columns TEXT[] := ARRAY[]::text[];
    v_values TEXT[] := ARRAY[]::text[];
    v_sets TEXT[] := ARRAY[]::text[];
    v_tags JSONB := v_data->'tags';
    v_custom_fields JSONB := COALESCE(v_data->'customFields', v_data->'custom_fields');
    v_dependency_ids JSONB := COALESCE(v_data->'dependencyIds', v_data->'dependency_ids');
    v_watcher_ids JSONB := COALESCE(v_data->'watcherIds', v_data->'watcher_ids');
    v_line_items JSONB := COALESCE(v_data->'lineItems', v_data->'items', v_data->'line_items');
    v_generated_id UUID;
    v_status_rid TEXT := 's-data-operation-complete';
    v_total_amount NUMERIC := 0;
    v_action TEXT := lower(COALESCE(v_data->>'action', ''));
    v_bulk_ids JSONB := COALESCE(v_data->'ids', '[]'::jsonb);
BEGIN
    SELECT *
    INTO v_entity
    FROM ui_entity_configs
    WHERE entity_key = v_entity_key
      AND is_enabled = TRUE
      AND deleted_at IS NULL;

    IF v_entity.id IS NULL THEN
        RETURN fn_error_envelope('e-unknown-entity', 404, 'Unknown entity key');
    END IF;

    IF NOT fn_runtime_is_admin(v_requested_by, v_role, v_permissions)
       AND v_entity.permission_slug IS NOT NULL
       AND v_entity.permission_slug <> ''
       AND NOT (
           v_permissions @> jsonb_build_array(v_entity.permission_slug)
           OR v_permissions @> jsonb_build_array(split_part(v_entity.permission_slug, ':', 1) || ':manage')
       ) THEN
        RETURN fn_error_envelope('e-forbidden', 403, 'Permission denied');
    END IF;

    v_table := v_entity.table_name;
    v_pk := COALESCE(v_entity.primary_key, 'id');
    v_offset := (v_page - 1) * v_limit;

    PERFORM set_config('crm.current_user_id', COALESCE(v_requested_by::text, '00000000-0000-0000-0000-000000000000'), true);

    CASE v_entity_key
        WHEN 'lead' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-leads-listed';
                WHEN 'get' THEN v_status_rid := 's-lead-retrieved';
                WHEN 'create' THEN v_status_rid := 's-lead-created';
                WHEN 'update' THEN v_status_rid := 's-lead-updated';
                WHEN 'delete' THEN v_status_rid := 's-lead-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-leads-bulk-updated';
            END CASE;
        WHEN 'contact' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-contacts-listed';
                WHEN 'get' THEN v_status_rid := 's-contact-retrieved';
                WHEN 'create' THEN v_status_rid := 's-contact-created';
                WHEN 'update' THEN v_status_rid := 's-contact-updated';
                WHEN 'delete' THEN v_status_rid := 's-contact-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-contacts-bulk-updated';
            END CASE;
        WHEN 'account' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-accounts-listed';
                WHEN 'get' THEN v_status_rid := 's-account-retrieved';
                WHEN 'create' THEN v_status_rid := 's-account-created';
                WHEN 'update' THEN v_status_rid := 's-account-updated';
                WHEN 'delete' THEN v_status_rid := 's-account-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-accounts-bulk-updated';
            END CASE;
        WHEN 'project' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-projects-listed';
                WHEN 'get' THEN v_status_rid := 's-project-loaded';
                WHEN 'create' THEN v_status_rid := 's-project-created';
                WHEN 'update' THEN v_status_rid := 's-project-updated';
                WHEN 'delete' THEN v_status_rid := 's-project-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-projects-bulk-updated';
            END CASE;
        WHEN 'task' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-tasks-listed';
                WHEN 'get' THEN v_status_rid := 's-task-retrieved';
                WHEN 'create' THEN v_status_rid := 's-task-created';
                WHEN 'update' THEN v_status_rid := 's-task-updated';
                WHEN 'delete' THEN v_status_rid := 's-task-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-tasks-bulk-updated';
            END CASE;
        WHEN 'communication' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-communications-listed';
                WHEN 'get' THEN v_status_rid := 's-communication-retrieved';
                WHEN 'create' THEN v_status_rid := 's-communication-created';
                WHEN 'update' THEN v_status_rid := 's-communication-updated';
                WHEN 'delete' THEN v_status_rid := 's-communication-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-communications-bulk-updated';
            END CASE;
        WHEN 'document' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-documents-listed';
                WHEN 'get' THEN v_status_rid := 's-document-retrieved';
                WHEN 'create' THEN v_status_rid := 's-document-created';
                WHEN 'update' THEN v_status_rid := 's-document-updated';
                WHEN 'delete' THEN v_status_rid := 's-document-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-documents-bulk-updated';
            END CASE;
        WHEN 'quotation' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-quotations-listed';
                WHEN 'get' THEN v_status_rid := 's-quotation-retrieved';
                WHEN 'create' THEN v_status_rid := 's-quotation-created';
                WHEN 'update' THEN v_status_rid := 's-quotation-updated';
                WHEN 'delete' THEN v_status_rid := 's-quotation-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-quotations-bulk-updated';
            END CASE;
        WHEN 'expense' THEN
            CASE v_operation
                WHEN 'list' THEN v_status_rid := 's-expenses-listed';
                WHEN 'get' THEN v_status_rid := 's-expense-retrieved';
                WHEN 'create' THEN v_status_rid := 's-expense-created';
                WHEN 'update' THEN v_status_rid := 's-expense-updated';
                WHEN 'delete' THEN v_status_rid := 's-expense-deleted';
                WHEN 'bulk' THEN v_status_rid := 's-expenses-bulk-updated';
            END CASE;
    END CASE;

    CASE v_operation
        WHEN 'list' THEN
            IF v_q IS NOT NULL AND v_entity.title_column IS NOT NULL THEN
                v_where := v_where || format(
                    ' AND (COALESCE(%1$I::text, '''') ILIKE %2$L OR COALESCE(%3$I::text, '''') ILIKE %2$L)',
                    v_entity.title_column,
                    '%' || v_q || '%',
                    v_pk
                );
            END IF;

            FOR v_field IN
                SELECT *
                FROM ui_field_configs
                WHERE entity_key = v_entity_key
                  AND is_filterable = TRUE
                  AND column_name IS NOT NULL
                  AND deleted_at IS NULL
            LOOP
                IF v_data ? v_field.field_key THEN
                    v_where := v_where || format(
                        ' AND %I = %s',
                        v_field.column_name,
                        fn_runtime_literal(v_data -> v_field.field_key, v_field.data_type)
                    );
                END IF;
            END LOOP;

            IF NULLIF(v_data->>'sortBy', '') IS NOT NULL THEN
                SELECT column_name
                INTO v_sort_column
                FROM ui_field_configs
                WHERE entity_key = v_entity_key
                  AND field_key = v_data->>'sortBy'
                  AND is_sortable = TRUE
                  AND deleted_at IS NULL
                LIMIT 1;
            END IF;

            v_sort_column := COALESCE(v_sort_column, v_entity.default_sort_column, v_entity.title_column, 'created_at');

            v_sql := format('SELECT COUNT(*) FROM %I WHERE %s', v_table, v_where);
            EXECUTE v_sql INTO v_total;

            v_sql := format(
                'SELECT COALESCE(jsonb_agg(fn_runtime_enrich_record(%L, to_jsonb(t))), ''[]''::jsonb)
                 FROM (
                     SELECT *
                     FROM %I
                     WHERE %s
                     ORDER BY %I %s
                     LIMIT %s OFFSET %s
                 ) t',
                v_entity_key,
                v_table,
                v_where,
                v_sort_column,
                v_sort_order,
                v_limit,
                v_offset
            );
            EXECUTE v_sql INTO v_rows;

            RETURN fn_runtime_success(
                v_status_rid,
                200,
                COALESCE(v_rows, '[]'::jsonb),
                'Operation successful',
                jsonb_build_object(
                    'page', v_page,
                    'limit', v_limit,
                    'total', v_total,
                    'totalPages', CASE WHEN v_total = 0 THEN 0 ELSE CEIL(v_total::numeric / v_limit)::int END
                )
            );

        WHEN 'get' THEN
            IF v_id IS NULL THEN
                RETURN fn_error_envelope('e-id-required', 400, 'Record id is required');
            END IF;

            v_sql := format(
                'SELECT to_jsonb(t) FROM %I t WHERE %I = $1::uuid AND deleted_at IS NULL',
                v_table,
                v_pk
            );
            EXECUTE v_sql INTO v_record USING v_id;

            IF v_record IS NULL THEN
                RETURN fn_error_envelope('e-record-not-found', 404, 'Record not found');
            END IF;

            RETURN fn_runtime_success(v_status_rid, 200, fn_runtime_enrich_record(v_entity_key, v_record));

        WHEN 'delete' THEN
            IF v_id IS NULL THEN
                RETURN fn_error_envelope('e-id-required', 400, 'Record id is required');
            END IF;

            v_sql := format(
                'UPDATE %I
                 SET deleted_at = NOW(), updated_at = NOW()
                 WHERE %I = $1::uuid AND deleted_at IS NULL',
                v_table,
                v_pk
            );
            EXECUTE v_sql USING v_id;

            v_sql := format('SELECT to_jsonb(t) FROM %I t WHERE %I = $1::uuid', v_table, v_pk);
            EXECUTE v_sql INTO v_record USING v_id;

            IF v_record IS NULL THEN
                RETURN fn_error_envelope('e-record-not-found', 404, 'Record not found');
            END IF;

            RETURN fn_runtime_success(v_status_rid, 200, v_record);

        WHEN 'bulk' THEN
            IF jsonb_typeof(v_bulk_ids) <> 'array' OR jsonb_array_length(v_bulk_ids) = 0 THEN
                RETURN fn_error_envelope('e-bulk-ids-required', 400, 'At least one id is required');
            END IF;

            IF v_action IN ('delete', 'archive') THEN
                v_sql := format(
                    'UPDATE %I
                     SET deleted_at = NOW(), updated_at = NOW()
                     WHERE %I IN (SELECT value::uuid FROM jsonb_array_elements_text($1::jsonb))
                       AND deleted_at IS NULL',
                    v_table,
                    v_pk
                );
                EXECUTE v_sql USING v_bulk_ids;
            ELSE
                FOR v_field IN
                    SELECT *
                    FROM ui_field_configs
                    WHERE entity_key = v_entity_key
                      AND include_in_update = TRUE
                      AND column_name IS NOT NULL
                      AND is_readonly = FALSE
                      AND deleted_at IS NULL
                LOOP
                    IF v_data ? v_field.field_key THEN
                        v_sets := array_append(
                            v_sets,
                            format('%I = %s', v_field.column_name, fn_runtime_literal(v_data -> v_field.field_key, v_field.data_type))
                        );
                    END IF;
                END LOOP;

                IF array_length(v_sets, 1) IS NULL THEN
                    RETURN fn_error_envelope('e-no-fields', 400, 'No update fields supplied for bulk operation');
                END IF;

                v_sets := array_append(v_sets, 'updated_at = NOW()');
                v_sql := format(
                    'UPDATE %I
                     SET %s
                     WHERE %I IN (SELECT value::uuid FROM jsonb_array_elements_text($1::jsonb))
                       AND deleted_at IS NULL',
                    v_table,
                    array_to_string(v_sets, ', '),
                    v_pk
                );
                EXECUTE v_sql USING v_bulk_ids;
            END IF;

            RETURN fn_runtime_success(
                v_status_rid,
                200,
                jsonb_build_object(
                    'ids', v_bulk_ids,
                    'action', COALESCE(NULLIF(v_action, ''), 'update')
                )
            );

        WHEN 'create' THEN
            FOR v_field IN
                SELECT *
                FROM ui_field_configs
                WHERE entity_key = v_entity_key
                  AND include_in_create = TRUE
                  AND column_name IS NOT NULL
                  AND deleted_at IS NULL
                ORDER BY sort_order, field_key
            LOOP
                IF v_data ? v_field.field_key AND array_position(v_columns, v_field.column_name) IS NULL THEN
                    v_columns := array_append(v_columns, v_field.column_name);
                    v_values := array_append(v_values, fn_runtime_literal(v_data -> v_field.field_key, v_field.data_type));
                ELSIF v_field.is_required
                  AND array_position(v_columns, v_field.column_name) IS NULL
                  AND (v_field.default_value_json IS NULL OR v_field.default_value_json = 'null'::jsonb) THEN
                    RETURN fn_error_envelope('e-required-field-missing', 400, format('Missing required field: %s', v_field.field_key));
                END IF;
            END LOOP;

            IF v_entity_key = 'lead' THEN
                IF array_position(v_columns, 'lead_number') IS NULL THEN
                    v_columns := array_append(v_columns, 'lead_number');
                    v_values := array_append(v_values, 'generate_lead_number()');
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''new''::lead_status');
                END IF;
                IF array_position(v_columns, 'source') IS NULL THEN
                    v_columns := array_append(v_columns, 'source');
                    v_values := array_append(v_values, '''other''::lead_source');
                END IF;
                IF array_position(v_columns, 'assigned_to') IS NULL AND NULLIF(v_data->>'ownerId', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'assigned_to');
                    v_values := array_append(v_values, format('%L::uuid', v_data->>'ownerId'));
                END IF;
                IF array_position(v_columns, 'follow_up_at') IS NULL AND NULLIF(v_data->>'nextFollowUpAt', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'follow_up_at');
                    v_values := array_append(v_values, format('%L::timestamptz', v_data->>'nextFollowUpAt'));
                END IF;
            ELSIF v_entity_key = 'project' THEN
                IF array_position(v_columns, 'project_number') IS NULL THEN
                    v_columns := array_append(v_columns, 'project_number');
                    v_values := array_append(v_values, 'generate_project_number()');
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''planning''::project_status');
                END IF;
                IF array_position(v_columns, 'estimated_value') IS NULL AND NULLIF(v_data->>'budget', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'estimated_value');
                    v_values := array_append(v_values, format('%L::numeric', v_data->>'budget'));
                END IF;
            ELSIF v_entity_key = 'task' THEN
                IF array_position(v_columns, 'task_number') IS NULL THEN
                    v_columns := array_append(v_columns, 'task_number');
                    v_values := array_append(v_values, 'generate_task_number()');
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''todo''::task_status');
                END IF;
                IF array_position(v_columns, 'priority') IS NULL THEN
                    v_columns := array_append(v_columns, 'priority');
                    v_values := array_append(v_values, '''medium''::task_priority');
                END IF;
                IF array_position(v_columns, 'reporter_id') IS NULL AND v_requested_by IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'reporter_id');
                    v_values := array_append(v_values, format('%L::uuid', v_requested_by::text));
                END IF;
            ELSIF v_entity_key = 'quotation' THEN
                IF array_position(v_columns, 'quotation_number') IS NULL THEN
                    v_columns := array_append(v_columns, 'quotation_number');
                    v_values := array_append(v_values, 'generate_quotation_number()');
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''draft''::quotation_status');
                END IF;
                IF array_position(v_columns, 'created_by') IS NULL AND v_requested_by IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'created_by');
                    v_values := array_append(v_values, format('%L::uuid', v_requested_by::text));
                END IF;
            ELSIF v_entity_key = 'expense' THEN
                IF array_position(v_columns, 'logged_by') IS NULL AND v_requested_by IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'logged_by');
                    v_values := array_append(v_values, format('%L::uuid', v_requested_by::text));
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''submitted''');
                END IF;
            ELSIF v_entity_key = 'communication' THEN
                IF array_position(v_columns, 'performed_by') IS NULL AND v_requested_by IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'performed_by');
                    v_values := array_append(v_values, format('%L::uuid', v_requested_by::text));
                END IF;
                IF array_position(v_columns, 'performed_at') IS NULL THEN
                    v_columns := array_append(v_columns, 'performed_at');
                    v_values := array_append(v_values, COALESCE(
                        CASE WHEN NULLIF(v_data->>'occurredAt', '') IS NOT NULL THEN format('%L::timestamptz', v_data->>'occurredAt') END,
                        'NOW()'
                    ));
                END IF;
                IF array_position(v_columns, 'type') IS NULL THEN
                    v_columns := array_append(v_columns, 'type');
                    v_values := array_append(v_values, COALESCE(
                        CASE
                            WHEN NULLIF(v_data->>'channel', '') IS NOT NULL THEN format('%L::communication_type', v_data->>'channel')
                            WHEN NULLIF(v_data->>'type', '') IS NOT NULL THEN format('%L::communication_type', v_data->>'type')
                        END,
                        '''other''::communication_type'
                    ));
                END IF;
                IF array_position(v_columns, 'module_name') IS NULL AND NULLIF(v_data->>'entityType', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'module_name');
                    v_values := array_append(v_values, format('%L', v_data->>'entityType'));
                END IF;
                IF array_position(v_columns, 'content') IS NULL AND NULLIF(v_data->>'summary', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'content');
                    v_values := array_append(v_values, format('%L', v_data->>'summary'));
                END IF;
            ELSIF v_entity_key = 'document' THEN
                IF array_position(v_columns, 'uploaded_by') IS NULL AND v_requested_by IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'uploaded_by');
                    v_values := array_append(v_values, format('%L::uuid', v_requested_by::text));
                END IF;
                IF array_position(v_columns, 'status') IS NULL THEN
                    v_columns := array_append(v_columns, 'status');
                    v_values := array_append(v_values, '''draft''::document_status');
                END IF;
                IF array_position(v_columns, 'version') IS NULL THEN
                    v_columns := array_append(v_columns, 'version');
                    v_values := array_append(v_values, '1');
                END IF;
                IF array_position(v_columns, 'version_number') IS NULL THEN
                    v_columns := array_append(v_columns, 'version_number');
                    v_values := array_append(v_values, '1');
                END IF;
                IF array_position(v_columns, 'version_label') IS NULL THEN
                    v_columns := array_append(v_columns, 'version_label');
                    v_values := array_append(v_values, '''v1''');
                END IF;
                IF array_position(v_columns, 'module_name') IS NULL AND NULLIF(v_data->>'entityType', '') IS NOT NULL THEN
                    v_columns := array_append(v_columns, 'module_name');
                    v_values := array_append(v_values, format('%L', v_data->>'entityType'));
                END IF;
            END IF;

            IF array_length(v_columns, 1) IS NULL THEN
                RETURN fn_error_envelope('e-no-fields', 400, 'No fields supplied for create');
            END IF;

            v_sql := format(
                'INSERT INTO %I (%s) VALUES (%s) RETURNING %I',
                v_table,
                array_to_string(ARRAY(SELECT format('%I', c) FROM unnest(v_columns) AS c), ', '),
                array_to_string(v_values, ', '),
                v_pk
            );
            EXECUTE v_sql INTO v_generated_id;

            IF v_entity_key = 'task' THEN
                PERFORM fn_sync_task_dependencies(v_generated_id, v_dependency_ids);
                PERFORM fn_sync_task_watchers(v_generated_id, v_watcher_ids);
            ELSIF v_entity_key = 'quotation' THEN
                v_total_amount := fn_sync_quotation_items(v_generated_id, v_line_items);
                UPDATE quotations
                SET subtotal_amount = v_total_amount,
                    total_amount = v_total_amount - COALESCE(discount, 0) + COALESCE(tax_amount, 0),
                    updated_at = NOW()
                WHERE id = v_generated_id;
            ELSIF v_entity_key = 'document' THEN
                INSERT INTO document_versions (
                    document_id, version_no, version_label, file_name, file_path, file_type, file_size, status, uploaded_by
                )
                SELECT
                    d.id,
                    COALESCE(d.version_number, 1),
                    COALESCE(d.version_label, 'v1'),
                    d.file_name,
                    d.file_path,
                    d.file_type,
                    d.file_size,
                    d.status,
                    d.uploaded_by
                FROM documents d
                WHERE d.id = v_generated_id
                  AND NOT EXISTS (
                      SELECT 1
                      FROM document_versions dv
                      WHERE dv.document_id = d.id
                        AND dv.version_no = COALESCE(d.version_number, 1)
                        AND dv.deleted_at IS NULL
                  );
            END IF;

            PERFORM fn_sync_record_tags(v_entity_key, v_generated_id, v_tags, v_requested_by);
            PERFORM fn_upsert_custom_field_values(v_entity_key, v_generated_id, v_custom_fields);

            v_sql := format('SELECT to_jsonb(t) FROM %I t WHERE %I = $1::uuid', v_table, v_pk);
            EXECUTE v_sql INTO v_record USING v_generated_id;

            RETURN fn_runtime_success(v_status_rid, 201, fn_runtime_enrich_record(v_entity_key, v_record));

        WHEN 'update' THEN
            IF v_id IS NULL THEN
                RETURN fn_error_envelope('e-id-required', 400, 'Record id is required');
            END IF;

            FOR v_field IN
                SELECT *
                FROM ui_field_configs
                WHERE entity_key = v_entity_key
                  AND include_in_update = TRUE
                  AND column_name IS NOT NULL
                  AND is_readonly = FALSE
                  AND deleted_at IS NULL
                ORDER BY sort_order, field_key
            LOOP
                IF v_data ? v_field.field_key AND array_position(v_sets, format('%I', v_field.column_name)) IS NULL THEN
                    v_sets := array_append(
                        v_sets,
                        format('%I = %s', v_field.column_name, fn_runtime_literal(v_data -> v_field.field_key, v_field.data_type))
                    );
                END IF;
            END LOOP;

            IF v_entity_key = 'lead' AND NULLIF(v_data->>'nextFollowUpAt', '') IS NOT NULL THEN
                v_sets := array_append(v_sets, format('follow_up_at = %L::timestamptz', v_data->>'nextFollowUpAt'));
            ELSIF v_entity_key = 'project' AND NULLIF(v_data->>'budget', '') IS NOT NULL THEN
                v_sets := array_append(v_sets, format('estimated_value = %L::numeric', v_data->>'budget'));
            END IF;

            IF array_length(v_sets, 1) IS NOT NULL THEN
                v_sets := array_append(v_sets, 'updated_at = NOW()');
                v_sql := format(
                    'UPDATE %I SET %s WHERE %I = $1::uuid AND deleted_at IS NULL',
                    v_table,
                    array_to_string(v_sets, ', '),
                    v_pk
                );
                EXECUTE v_sql USING v_id;
            END IF;

            v_sql := format('SELECT to_jsonb(t) FROM %I t WHERE %I = $1::uuid AND deleted_at IS NULL', v_table, v_pk);
            EXECUTE v_sql INTO v_record USING v_id;

            IF v_record IS NULL THEN
                RETURN fn_error_envelope('e-record-not-found', 404, 'Record not found');
            END IF;

            IF v_entity_key = 'task' THEN
                PERFORM fn_sync_task_dependencies(v_id, v_dependency_ids);
                PERFORM fn_sync_task_watchers(v_id, v_watcher_ids);
            ELSIF v_entity_key = 'quotation' AND v_line_items IS NOT NULL THEN
                v_total_amount := fn_sync_quotation_items(v_id, v_line_items);
                UPDATE quotations
                SET subtotal_amount = v_total_amount,
                    total_amount = v_total_amount - COALESCE(discount, 0) + COALESCE(tax_amount, 0),
                    updated_at = NOW()
                WHERE id = v_id;
            END IF;

            IF v_tags IS NOT NULL THEN
                PERFORM fn_sync_record_tags(v_entity_key, v_id, v_tags, v_requested_by);
            END IF;
            IF v_custom_fields IS NOT NULL THEN
                PERFORM fn_upsert_custom_field_values(v_entity_key, v_id, v_custom_fields);
            END IF;

            v_sql := format('SELECT to_jsonb(t) FROM %I t WHERE %I = $1::uuid AND deleted_at IS NULL', v_table, v_pk);
            EXECUTE v_sql INTO v_record USING v_id;

            RETURN fn_runtime_success(v_status_rid, 200, fn_runtime_enrich_record(v_entity_key, v_record));
        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid data operation');
    END CASE;
END;
$$;
