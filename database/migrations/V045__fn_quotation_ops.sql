SET search_path = crm, public;

-- V045: Quotations Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_quotation_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_res JSONB;
    v_id UUID;
    v_item JSONB;
    v_total NUMERIC(15, 2) := 0;
    v_search TEXT := v_data->>'q';
BEGIN
    -- Set session user for audit
    PERFORM set_config('crm.current_user_id', v_req_by::TEXT, true);

    CASE v_op
        WHEN 'list_quotations' THEN
            SELECT jsonb_agg(q) INTO v_res FROM (
                SELECT 
                    q.*,
                    l.title as lead_title,
                    c.first_name || ' ' || c.last_name as contact_name
                FROM quotations q
                LEFT JOIN leads l ON q.lead_id = l.id
                LEFT JOIN contacts c ON q.contact_id = c.id
                WHERE q.deleted_at IS NULL
                  AND (v_search IS NULL OR q.quotation_number ILIKE '%' || fn_escape_like(v_search) || '%' OR q.notes ILIKE '%' || fn_escape_like(v_search) || '%')
                ORDER BY q.created_at DESC
                LIMIT COALESCE((v_data->>'limit')::INT, 50)
                OFFSET COALESCE((v_data->>'offset')::INT, 0)
            ) q;
            RETURN jsonb_build_object('rid', 's-quotations-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'create_quotation' THEN
            -- 1. Insert Main Record
            INSERT INTO quotations (
                quotation_number, lead_id, contact_id, status, notes, created_by
            ) VALUES (
                generate_quotation_number(),
                (v_data->>'leadId')::UUID,
                (v_data->>'contactId')::UUID,
                COALESCE((v_data->>'status')::quotation_status, 'draft'),
                v_data->>'notes',
                v_req_by
            ) RETURNING id INTO v_id;

            -- 2. Process Items
            FOR v_item IN SELECT * FROM jsonb_array_elements(v_data->'items')
            LOOP
                INSERT INTO quotation_items (
                    quotation_id, description, quantity, unit_price, total_price
                ) VALUES (
                    v_id,
                    v_item->>'description',
                    (v_item->>'quantity')::NUMERIC,
                    (v_item->>'unitPrice')::NUMERIC,
                    (v_item->>'quantity')::NUMERIC * (v_item->>'unitPrice')::NUMERIC
                );
                
                v_total := v_total + ((v_item->>'quantity')::NUMERIC * (v_item->>'unitPrice')::NUMERIC);
            END LOOP;

            -- 3. Update Total
            UPDATE quotations SET total_amount = v_total WHERE id = v_id;

            RETURN jsonb_build_object('rid', 's-quotation-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_id, 'total', v_total));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
