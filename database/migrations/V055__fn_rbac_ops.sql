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
    v_req_role_slug TEXT;
    v_target_role_slug TEXT;
    v_target_role_id UUID;
    v_perm_ids UUID[];
BEGIN
    -- Get the requester's role slug
    IF v_req_by IS NOT NULL THEN
        SELECT r.slug INTO v_req_role_slug FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = v_req_by;
    END IF;

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
            SELECT jsonb_agg(r) INTO v_res FROM (
                SELECT id, slug, name, description, priority, created_at, updated_at 
                FROM roles WHERE deleted_at IS NULL ORDER BY priority DESC
            ) r;
            RETURN jsonb_build_object('rid', 's-roles-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'create_role' THEN
            -- Check permissions via external check or assume authorized, but let's just insert here
            INSERT INTO roles (name, slug, description, priority)
            VALUES (v_data->>'name', v_data->>'slug', v_data->>'description', COALESCE((v_data->>'priority')::int, 0))
            RETURNING jsonb_build_object('id', id, 'name', name, 'slug', slug) INTO v_res;
            
            RETURN jsonb_build_object('rid', 's-role-created', 'statusCode', 201, 'data', v_res);

        WHEN 'update_role' THEN
            v_target_role_id := (v_data->>'id')::UUID;
            SELECT slug INTO v_target_role_slug FROM roles WHERE id = v_target_role_id;
            
            IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                RETURN fn_error_envelope('e-access-denied', 403, 'Only super_admin can modify super_admin role.');
            END IF;

            UPDATE roles 
            SET name = COALESCE(v_data->>'name', name),
                slug = COALESCE(v_data->>'slug', slug),
                description = COALESCE(v_data->>'description', description),
                priority = COALESCE((v_data->>'priority')::int, priority),
                updated_at = NOW()
            WHERE id = v_target_role_id AND deleted_at IS NULL
            RETURNING jsonb_build_object('id', id, 'name', name, 'slug', slug) INTO v_res;

            IF v_res IS NULL THEN
                RETURN fn_error_envelope('e-not-found', 404, 'Role not found.');
            END IF;

            RETURN jsonb_build_object('rid', 's-role-updated', 'statusCode', 200, 'data', v_res);

        WHEN 'delete_role' THEN
            v_target_role_id := (v_data->>'id')::UUID;
            SELECT slug INTO v_target_role_slug FROM roles WHERE id = v_target_role_id;

            IF v_target_role_slug = 'super_admin' THEN
                RETURN fn_error_envelope('e-access-denied', 403, 'super_admin role cannot be deleted.');
            END IF;

            -- Check if users are assigned to this role
            IF EXISTS (SELECT 1 FROM users WHERE role_id = v_target_role_id AND deleted_at IS NULL) THEN
                RETURN fn_error_envelope('e-role-in-use', 400, 'Cannot delete role with assigned users.');
            END IF;

            UPDATE roles SET deleted_at = NOW() WHERE id = v_target_role_id;
            RETURN jsonb_build_object('rid', 's-role-deleted', 'statusCode', 200, 'data', true);

        WHEN 'list_permissions' THEN
            SELECT jsonb_agg(p) INTO v_res FROM (
                SELECT id, module, action, slug, description 
                FROM permissions WHERE deleted_at IS NULL ORDER BY module, action
            ) p;
            RETURN jsonb_build_object('rid', 's-permissions-listed', 'statusCode', 200, 'data', COALESCE(v_res, '[]'::jsonb));

        WHEN 'update_role_permissions' THEN
            v_target_role_id := (v_data->>'roleId')::UUID;
            SELECT slug INTO v_target_role_slug FROM roles WHERE id = v_target_role_id;

            IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                RETURN fn_error_envelope('e-access-denied', 403, 'Only super_admin can alter super_admin permissions.');
            END IF;

            -- Parse permissions array
            SELECT array_agg(p_id::UUID) INTO v_perm_ids 
            FROM jsonb_array_elements_text(v_data->'permissions') AS p_id;

            -- Delete old ones and insert new ones
            DELETE FROM role_permissions WHERE role_id = v_target_role_id;
            
            IF v_perm_ids IS NOT NULL AND array_length(v_perm_ids, 1) > 0 THEN
                INSERT INTO role_permissions (role_id, permission_id)
                SELECT v_target_role_id, unnest(v_perm_ids);
            END IF;

            RETURN jsonb_build_object('rid', 's-role-perms-updated', 'statusCode', 200, 'data', true);

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
