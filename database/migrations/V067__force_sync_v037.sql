SET search_path = crm, public;

-- V067: Force Synchronization of Auth Dispatcher (Latest permissions & firstName structure)
CREATE OR REPLACE FUNCTION fn_auth_operations(p_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = crm, public AS $$
DECLARE
    v_op TEXT := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_res JSONB;
    v_user RECORD;
    v_session_token TEXT;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '7 days';
BEGIN
    CASE v_op
        WHEN 'login' THEN
            -- Find user by email
            SELECT u.*, r.slug as role_slug
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.email = v_data->>'email' AND u.deleted_at IS NULL
            INTO v_user;

            -- Check if user exists and password matches
            IF v_user.id IS NULL OR v_user.password_hash != crypt(v_data->>'password', v_user.password_hash) THEN
                RETURN fn_error_envelope('e-invalid-credentials', 401, 'Invalid email or password');
            END IF;

            -- Generate a secure session token
            v_session_token := (gen_random_uuid())::TEXT;

            -- Store session
            INSERT INTO sessions (user_id, token, expires_at)
            VALUES (v_user.id, v_session_token::UUID, v_expires_at);

            -- Get permissions
            SELECT jsonb_agg(p.slug) INTO v_res FROM role_permissions rp
            JOIN permissions p ON rp.permission_id = p.id
            WHERE rp.role_id = v_user.role_id;

            -- Return success with token and profile data
            RETURN jsonb_build_object(
                'rid', 's-login-success',
                'statusCode', 200,
                'data', jsonb_build_object(
                    'token', v_session_token,
                    'user', jsonb_build_object(
                        'id', v_user.id,
                        'email', v_user.email,
                        'firstName', split_part(v_user.full_name, ' ', 1),
                        'lastName', substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2),
                        'roleName', v_user.role_slug,
                        'permissions', COALESCE(v_res, '[]'::jsonb)
                    )
                )
            );

        WHEN 'validate_session' THEN
            SELECT s.*, u.email, u.full_name, r.slug as role_slug, r.id as role_id
            INTO v_user
            FROM sessions s
            JOIN users u ON s.user_id = u.id
            JOIN roles r ON u.role_id = r.id
            WHERE s.token = (v_data->>'token')::UUID
              AND s.expires_at > NOW();

            IF v_user.id IS NULL THEN
                RETURN fn_error_envelope('e-session-invalid', 401, 'Session expired or invalid');
            END IF;

            -- Get permissions
            SELECT jsonb_agg(p.slug) INTO v_res FROM role_permissions rp
            JOIN permissions p ON rp.permission_id = p.id
            WHERE rp.role_id = v_user.role_id;

            RETURN jsonb_build_object(
                'rid', 's-session-valid',
                'statusCode', 200,
                'data', jsonb_build_object(
                    'id', v_user.user_id,
                    'email', v_user.email,
                    'firstName', split_part(v_user.full_name, ' ', 1),
                    'lastName', substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2),
                    'roleName', v_user.role_slug,
                    'permissions', COALESCE(v_res, '[]'::jsonb)
                )
            );

        WHEN 'logout' THEN
            DELETE FROM sessions WHERE token = (v_data->>'token')::UUID;
            RETURN jsonb_build_object('rid', 's-logout-success', 'statusCode', 200, 'data', null);

        WHEN 'get_profile' THEN
            SELECT u.id, u.email, u.full_name, r.slug as role_slug, r.id as role_id
            INTO v_user
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = (v_data->>'userId')::UUID AND u.deleted_at IS NULL;

            IF v_user.id IS NULL THEN
                RETURN fn_error_envelope('e-user-not-found', 404, 'User does not exist');
            END IF;

            -- Get permissions
            SELECT jsonb_agg(p.slug) INTO v_res FROM role_permissions rp
            JOIN permissions p ON rp.permission_id = p.id
            WHERE rp.role_id = v_user.role_id;

            RETURN jsonb_build_object(
                'rid', 's-profile-loaded',
                'statusCode', 200,
                'data', jsonb_build_object(
                    'id', v_user.id,
                    'email', v_user.email,
                    'firstName', split_part(v_user.full_name, ' ', 1),
                    'lastName', substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2),
                    'roleName', v_user.role_slug,
                    'permissions', COALESCE(v_res, '[]'::jsonb)
                )
            );

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
