SET search_path = crm, public;

-- V039: Users Dispatcher
CREATE OR REPLACE FUNCTION fn_user_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_req_usr_id UUID := (p_payload->>'requestedBy')::UUID;
    v_req_role_slug TEXT;
    v_target_role_slug TEXT;
    v_target_usr_id UUID;
    v_new_role_id UUID;
    v_res JSONB;
    v_email TEXT;
    v_password_hash TEXT;
    v_full_name TEXT;
BEGIN
    -- Get requester role
    SELECT r.slug INTO v_req_role_slug
    FROM users u
    JOIN roles r ON u.role_id = r.id
    WHERE u.id = v_req_usr_id AND u.deleted_at IS NULL AND u.is_active = TRUE;

    IF v_req_role_slug IS NULL AND v_op != 'login' THEN
        RETURN fn_error_envelope('e-unauthorized', 401, 'Unauthorized or inactive user');
    END IF;

    CASE v_op
        WHEN 'list_users' THEN
            SELECT jsonb_build_object(
                'rid', 's-users-listed',
                'statusCode', 200,
                'data', COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'id', u.id,
                        'email', u.email,
                        'full_name', u.full_name,
                        'phone', u.phone,
                        'avatar_url', u.avatar_url,
                        'is_active', u.is_active,
                        'role_id', u.role_id,
                        'role_slug', r.slug,
                        'role_name', r.name,
                        'last_login_at', u.last_login_at,
                        'created_at', u.created_at
                    ) ORDER BY u.created_at DESC
                ), '[]'::jsonb)
            ) INTO v_res
            FROM users u
            LEFT JOIN roles r ON u.role_id = r.id
            WHERE u.deleted_at IS NULL;
            RETURN v_res;

        WHEN 'create_user' THEN
            v_email := p_payload->'data'->>'email';
            v_full_name := p_payload->'data'->>'full_name';
            v_new_role_id := (p_payload->'data'->>'role_id')::UUID;
            v_password_hash := p_payload->'data'->>'password_hash';

            IF v_email IS NULL OR v_full_name IS NULL OR v_new_role_id IS NULL THEN
                RETURN fn_error_envelope('e-missing-fields', 400, 'Email, full name, and role are required');
            END IF;

            SELECT slug INTO v_target_role_slug FROM roles WHERE id = v_new_role_id;
            IF v_target_role_slug IS NULL THEN
                RETURN fn_error_envelope('e-invalid-role', 400, 'Invalid role');
            END IF;

            -- Hierarchy check
            IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                RETURN fn_error_envelope('e-forbidden-hierarchy', 403, 'Only super_admin can create super_admin users');
            END IF;

            BEGIN
                INSERT INTO users (email, password_hash, full_name, role_id, phone, avatar_url, is_active)
                VALUES (
                    v_email,
                    COALESCE(v_password_hash, 'INVITED_NO_PASSWORD'),
                    v_full_name,
                    v_new_role_id,
                    p_payload->'data'->>'phone',
                    p_payload->'data'->>'avatar_url',
                    COALESCE((p_payload->'data'->>'is_active')::BOOLEAN, TRUE)
                ) RETURNING id INTO v_target_usr_id;
            EXCEPTION WHEN unique_violation THEN
                RETURN fn_error_envelope('e-email-exists', 409, 'User with this email already exists');
            END;

            RETURN jsonb_build_object('rid', 's-user-created', 'statusCode', 201, 'data', jsonb_build_object('id', v_target_usr_id));

        WHEN 'update_user' THEN
            v_target_usr_id := (p_payload->'data'->>'id')::UUID;
            
            IF v_target_usr_id IS NULL THEN
                RETURN fn_error_envelope('e-missing-id', 400, 'User ID is required');
            END IF;

            -- Get target user's current role
            SELECT r.slug INTO v_target_role_slug
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = v_target_usr_id AND u.deleted_at IS NULL;

            IF v_target_role_slug IS NULL THEN
                RETURN fn_error_envelope('e-user-not-found', 404, 'User not found');
            END IF;

            -- Hierarchy check for updating
            IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                RETURN fn_error_envelope('e-forbidden-hierarchy', 403, 'Only super_admin can update super_admin users');
            END IF;

            -- New role check
            v_new_role_id := (p_payload->'data'->>'role_id')::UUID;
            IF v_new_role_id IS NOT NULL THEN
                SELECT slug INTO v_target_role_slug FROM roles WHERE id = v_new_role_id;
                IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                    RETURN fn_error_envelope('e-forbidden-hierarchy', 403, 'Only super_admin can grant super_admin role');
                END IF;
            END IF;

            BEGIN
                UPDATE users
                SET 
                    email = COALESCE(p_payload->'data'->>'email', email),
                    full_name = COALESCE(p_payload->'data'->>'full_name', full_name),
                    phone = COALESCE(p_payload->'data'->>'phone', phone),
                    avatar_url = COALESCE(p_payload->'data'->>'avatar_url', avatar_url),
                    is_active = COALESCE((p_payload->'data'->>'is_active')::BOOLEAN, is_active),
                    role_id = COALESCE(v_new_role_id, role_id),
                    updated_at = NOW()
                WHERE id = v_target_usr_id AND deleted_at IS NULL;
            EXCEPTION WHEN unique_violation THEN
                RETURN fn_error_envelope('e-email-exists', 409, 'User with this email already exists');
            END;

            RETURN jsonb_build_object('rid', 's-user-updated', 'statusCode', 200, 'data', jsonb_build_object('id', v_target_usr_id));

        WHEN 'delete_user' THEN
            v_target_usr_id := (p_payload->'data'->>'id')::UUID;
            
            IF v_target_usr_id IS NULL THEN
                RETURN fn_error_envelope('e-missing-id', 400, 'User ID is required');
            END IF;

            -- Get target user's current role
            SELECT r.slug INTO v_target_role_slug
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = v_target_usr_id AND u.deleted_at IS NULL;

            IF v_target_role_slug IS NULL THEN
                RETURN fn_error_envelope('e-user-not-found', 404, 'User not found');
            END IF;

            -- Hierarchy check for deleting
            IF v_target_role_slug = 'super_admin' AND v_req_role_slug != 'super_admin' THEN
                RETURN fn_error_envelope('e-forbidden-hierarchy', 403, 'Only super_admin can delete super_admin users');
            END IF;

            -- Self-deletion prevention
            IF v_target_usr_id = v_req_usr_id THEN
                RETURN fn_error_envelope('e-forbidden-self-delete', 400, 'Cannot delete yourself');
            END IF;

            UPDATE users
            SET deleted_at = NOW(), is_active = false
            WHERE id = v_target_usr_id AND deleted_at IS NULL;

            RETURN jsonb_build_object('rid', 's-user-deleted', 'statusCode', 200, 'data', jsonb_build_object('id', v_target_usr_id));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;


