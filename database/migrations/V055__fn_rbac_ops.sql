SET search_path = crm, public;

-- V055: RBAC Dispatcher Functional Implementation
CREATE OR REPLACE FUNCTION fn_rbac_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_req_by UUID := (p_payload->>'requestedBy')::UUID;
    v_user_id UUID := (v_data->>'userId')::UUID;
    v_perm TEXT := v_data->>'permission';
    v_has_perm BOOLEAN;
    v_res JSONB;
BEGIN
    CASE v_op
        WHEN 'check_permission' THEN
            SELECT EXISTS (
                SELECT 1 FROM users u
                JOIN roles r ON u.role_id = r.id
                JOIN role_permissions rp ON r.id = rp.role_id
                JOIN permissions p ON rp.permission_id = p.id
                WHERE u.id = v_user_id AND p.slug = v_perm
            ) INTO v_has_perm;

            RETURN jsonb_build_object('rid', 's-permission-checked', 'statusCode', 200, 'data', v_has_perm);

        WHEN 'get_user_permissions' THEN
            SELECT jsonb_agg(p.slug) INTO v_res FROM users u
            JOIN roles r ON u.role_id = r.id
            JOIN role_permissions rp ON r.id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            WHERE u.id = COALESCE(v_user_id, v_req_by);

            RETURN jsonb_build_object('rid', 's-permissions-loaded', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'list_roles' THEN
            SELECT jsonb_agg(r) INTO v_res FROM (SELECT id, slug, name FROM roles) r;
            RETURN jsonb_build_object('rid', 's-roles-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
