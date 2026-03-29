SET search_path = crm, public;

-- V080: fn_opportunity_operations
-- Manages the full Opportunity (Deal) lifecycle:
--   list_opportunities, get_opportunity, create_opportunity,
--   update_opportunity, update_stage, close_won (auto-creates Project),
--   close_lost, assign_opportunity, delete_opportunity

CREATE OR REPLACE FUNCTION fn_opportunity_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op   TEXT  := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res  JSONB;
    v_opp  RECORD;
    v_new_opp_id  UUID;
    v_new_proj_id UUID;
    v_search TEXT := v_data->>'q';
    v_stage  TEXT := v_data->>'stage';
BEGIN
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op

    -- ──────────────────────────────────────────
    -- LIST OPPORTUNITIES
    -- ──────────────────────────────────────────
    WHEN 'list_opportunities' THEN
        SELECT jsonb_agg(row_to_json(o)) INTO v_res FROM (
            SELECT
                o.id, o.opportunity_number, o.title, o.description,
                o.stage, o.amount, o.probability, o.expected_close_date,
                o.won_at, o.lost_at, o.lost_reason,
                o.lead_id, o.account_id, a.name AS account_name,
                o.contact_id, c.first_name || ' ' || c.last_name AS contact_name,
                o.assigned_to, u.full_name AS assigned_to_name,
                o.created_at, o.updated_at
            FROM opportunities o
            LEFT JOIN accounts a ON o.account_id = a.id
            LEFT JOIN contacts c ON o.contact_id = c.id
            LEFT JOIN users   u ON o.assigned_to  = u.id
            WHERE o.deleted_at IS NULL
              AND (v_search IS NULL OR o.title ILIKE '%' || fn_escape_like(v_search) || '%')
              AND (v_stage IS NULL OR o.stage::TEXT = v_stage)
              AND (
                  (SELECT r.slug FROM users u2 JOIN roles r ON u2.role_id = r.id WHERE u2.id = v_req_by) = 'admin'
                  OR o.assigned_to = v_req_by
                  OR o.assigned_to IS NULL
              )
            ORDER BY o.created_at DESC
            LIMIT  COALESCE((v_data->>'limit')::INT, 50)
            OFFSET COALESCE((v_data->>'offset')::INT, 0)
        ) o;
        RETURN jsonb_build_object('rid', 's-opportunities-listed', 'statusCode', 200,
            'data', COALESCE(v_res, '[]'::jsonb));

    -- ──────────────────────────────────────────
    -- GET OPPORTUNITY (detail with related data)
    -- ──────────────────────────────────────────
    WHEN 'get_opportunity' THEN
        SELECT row_to_json(o) INTO v_res FROM (
            SELECT
                o.*,
                a.name  AS account_name,
                c.first_name || ' ' || c.last_name AS contact_name,
                u.full_name AS assigned_to_name,
                (SELECT row_to_json(l) FROM leads l WHERE l.id = o.lead_id) AS lead,
                (SELECT jsonb_agg(row_to_json(p)) FROM projects p WHERE p.opportunity_id = o.id AND p.deleted_at IS NULL) AS projects,
                (SELECT jsonb_agg(row_to_json(nt)) FROM notes nt WHERE nt.entity_type = 'opportunity' AND nt.entity_id = o.id AND nt.deleted_at IS NULL ORDER BY nt.is_pinned DESC, nt.created_at DESC) AS notes,
                (SELECT jsonb_agg(row_to_json(ac)) FROM activities ac WHERE ac.entity_type = 'opportunity' AND ac.entity_id = o.id AND ac.deleted_at IS NULL ORDER BY ac.activity_date DESC LIMIT 20) AS activities,
                (SELECT jsonb_agg(row_to_json(ah)) FROM assignment_history ah WHERE ah.entity_type = 'opportunity' AND ah.entity_id = o.id ORDER BY ah.assigned_at DESC) AS assignment_history
            FROM opportunities o
            LEFT JOIN accounts a ON o.account_id = a.id
            LEFT JOIN contacts c ON o.contact_id = c.id
            LEFT JOIN users   u ON o.assigned_to  = u.id
            WHERE o.id = (v_data->>'id')::UUID AND o.deleted_at IS NULL
        ) o;
        IF v_res IS NULL THEN
            RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found');
        END IF;
        RETURN jsonb_build_object('rid', 's-opportunity-loaded', 'statusCode', 200, 'data', v_res);

    -- ──────────────────────────────────────────
    -- CREATE OPPORTUNITY (standalone)
    -- ──────────────────────────────────────────
    WHEN 'create_opportunity' THEN
        INSERT INTO opportunities (
            opportunity_number, title, description,
            lead_id, account_id, contact_id,
            stage, amount, expected_close_date,
            assigned_to, probability
        ) VALUES (
            generate_opportunity_number(),
            v_data->>'title',
            v_data->>'description',
            (v_data->>'leadId')::UUID,
            (v_data->>'accountId')::UUID,
            (v_data->>'contactId')::UUID,
            COALESCE((v_data->>'stage')::opportunity_stage, 'prospecting'),
            COALESCE((v_data->>'amount')::NUMERIC, 0),
            (v_data->>'expectedCloseDate')::DATE,
            COALESCE((v_data->>'assignedTo')::UUID, v_req_by),
            COALESCE((v_data->>'probability')::INT, 0)
        ) RETURNING id INTO v_new_opp_id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('opportunity', v_new_opp_id, 'system_event', 'Opportunity created', v_req_by);

        RETURN jsonb_build_object('rid', 's-opportunity-created', 'statusCode', 201,
            'data', jsonb_build_object('id', v_new_opp_id));

    -- ──────────────────────────────────────────
    -- UPDATE OPPORTUNITY
    -- ──────────────────────────────────────────
    WHEN 'update_opportunity' THEN
        SELECT * INTO v_opp FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_opp.id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;

        UPDATE opportunities SET
            title               = COALESCE(v_data->>'title', title),
            description         = COALESCE(v_data->>'description', description),
            amount              = COALESCE((v_data->>'amount')::NUMERIC, amount),
            probability         = COALESCE((v_data->>'probability')::INT, probability),
            expected_close_date = COALESCE((v_data->>'expectedCloseDate')::DATE, expected_close_date),
            account_id          = COALESCE((v_data->>'accountId')::UUID, account_id),
            contact_id          = COALESCE((v_data->>'contactId')::UUID, contact_id),
            lost_reason         = COALESCE(v_data->>'lostReason', lost_reason)
        WHERE id = v_opp.id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('opportunity', v_opp.id, 'system_event', 'Opportunity updated', v_req_by);

        RETURN jsonb_build_object('rid', 's-opportunity-updated', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- UPDATE STAGE
    -- ──────────────────────────────────────────
    WHEN 'update_stage' THEN
        SELECT * INTO v_opp FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_opp.id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;

        IF v_opp.stage IN ('won', 'lost') THEN
            RETURN fn_error_envelope('e-opportunity-closed', 400, 'Cannot change stage of a closed Opportunity. Use close_won or close_lost.');
        END IF;

        UPDATE opportunities SET
            stage      = (v_data->>'stage')::opportunity_stage,
            probability = COALESCE((v_data->>'probability')::INT, probability),
            updated_at = NOW()
        WHERE id = v_opp.id;

        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by)
        VALUES ('opportunity', v_opp.id, 'system_event',
                'Stage moved from ' || v_opp.stage || ' to ' || (v_data->>'stage'),
                v_data->>'note', v_req_by);

        RETURN jsonb_build_object('rid', 's-opportunity-stage-updated', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- CLOSE WON → Auto-creates Project
    -- ──────────────────────────────────────────
    WHEN 'close_won' THEN
        SELECT * INTO v_opp FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_opp.id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;
        IF v_opp.stage IN ('won', 'lost') THEN
            RETURN fn_error_envelope('e-opportunity-already-closed', 400, 'Opportunity is already closed');
        END IF;

        -- Mark opportunity won
        UPDATE opportunities SET
            stage  = 'won',
            won_at = NOW(),
            probability = 100,
            updated_at = NOW()
        WHERE id = v_opp.id;

        -- Auto-create Project linked to opportunity
        INSERT INTO projects (
            project_number, title, description,
            lead_id, account_id, contact_id, opportunity_id,
            estimated_value, budget,
            project_manager_id, template_id, status
        ) VALUES (
            generate_project_number(),
            COALESCE(v_data->>'projectTitle', v_opp.title),
            COALESCE(v_data->>'projectDescription', v_opp.description),
            v_opp.lead_id,
            v_opp.account_id,
            v_opp.contact_id,
            v_opp.id,
            v_opp.amount,
            v_opp.amount,
            COALESCE((v_data->>'projectManagerId')::UUID, v_opp.assigned_to, v_req_by),
            (v_data->>'templateId')::UUID,
            'planning'
        ) RETURNING id INTO v_new_proj_id;

        -- Clone template phases if provided
        IF v_data->>'templateId' IS NOT NULL THEN
            INSERT INTO project_phases (project_id, name, description, sort_order, status)
            SELECT v_new_proj_id, name, description, sort_order, 'planning'
            FROM project_phases
            WHERE template_id = (v_data->>'templateId')::UUID
              AND deleted_at IS NULL;
        END IF;

        -- Add primary stakeholder
        IF v_opp.contact_id IS NOT NULL THEN
            INSERT INTO project_stakeholders (project_id, account_id, contact_id, role_key, is_primary)
            VALUES (v_new_proj_id, v_opp.account_id, v_opp.contact_id, 'primary_contact', TRUE)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Activities
        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES
            ('opportunity', v_opp.id, 'system_event', 'Opportunity closed as Won — Project created', v_req_by),
            ('project', v_new_proj_id, 'system_event', 'Project created from Opportunity ' || v_opp.opportunity_number, v_req_by);

        -- Update lead last_activity_at
        UPDATE leads SET last_activity_at = NOW() WHERE id = v_opp.lead_id;

        PERFORM fn_trigger_workflow('lead_converted', v_opp.lead_id);

        RETURN jsonb_build_object('rid', 's-opportunity-won', 'statusCode', 200,
            'data', jsonb_build_object('projectId', v_new_proj_id));

    -- ──────────────────────────────────────────
    -- CLOSE LOST
    -- ──────────────────────────────────────────
    WHEN 'close_lost' THEN
        SELECT * INTO v_opp FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_opp.id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;

        UPDATE opportunities SET
            stage       = 'lost',
            lost_at     = NOW(),
            lost_reason = COALESCE(v_data->>'lostReason', lost_reason),
            probability = 0,
            updated_at  = NOW()
        WHERE id = v_opp.id;

        INSERT INTO activities (entity_type, entity_id, type, title, description, performed_by)
        VALUES ('opportunity', v_opp.id, 'system_event', 'Opportunity closed as Lost', v_data->>'lostReason', v_req_by);

        UPDATE leads SET last_activity_at = NOW() WHERE id = v_opp.lead_id;

        RETURN jsonb_build_object('rid', 's-opportunity-lost', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- ASSIGN OPPORTUNITY
    -- ──────────────────────────────────────────
    WHEN 'assign_opportunity' THEN
        SELECT * INTO v_opp FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_opp.id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;

        INSERT INTO assignment_history (entity_type, entity_id, previous_user_id, new_user_id, assigned_by, reason)
        VALUES ('opportunity', v_opp.id, v_opp.assigned_to, (v_data->>'userId')::UUID, v_req_by, v_data->>'reason');

        UPDATE opportunities SET
            assigned_to = (v_data->>'userId')::UUID,
            updated_at  = NOW()
        WHERE id = v_opp.id;

        INSERT INTO activities (entity_type, entity_id, type, title, performed_by)
        VALUES ('opportunity', v_opp.id, 'system_event', 'Opportunity reassigned', v_req_by);

        RETURN jsonb_build_object('rid', 's-opportunity-assigned', 'statusCode', 200, 'data', null);

    -- ──────────────────────────────────────────
    -- DELETE OPPORTUNITY (soft)
    -- ──────────────────────────────────────────
    WHEN 'delete_opportunity' THEN
        SELECT id INTO v_new_opp_id FROM opportunities WHERE id = (v_data->>'id')::UUID AND deleted_at IS NULL;
        IF v_new_opp_id IS NULL THEN RETURN fn_error_envelope('e-opportunity-not-found', 404, 'Opportunity not found'); END IF;

        UPDATE opportunities SET deleted_at = NOW() WHERE id = v_new_opp_id;
        RETURN jsonb_build_object('rid', 's-opportunity-deleted', 'statusCode', 200, 'data', null);

    ELSE
        RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation: ' || COALESCE(v_op, 'null'));
    END CASE;
END; $$;
