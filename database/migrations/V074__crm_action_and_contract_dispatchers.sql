SET search_path = crm, public;

CREATE OR REPLACE FUNCTION fn_action_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = crm, public
AS $$
DECLARE
    v_action_key TEXT := lower(COALESCE(p_payload->>'actionKey', p_payload->'data'->>'actionKey', ''));
    v_data JSONB := COALESCE(p_payload->'data', '{}'::jsonb);
    v_requested_by UUID := NULLIF(p_payload->>'requestedBy', '')::uuid;
    v_id UUID := NULLIF(COALESCE(v_data->>'id', v_data->>'documentId', v_data->>'leadId'), '')::uuid;
    v_template_id UUID := NULLIF(v_data->>'templateId', '')::uuid;
    v_res JSONB;
    v_lead RECORD;
    v_project_id UUID;
    v_account_id UUID;
    v_contact_id UUID;
    v_document RECORD;
    v_parent_document RECORD;
    v_version_no INT := 1;
    v_share_token TEXT;
BEGIN
    PERFORM set_config('crm.current_user_id', COALESCE(v_requested_by::text, '00000000-0000-0000-0000-000000000000'), true);

    CASE v_action_key
        WHEN 'lead.update_status' THEN
            SELECT *
            INTO v_lead
            FROM leads
            WHERE id = v_id
              AND deleted_at IS NULL
            FOR UPDATE;

            IF v_lead.id IS NULL THEN
                RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found');
            END IF;

            UPDATE leads
            SET status = COALESCE(NULLIF(v_data->>'status', '')::lead_status, v_lead.status),
                last_activity_at = NOW(),
                updated_at = NOW()
            WHERE id = v_lead.id;

            INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, reason)
            VALUES (
                v_lead.id,
                v_lead.status,
                COALESCE(NULLIF(v_data->>'status', '')::lead_status, v_lead.status),
                v_requested_by,
                NULLIF(v_data->>'reason', '')
            );

            PERFORM fn_trigger_workflow('status_changed', v_lead.id);
            RETURN fn_runtime_success('s-lead-status-updated', 200, jsonb_build_object('id', v_lead.id));

        WHEN 'lead.convert' THEN
            SELECT *
            INTO v_lead
            FROM leads
            WHERE id = v_id
              AND deleted_at IS NULL
            FOR UPDATE;

            IF v_lead.id IS NULL THEN
                RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found');
            END IF;

            v_contact_id := COALESCE(v_lead.primary_contact_id, v_lead.contact_id);
            IF v_contact_id IS NULL THEN
                RETURN fn_error_envelope('e-contact-required', 400, 'A contact must be assigned before conversion.');
            END IF;

            v_account_id := v_lead.account_id;
            IF v_account_id IS NULL THEN
                SELECT account_id INTO v_account_id FROM contacts WHERE id = v_contact_id;
            END IF;

            IF v_account_id IS NULL THEN
                INSERT INTO accounts (name, type, owner_id, notes)
                VALUES (
                    COALESCE(NULLIF(v_data->>'accountName', ''), COALESCE(v_lead.title, 'Converted Account')),
                    'company',
                    COALESCE(v_lead.owner_id, v_lead.assigned_to, v_requested_by),
                    'Auto-created during lead conversion'
                )
                RETURNING id INTO v_account_id;
            END IF;

            INSERT INTO projects (
                project_number,
                title,
                description,
                lead_id,
                contact_id,
                account_id,
                template_id,
                project_type,
                status,
                project_manager_id,
                estimated_value,
                budget,
                start_date
            )
            VALUES (
                generate_project_number(),
                COALESCE(NULLIF(v_data->>'title', ''), 'Project for: ' || v_lead.title),
                COALESCE(NULLIF(v_data->>'description', ''), v_lead.description),
                v_lead.id,
                v_contact_id,
                v_account_id,
                v_template_id,
                COALESCE(NULLIF(v_data->>'projectType', ''), NULLIF(v_lead.category, ''), 'implementation'),
                'planning',
                COALESCE(v_lead.owner_id, v_lead.assigned_to, v_requested_by),
                COALESCE(v_lead.estimated_value, v_lead.budget_max),
                COALESCE(v_lead.budget_max, v_lead.estimated_value),
                NOW()
            )
            RETURNING id INTO v_project_id;

            INSERT INTO project_stakeholders (project_id, account_id, contact_id, role_key, is_primary)
            VALUES (v_project_id, v_account_id, v_contact_id, 'primary_contact', TRUE)
            ON CONFLICT DO NOTHING;

            IF v_template_id IS NOT NULL THEN
                SELECT fn_clone_project_template(v_project_id, v_template_id) INTO v_res;
            ELSE
                v_res := '{}'::jsonb;
            END IF;

            UPDATE leads
            SET status = 'converted',
                converted_at = NOW(),
                account_id = v_account_id,
                primary_contact_id = v_contact_id,
                last_activity_at = NOW(),
                updated_at = NOW()
            WHERE id = v_lead.id;

            PERFORM fn_trigger_workflow('lead_converted', v_lead.id);

            RETURN fn_runtime_success(
                's-lead-converted',
                201,
                jsonb_build_object(
                    'leadId', v_lead.id,
                    'projectId', v_project_id,
                    'accountId', v_account_id,
                    'template', COALESCE(v_res, '{}'::jsonb)
                )
            );

        WHEN 'document.upload' THEN
            IF NULLIF(v_data->>'parentDocumentId', '') IS NOT NULL THEN
                SELECT *
                INTO v_parent_document
                FROM documents
                WHERE id = NULLIF(v_data->>'parentDocumentId', '')::uuid
                FOR UPDATE;

                SELECT COALESCE(MAX(version_no), 0) + 1
                INTO v_version_no
                FROM document_versions
                WHERE document_id = v_parent_document.id
                  AND deleted_at IS NULL;
            ELSE
                v_version_no := 1;
            END IF;

            INSERT INTO documents (
                title,
                file_name,
                file_path,
                file_type,
                file_size,
                module_name,
                entity_type,
                entity_id,
                category,
                status,
                version,
                version_number,
                version_label,
                uploaded_by,
                parent_document_id,
                approval_required,
                share_mode
            )
            VALUES (
                COALESCE(NULLIF(v_data->>'title', ''), NULLIF(v_data->>'originalName', ''), 'Uploaded Document'),
                COALESCE(NULLIF(v_data->>'fileName', ''), NULLIF(v_data#>>'{file,filename}', ''), NULLIF(v_data#>>'{file,originalName}', ''), 'document.bin'),
                COALESCE(NULLIF(v_data->>'filePath', ''), NULLIF(v_data#>>'{file,path}', '')),
                COALESCE(NULLIF(v_data->>'fileType', ''), NULLIF(v_data#>>'{file,mimetype}', ''), 'application/octet-stream'),
                COALESCE(NULLIF(v_data->>'fileSize', '')::bigint, NULLIF(v_data#>>'{file,size}', '')::bigint, 0),
                COALESCE(NULLIF(v_data->>'moduleName', ''), NULLIF(v_data->>'entityType', ''), 'documents'),
                COALESCE(NULLIF(v_data->>'entityType', ''), NULLIF(v_data->>'moduleName', ''), 'documents'),
                NULLIF(v_data->>'entityId', '')::uuid,
                NULLIF(v_data->>'category', ''),
                'draft',
                v_version_no,
                v_version_no,
                COALESCE(NULLIF(v_data->>'versionLabel', ''), 'v' || v_version_no::text),
                v_requested_by,
                NULLIF(v_data->>'parentDocumentId', '')::uuid,
                COALESCE(NULLIF(v_data->>'approvalRequired', '')::boolean, FALSE),
                COALESCE(NULLIF(v_data->>'shareMode', ''), 'internal')
            )
            RETURNING * INTO v_document;

            INSERT INTO document_versions (
                document_id,
                version_no,
                version_label,
                file_name,
                file_path,
                file_type,
                file_size,
                status,
                uploaded_by
            )
            VALUES (
                v_document.id,
                v_version_no,
                COALESCE(v_document.version_label, 'v' || v_version_no::text),
                v_document.file_name,
                v_document.file_path,
                v_document.file_type,
                v_document.file_size,
                v_document.status,
                v_requested_by
            );

            RETURN fn_runtime_success('s-document-uploaded', 201, fn_runtime_enrich_record('document', to_jsonb(v_document)));

        WHEN 'document.approve' THEN
            SELECT *
            INTO v_document
            FROM documents
            WHERE id = v_id
              AND deleted_at IS NULL
            FOR UPDATE;

            IF v_document.id IS NULL THEN
                RETURN fn_error_envelope('e-document-not-found', 404, 'Document not found');
            END IF;

            UPDATE documents
            SET status = CASE
                    WHEN lower(COALESCE(v_data->>'decision', 'approved')) = 'rejected' THEN 'rejected'::document_status
                    ELSE 'approved'::document_status
                END,
                approved_by = COALESCE(v_requested_by, approved_by),
                approved_at = NOW(),
                version_label = COALESCE(NULLIF(v_data->>'versionLabel', ''), version_label),
                updated_at = NOW()
            WHERE id = v_document.id;

            UPDATE document_versions
            SET status = CASE
                    WHEN lower(COALESCE(v_data->>'decision', 'approved')) = 'rejected' THEN 'rejected'::document_status
                    ELSE 'approved'::document_status
                END,
                approved_by = COALESCE(v_requested_by, approved_by),
                approved_at = NOW(),
                updated_at = NOW()
            WHERE document_id = v_document.id
              AND version_no = COALESCE(v_document.version_number, 1)
              AND deleted_at IS NULL;

            SELECT to_jsonb(d) INTO v_res FROM documents d WHERE d.id = v_document.id;
            RETURN fn_runtime_success('s-document-approved', 200, fn_runtime_enrich_record('document', v_res));

        WHEN 'document.share' THEN
            v_share_token := gen_random_uuid()::text;
            INSERT INTO document_shares (document_id, shared_with_email, access_token, expires_at)
            VALUES (
                v_id,
                COALESCE(NULLIF(v_data->>'email', ''), 'external@shared.local'),
                v_share_token,
                COALESCE(NULLIF(v_data->>'expiresAt', '')::timestamptz, NOW() + INTERVAL '7 days')
            );

            RETURN fn_runtime_success(
                's-document-shared',
                201,
                jsonb_build_object(
                    'documentId', v_id,
                    'token', v_share_token,
                    'expiresAt', COALESCE(NULLIF(v_data->>'expiresAt', '')::timestamptz, NOW() + INTERVAL '7 days')
                )
            );

        WHEN 'share.resolve' THEN
            SELECT jsonb_build_object(
                'document', fn_runtime_enrich_record('document', to_jsonb(d)),
                'share', jsonb_build_object(
                    'documentId', ds.document_id,
                    'sharedWithEmail', ds.shared_with_email,
                    'expiresAt', ds.expires_at
                )
            )
            INTO v_res
            FROM document_shares ds
            JOIN documents d ON d.id = ds.document_id
            WHERE ds.access_token = COALESCE(NULLIF(v_data->>'accessToken', ''), NULLIF(v_data->>'token', ''))
              AND (ds.expires_at IS NULL OR ds.expires_at > NOW());

            IF v_res IS NULL THEN
                RETURN fn_error_envelope('e-share-not-found', 404, 'Share token is invalid or expired');
            END IF;

            RETURN fn_runtime_success('s-share-resolved', 200, v_res);

        WHEN 'dashboard.stats' THEN
            SELECT jsonb_build_object(
                'leads', (
                    SELECT jsonb_object_agg(status::text, cnt)
                    FROM (
                        SELECT status, COUNT(*)::int AS cnt
                        FROM leads
                        WHERE deleted_at IS NULL
                        GROUP BY status
                    ) AS src
                ),
                'projects', (SELECT COUNT(*)::int FROM projects WHERE deleted_at IS NULL AND status = 'active'),
                'revenue', (SELECT COALESCE(SUM(total_amount), 0) FROM quotations WHERE deleted_at IS NULL AND status = 'accepted'),
                'tasksPending', (SELECT COUNT(*)::int FROM tasks WHERE deleted_at IS NULL AND status IN ('todo', 'in_progress')),
                'accounts', (SELECT COUNT(*)::int FROM accounts WHERE deleted_at IS NULL)
            )
            INTO v_res;

            RETURN fn_runtime_success('s-dashboard-stats', 200, v_res);

        WHEN 'workflow.run_due' THEN
            SELECT fn_escalate_overdue_tasks() INTO v_res;
            RETURN fn_runtime_success('s-workflows-run', 200, COALESCE(v_res, '{}'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid action operation');
    END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_contract_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = crm, public
AS $$
DECLARE
    v_op TEXT := lower(COALESCE(p_payload->>'operation', 'frontend_contract'));
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'frontend_contract', 'export_contract' THEN
            SELECT jsonb_build_object(
                'generatedAt', NOW(),
                'auth', jsonb_build_object(
                    'strategy', 'cookie',
                    'cookieName', 'crm_session',
                    'withCredentials', TRUE
                ),
                'endpoints', COALESCE((
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'endpointKey', aer.endpoint_key,
                            'entityKey', aer.entity_key,
                            'actionKey', aer.action_key,
                            'method', aer.http_method,
                            'route', aer.route_path,
                            'authMode', aer.auth_mode,
                            'isPublic', aer.is_public,
                            'permissionSlug', aer.permission_slug,
                            'dispatcherFn', aer.dispatcher_fn,
                            'formKey', aer.form_key,
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
                'entities', COALESCE((
                    SELECT jsonb_agg(fn_runtime_entity_spec(e.entity_key) ORDER BY e.entity_key)
                    FROM ui_entity_configs e
                    WHERE e.is_enabled = TRUE
                      AND e.deleted_at IS NULL
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
                            'definition', rd.definition_json
                        )
                        ORDER BY rd.report_key
                    )
                    FROM report_definitions rd
                    WHERE rd.deleted_at IS NULL
                      AND rd.is_enabled = TRUE
                ), '[]'::jsonb)
            )
            INTO v_res;

            RETURN fn_runtime_success('s-frontend-contract', 200, v_res);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid contract operation');
    END CASE;
END;
$$;
