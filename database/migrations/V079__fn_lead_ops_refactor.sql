SET search_path = crm, public;

-- V079: fn_lead_operations Refactor
-- Breaking changes:
--   - `convert_lead` now produces an Opportunity (not a Project)
--   - Lead creation uses Assignment Pools if configured
--   - New operations: assign_lead, list_my_leads, claim_lead (pool pick)

CREATE OR REPLACE FUNCTION fn_lead_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op     TEXT := p_payload->>'operation';
    v_data   JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res    JSONB;
    v_lead   RECORD;
    v_new_lead_id UUID;
    v_new_opp_id  UUID;
    v_account_id  UUID;
    v_contact_id  UUID;
    v_pool        RECORD;
    v_next_user   RECORD;
    v_member_count INT;
    v_new_index   INT;
    v_search TEXT := v_data->>'q';
    v_status TEXT := v_data->>'status';
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op

    -- ──────────────────────────────────────────
    -- LIST LEADS
    -- ──────────────────────────────────────────
    WHEN 'list_leads' THEN
        SELECT jsonb_agg(row_to_json(l)) INTO v_res FROM (
            SELECT
                l.id, l.lead_number, l.title, l.description,
                l.status, l.source, l.stage, l.category,
                l.estimated_value, l.probability,
                l.expected_close_at, l.next_follow_up_at,
                l.email, l.phone,
                l.assigned_to, u.full_name AS assigned_to_name,
                l.owner_id, ow.full_name AS owner_name,
                l.account_id, a.name AS account_name,
                l.contact_id, c.first_name || ' ' || c.last_name AS contact_name,
                l.converted_opportunity_id,
                l.converted_at,
                l.last_activity_at,
                l.created_at, l.updated_at
            FROM leads l
            LEFT JOIN users u  ON l.assigned_to = u.id
            LEFT JOIN users ow ON l.owner_id = ow.id
            LEFT JOIN accounts a ON l.account_id = a.id
            LEFT JOIN contacts c ON l.contact_id = c.id
            WHERE l.deleted_at IS NULL
              AND (v_search IS NULL OR
                   l.title    ILIKE '%' || fn_escape_like(v_search) || '%' OR
                   l.email    ILIKE '%' || fn_escape_like(v_search) || '%' OR
                   l.phone    ILIKE '%' || fn_escape_like(v_search) || '%')
              AND (v_status IS NULL OR l.status::TEXT = v_status)
              AND (
                  (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                  OR l.assigned_to = v_req_by
                  OR l.owner_id    = v_req_by
                  OR l.assigned_to IS NULL
              )
            ORDER BY l.created_at DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) l;
        RETURN jsonb_build_object('rid', 's-leads-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- GET LEAD
    -- ──────────────────────────────────────────
    WHEN 'get_lead' THEN
        SELECT row_to_json(l) INTO v_res FROM (
            SELECT
                l.*,
                u.full_name  AS assigned_to_name,
                ow.full_name AS owner_name,
                a.name       AS account_name,
                c.first_name || ' ' || c.last_name AS contact_name,
                (SELECT jsonb_agg(row_to_json(sh)) FROM lead_status_history sh WHERE sh.lead_id = l.id ORDER BY sh.created_at DESC) AS status_history,
                (SELECT jsonb_agg(row_to_json(ah)) FROM assignment_history ah WHERE ah.entity_type = 'lead' AND ah.entity_id = l.id ORDER BY ah.assigned_at DESC) AS assignment_history,
                (SELECT jsonb_agg(row_to_json(nt)) FROM notes nt WHERE nt.entity_type = 'lead' AND nt.entity_id = l.id AND nt.deleted_at IS NULL ORDER BY nt.is_pinned DESC, nt.created_at DESC) AS notes,
                (SELECT jsonb_agg(row_to_json(ac)) FROM activities ac WHERE ac.entity_type = 'lead' AND ac.entity_id = l.id AND ac.deleted_at IS NULL ORDER BY ac.activity_date DESC LIMIT 20) AS activities
            FROM leads l
            LEFT JOIN users u  ON l.assigned_to = u.id
            LEFT JOIN users ow ON l.owner_id = ow.id
            LEFT JOIN accounts a ON l.account_id = a.id
            LEFT JOIN contacts c ON l.contact_id = c.id
            WHERE l.id = (v_data->>'id')::UUID AND l.deleted_at IS NULL
        ) l;
        IF v_res IS NULL THEN
            RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found');
        END IF;
        RETURN jsonb_build_object('rid', 's-lead-loaded', 'statusCode', 200, 'data', v_res);

    -- ──────────────────────────────────────────
    -- CREATE LEAD (with Pool-based Auto Assignment)
    -- ──────────────────────────────────────────
    WHEN 'create_lead' THEN
        -- Determine assigned_to
        -- If an explicit assignedTo is given, use it. Otherwise try round-robin pool.
        v_new_lead_id := gen_random_uuid(); -- pre-generate for pool tracking

        -- If no explicit assignee, attempt pool assignment
        IF v_data->>'assignedTo' IS NULL THEN
            SELECT ap.* INTO v_pool
            FROM assignment_pools ap
            WHERE ap.entity_type = 'lead'
              AND ap.is_active = TRUE
              AND ap.rule_type = 'round_robin'
              AND ap.deleted_at IS NULL
            ORDER BY ap.created_at
            LIMIT 1;

            IF v_pool.id IS NOT NULL THEN
                SELECT COUNT(*) INTO v_member_count
                FROM pool_members pm
                WHERE pm.pool_id = v_pool.id AND pm.is_active = TRUE;

                IF v_member_count > 0 THEN
                    v_new_index := v_pool.current_index % v_member_count;
                    SELECT u.id INTO v_next_user
                    FROM pool_members pm
                    JOIN users u ON u.id = pm.user_id
                    WHERE pm.pool_id = v_pool.id AND pm.is_active = TRUE
                    ORDER BY pm.added_at
                    LIMIT 1 OFFSET v_new_index;

                    -- Advance pointer
                    UPDATE assignment_pools
                    SET current_index = v_new_index + 1
                    WHERE id = v_pool.id;

                    -- Track count
                    UPDATE pool_members
                    SET assignment_count = assignment_count + 1
                    WHERE pool_id = v_pool.id AND user_id = v_next_user.id;
                END IF;
            END IF;
        END IF;

        INSERT INTO leads (
            lead_number, title, description, contact_id,
            estimated_value, assigned_to, owner_id, source, status,
            category, stage, probability,
            email, phone, expected_close_at, next_follow_up_at,
            budget_min, budget_max, requirement_summary, account_id
        ) VALUES (
            generate_lead_number(),
            v_data->>'title',
            v_data->>'description',
            (v_data->>'contactId')::UUID,
            (v_data->>'estimatedValue')::NUMERIC,
            COALESCE((v_data->>'assignedTo')::UUID, v_next_user.id),
            COALESCE((v_data->>'ownerId')::UUID, v_req_by),
            COALESCE((v_data->>'source')::lead_source, 'other'),
            COALESCE((v_data->>'status')::lead_status, 'new'),
            v_data->>'category',
            COALESCE(v_data->>'stage', 'new'),
            COALESCE((v_data->>'probability')::INT, 0),
            v_data->>'email',
            v_data->>'phone',
            (v_data->>'expectedCloseAt')::TIMESTAMPTZ,
            (v_data->>'nextFollowUpAt')::TIMESTAMPTZ,
            (v_data->>'budgetMin')::NUMERIC,
            (v_data->>'budgetMax')::NUMERIC,
            v_data->>'requirementSummary',
            (v_data->>'accountId')::UUID
        ) RETURNING id INTO v_new_lead_id;

        -- Log initial assignment if pool-assigned
        IF v_next_user.id IS NOT NULL THEN
            INSERT INTO assignment_history (entity_type, entity_id, previous_user_id, new_user_id, assigned_by, reason)
            VALUES ('lead', v_new_lead_id, NULL, v_next_user.id, v_req_by, 'Auto-assigned via round-robin pool');
        END IF;

        -- Log system activity
        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('lead', v_new_lead_id, 'system_event', 'Lead created', v_req_by);

        PERFORM fn_trigger_workflow('lead_created', v_new_lead_id);

        RETURN jsonb_build_object('rid', 's-lead-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_lead_id));

    -- ──────────────────────────────────────────
    -- UPDATE LEAD
    -- ──────────────────────────────────────────
    WHEN 'update_lead' THEN
        SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

        UPDATE leads SET
            title               = COALESCE(v_data->>'title', title),
            description         = COALESCE(v_data->>'description', description),
            category            = COALESCE(v_data->>'category', category),
            stage               = COALESCE(v_data->>'stage', stage),
            source              = COALESCE((v_data->>'source')::lead_source, source),
            email               = COALESCE(v_data->>'email', email),
            phone               = COALESCE(v_data->>'phone', phone),
            estimated_value     = COALESCE((v_data->>'estimatedValue')::NUMERIC, estimated_value),
            probability         = COALESCE((v_data->>'probability')::INT, probability),
            budget_min          = COALESCE((v_data->>'budgetMin')::NUMERIC, budget_min),
            budget_max          = COALESCE((v_data->>'budgetMax')::NUMERIC, budget_max),
            expected_close_at   = COALESCE((v_data->>'expectedCloseAt')::TIMESTAMPTZ, expected_close_at),
            next_follow_up_at   = COALESCE((v_data->>'nextFollowUpAt')::TIMESTAMPTZ, next_follow_up_at),
            requirement_summary = COALESCE(v_data->>'requirementSummary', requirement_summary),
            lost_reason         = COALESCE(v_data->>'lostReason', lost_reason),
            account_id          = COALESCE((v_data->>'accountId')::UUID, account_id),
            contact_id          = COALESCE((v_data->>'contactId')::UUID, contact_id)
        WHERE id = v_lead.id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('lead', v_lead.id, 'system_event', 'Lead updated', v_req_by);

        RETURN jsonb_build_object('rid', 's-lead-updated', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- UPDATE STATUS
    -- ──────────────────────────────────────────
    WHEN 'update_status' THEN
        SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

        UPDATE leads SET
            status     = (v_data->>'status')::lead_status,
            updated_at = NOW()
        WHERE id = v_lead.id;

        INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, reason)
        VALUES (v_lead.id, v_lead.status, (v_data->>'status')::lead_status, v_req_by, v_data->>'reason');

        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by)
        VALUES ('lead', v_lead.id, 'system_event',
                'Status changed from ' || v_lead.status || ' to ' || (v_data->>'status'),
                v_data->>'reason',
                v_req_by);

        PERFORM fn_trigger_workflow('status_changed', v_lead.id);

        RETURN jsonb_build_object('rid', 's-lead-status-updated', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- ASSIGN LEAD (Manual or Re-assign)
    -- ──────────────────────────────────────────
    WHEN 'assign_lead' THEN
        SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

        -- Record history
        INSERT INTO assignment_history (entity_type, entity_id, previous_user_id, new_user_id, assigned_by, reason)
        VALUES ('lead', v_lead.id, v_lead.assigned_to, (v_data->>'userId')::UUID, v_req_by, v_data->>'reason');

        UPDATE leads SET
            assigned_to = (v_data->>'userId')::UUID,
            updated_at  = NOW()
        WHERE id = v_lead.id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('lead', v_lead.id, 'system_event', 'Lead reassigned', v_req_by);

        RETURN jsonb_build_object('rid', 's-lead-assigned', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- CLAIM LEAD (Pool pick — user self-assigns)
    -- ──────────────────────────────────────────
    WHEN 'claim_lead' THEN
        SELECT * INTO v_lead FROM leads
        WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL AND assigned_to IS NULL;
        IF v_lead.id IS NULL THEN
            RETURN fn_error_envelope('e-lead-not-claimable', 400, 'Lead not found or already assigned');
        END IF;

        INSERT INTO assignment_history (entity_type, entity_id, previous_user_id, new_user_id, assigned_by, reason)
        VALUES ('lead', v_lead.id, NULL, v_req_by, v_req_by, 'Self-claimed from pool');

        UPDATE leads SET assigned_to = v_req_by, updated_at = NOW() WHERE id = v_lead.id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('lead', v_lead.id, 'system_event', 'Lead claimed from pool', v_req_by);

        RETURN jsonb_build_object('rid', 's-lead-claimed', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- CONVERT LEAD → OPPORTUNITY (+ deduplicate Account/Contact)
    -- ──────────────────────────────────────────
    WHEN 'convert_lead' THEN
        SELECT * INTO v_lead FROM leads WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_lead.id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

        IF v_lead.converted_opportunity_id IS NOT NULL THEN
            RETURN fn_error_envelope('e-lead-already-converted', 400, 'Lead has already been converted to an Opportunity');
        END IF;

        -- ── Account deduplication ──
        IF v_data->>'accountId' IS NOT NULL THEN
            v_account_id := (v_data->>'accountId')::UUID;
        ELSIF v_data->>'accountName' IS NOT NULL THEN
            -- Try to match existing account by name
            SELECT id INTO v_account_id FROM accounts
            WHERE lower(name) = lower(v_data->>'accountName')
              AND deleted_at IS NULL
            LIMIT 1;

            IF v_account_id IS NULL THEN
                INSERT INTO accounts (name, type, owner_id)
                VALUES (v_data->>'accountName', COALESCE(v_data->>'accountType', 'company'), v_req_by)
                RETURNING id INTO v_account_id;
            END IF;
        ELSE
            -- Fall back to lead's existing account
            v_account_id := v_lead.account_id;
        END IF;

        -- ── Contact deduplication ──
        IF v_data->>'contactId' IS NOT NULL THEN
            v_contact_id := (v_data->>'contactId')::UUID;
        ELSIF v_data->>'contactEmail' IS NOT NULL THEN
            SELECT id INTO v_contact_id FROM contacts
            WHERE lower(email) = lower(v_data->>'contactEmail')
              AND deleted_at IS NULL
            LIMIT 1;

            IF v_contact_id IS NULL THEN
                INSERT INTO contacts (first_name, last_name, email, phone, account_id, owner_id)
                VALUES (
                    COALESCE(v_data->>'contactFirstName', 'Unknown'),
                    COALESCE(v_data->>'contactLastName',  ''),
                    v_data->>'contactEmail',
                    v_data->>'contactPhone',
                    v_account_id,
                    v_req_by
                ) RETURNING id INTO v_contact_id;
            END IF;
        ELSE
            v_contact_id := COALESCE(v_lead.contact_id, v_lead.primary_contact_id);
        END IF;

        -- ── Create Opportunity ──
        INSERT INTO opportunities (
            opportunity_number, title, description,
            lead_id, account_id, contact_id,
            stage, amount, expected_close_date,
            assigned_to, probability
        ) VALUES (
            generate_opportunity_number(),
            COALESCE(v_data->>'opportunityTitle', v_lead.title),
            COALESCE(v_data->>'opportunityDescription', v_lead.description),
            v_lead.id,
            v_account_id,
            v_contact_id,
            'prospecting',
            COALESCE((v_data->>'amount')::NUMERIC, v_lead.estimated_value, 0),
            (v_data->>'expectedCloseDate')::DATE,
            COALESCE((v_data->>'assignedTo')::UUID, v_lead.assigned_to),
            COALESCE((v_data->>'probability')::INT, v_lead.probability, 0)
        ) RETURNING id INTO v_new_opp_id;

        -- ── Update lead conversion fields ──
        UPDATE leads SET
            status                    = 'converted',
            converted_at              = NOW(),
            converted_account_id      = v_account_id,
            converted_contact_id      = v_contact_id,
            converted_opportunity_id  = v_new_opp_id,
            last_activity_at          = NOW()
        WHERE id = v_lead.id;

        -- ── Update account/contact linkages if accounts were created ──
        IF v_account_id IS NOT NULL THEN
            UPDATE contacts SET account_id = v_account_id WHERE id = v_contact_id AND account_id IS NULL;
        END IF;

        -- ── Log activities ──
        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES
            ('lead', v_lead.id, 'system_event', 'Lead converted to Opportunity', v_req_by),
            ('opportunity', v_new_opp_id, 'system_event', 'Opportunity created from Lead ' || v_lead.lead_number, v_req_by);

        INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, reason)
        VALUES (v_lead.id, v_lead.status, 'converted', v_req_by, 'Lead converted to opportunity');

        PERFORM fn_trigger_workflow('lead_converted', v_lead.id);

        RETURN jsonb_build_object('rid', 's-lead-converted', 'statusCode', 200,
            'data', jsonb_build_object(
                'opportunityId', v_new_opp_id,
                'accountId',     v_account_id,
                'contactId',     v_contact_id
            ));

    -- ──────────────────────────────────────────
    -- DELETE LEAD (Soft)
    -- ──────────────────────────────────────────
    WHEN 'delete_lead' THEN
        SELECT id INTO v_new_lead_id FROM leads WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_new_lead_id IS NULL THEN RETURN fn_error_envelope('e-lead-not-found', 404, 'Lead not found'); END IF;

        UPDATE leads SET deleted_at = NOW() WHERE id = v_new_lead_id;
        RETURN jsonb_build_object('rid', 's-lead-deleted', 'statusCode', 200, 'data', null);

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
