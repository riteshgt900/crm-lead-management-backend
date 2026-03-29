SET search_path = crm, public;

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
                )
                || jsonb_build_object(
                    'subtotal', COALESCE((v_result->>'subtotal_amount')::numeric, 0),
                    'tax', COALESCE((v_result->>'tax_amount')::numeric, 0),
                    'discountValue', COALESCE((v_result->>'discount')::numeric, 0),
                    'total', COALESCE((v_result->>'total_amount')::numeric, 0)
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
