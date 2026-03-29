SET search_path = crm, public;

CREATE OR REPLACE FUNCTION fn_runtime_entity_spec(p_entity_key TEXT)
RETURNS JSONB
LANGUAGE sql
AS $$
    SELECT jsonb_build_object(
        'entityKey', e.entity_key,
        'label', e.label,
        'tableName', e.table_name,
        'primaryKey', e.primary_key,
        'titleColumn', e.title_column,
        'defaultSortColumn', e.default_sort_column,
        'permissionSlug', e.permission_slug,
        'formKey', e.form_key,
        'routeBase', e.route_base,
        'supportsTags', e.supports_tags,
        'supportsCustomFields', e.supports_custom_fields,
        'samplePayload', e.sample_payload_json,
        'metadata', e.metadata,
        'fields', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'fieldKey', f.field_key,
                    'label', f.label,
                    'columnName', f.column_name,
                    'dataType', f.data_type,
                    'sortOrder', f.sort_order,
                    'isRequired', f.is_required,
                    'isFilterable', f.is_filterable,
                    'isSortable', f.is_sortable,
                    'isReadonly', f.is_readonly,
                    'includeInList', f.include_in_list,
                    'includeInDetail', f.include_in_detail,
                    'includeInCreate', f.include_in_create,
                    'includeInUpdate', f.include_in_update,
                    'lookupSetKey', f.lookup_set_key,
                    'defaultValue', f.default_value_json,
                    'sampleValue', f.sample_value_json,
                    'config', f.config_json
                )
                ORDER BY f.sort_order, f.field_key
            )
            FROM ui_field_configs f
            WHERE f.entity_key = e.entity_key
              AND f.deleted_at IS NULL
        ), '[]'::jsonb),
        'filters', COALESCE((
            SELECT jsonb_agg(f.field_key ORDER BY f.sort_order, f.field_key)
            FROM ui_field_configs f
            WHERE f.entity_key = e.entity_key
              AND f.is_filterable = TRUE
              AND f.deleted_at IS NULL
        ), '[]'::jsonb)
    )
    FROM ui_entity_configs e
    WHERE e.entity_key = p_entity_key
      AND e.is_enabled = TRUE
      AND e.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_metadata_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = crm, public
AS $$
DECLARE
    v_op TEXT := lower(COALESCE(p_payload->>'operation', 'bootstrap'));
    v_data JSONB := COALESCE(p_payload->'data', '{}'::jsonb);
    v_entity_key TEXT := COALESCE(NULLIF(v_data->>'entityKey', ''), NULLIF(p_payload->>'entityKey', ''));
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'bootstrap' THEN
            SELECT jsonb_build_object(
                'app', jsonb_build_object(
                    'name', 'CRM Runtime',
                    'version', '1.0',
                    'noRedeployContract', TRUE
                ),
                'entities', COALESCE((
                    SELECT jsonb_agg(fn_runtime_entity_spec(e.entity_key) ORDER BY e.entity_key)
                    FROM ui_entity_configs e
                    WHERE e.is_enabled = TRUE
                      AND e.deleted_at IS NULL
                ), '[]'::jsonb),
                'endpoints', COALESCE((
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'endpointKey', aer.endpoint_key,
                            'entityKey', aer.entity_key,
                            'actionKey', aer.action_key,
                            'dispatcherFn', aer.dispatcher_fn,
                            'permissionSlug', aer.permission_slug,
                            'formKey', aer.form_key,
                            'httpMethod', aer.http_method,
                            'routePath', aer.route_path,
                            'authMode', aer.auth_mode,
                            'isPublic', aer.is_public,
                            'requestSchema', aer.request_schema_json,
                            'responseSchema', aer.response_schema_json,
                            'filterSchema', aer.filter_schema_json,
                            'samplePayload', aer.sample_payload_json,
                            'metadata', aer.metadata
                        )
                        ORDER BY aer.endpoint_key
                    )
                    FROM api_endpoint_registry aer
                    WHERE aer.is_enabled = TRUE
                      AND aer.deleted_at IS NULL
                ), '[]'::jsonb),
                'lookups', COALESCE((
                    SELECT jsonb_object_agg(src.set_key, src.payload)
                    FROM (
                        SELECT
                            ls.set_key,
                            COALESCE(
                                jsonb_agg(
                                    jsonb_build_object(
                                        'key', lv.value_key,
                                        'label', lv.label,
                                        'value', lv.value_json,
                                        'color', lv.color,
                                        'sortOrder', lv.sort_order,
                                        'isDefault', lv.is_default
                                    )
                                    ORDER BY lv.sort_order, lv.label
                                ),
                                '[]'::jsonb
                            ) AS payload
                        FROM lookup_sets ls
                        LEFT JOIN lookup_values lv
                          ON lv.set_id = ls.id
                         AND lv.deleted_at IS NULL
                         AND lv.is_enabled = TRUE
                        WHERE ls.deleted_at IS NULL
                          AND ls.is_enabled = TRUE
                        GROUP BY ls.set_key
                    ) AS src
                ), '{}'::jsonb),
                'reports', COALESCE((
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'reportKey', rd.report_key,
                            'label', rd.label,
                            'description', rd.description,
                            'isMaterialized', rd.is_materialized,
                            'scheduleCron', rd.schedule_cron,
                            'definition', rd.definition_json
                        )
                        ORDER BY rd.report_key
                    )
                    FROM report_definitions rd
                    WHERE rd.deleted_at IS NULL
                      AND rd.is_enabled = TRUE
                ), '[]'::jsonb)
            ) INTO v_res;

            RETURN fn_runtime_success('s-meta-bootstrap', 200, v_res);

        WHEN 'list_entities' THEN
            SELECT COALESCE(
                jsonb_agg(fn_runtime_entity_spec(e.entity_key) ORDER BY e.entity_key),
                '[]'::jsonb
            )
            INTO v_res
            FROM ui_entity_configs e
            WHERE e.is_enabled = TRUE
              AND e.deleted_at IS NULL;

            RETURN fn_runtime_success('s-meta-entities-listed', 200, v_res);

        WHEN 'get_entity' THEN
            SELECT fn_runtime_entity_spec(v_entity_key) INTO v_res;

            IF v_res IS NULL THEN
                RETURN fn_error_envelope('e-unknown-entity', 404, 'Unknown entity key');
            END IF;

            RETURN fn_runtime_success('s-meta-entity-loaded', 200, v_res);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid metadata operation');
    END CASE;
END;
$$;
