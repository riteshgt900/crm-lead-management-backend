SET search_path = crm, public;

CREATE OR REPLACE FUNCTION fn_auth_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = crm, public
AS $$
DECLARE
    v_op TEXT := lower(COALESCE(p_payload->>'operation', ''));
    v_data JSONB := COALESCE(p_payload->'data', '{}'::jsonb);
    v_user RECORD;
    v_permissions JSONB := '[]'::jsonb;
    v_session_token UUID;
    v_reset_token TEXT;
    v_reset RECORD;
BEGIN
    CASE v_op
        WHEN 'login' THEN
            SELECT u.*, r.slug AS role_slug, r.name AS role_name
            INTO v_user
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE lower(u.email) = lower(COALESCE(v_data->>'email', ''))
              AND u.deleted_at IS NULL
              AND u.is_active = TRUE;

            IF v_user.id IS NULL OR v_user.password_hash <> crypt(COALESCE(v_data->>'password', ''), v_user.password_hash) THEN
                RETURN fn_error_envelope('e-invalid-credentials', 401, 'Invalid email or password');
            END IF;

            DELETE FROM sessions WHERE user_id = v_user.id AND expires_at <= NOW();

            v_session_token := gen_random_uuid();
            INSERT INTO sessions (user_id, token, expires_at)
            VALUES (v_user.id, v_session_token, NOW() + INTERVAL '7 days');

            SELECT COALESCE(jsonb_agg(p.slug ORDER BY p.slug), '[]'::jsonb)
            INTO v_permissions
            FROM role_permissions rp
            JOIN permissions p ON p.id = rp.permission_id
            WHERE rp.role_id = v_user.role_id
              AND p.deleted_at IS NULL;

            UPDATE users
            SET last_login_at = NOW(),
                updated_at = NOW()
            WHERE id = v_user.id;

            RETURN fn_runtime_success(
                's-login-success',
                200,
                jsonb_build_object(
                    'token', v_session_token,
                    'user', jsonb_build_object(
                        'id', v_user.id,
                        'email', v_user.email,
                        'fullName', v_user.full_name,
                        'firstName', split_part(v_user.full_name, ' ', 1),
                        'lastName', NULLIF(substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2), ''),
                        'role', v_user.role_slug,
                        'roleName', v_user.role_slug,
                        'permissions', v_permissions
                    )
                )
            );

        WHEN 'validate_session' THEN
            SELECT s.user_id, u.email, u.full_name, u.is_active, r.slug AS role_slug, r.name AS role_name, u.role_id
            INTO v_user
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            JOIN roles r ON r.id = u.role_id
            WHERE s.token = NULLIF(v_data->>'token', '')::uuid
              AND s.expires_at > NOW()
              AND u.deleted_at IS NULL
              AND u.is_active = TRUE;

            IF v_user.user_id IS NULL THEN
                RETURN fn_error_envelope('e-session-invalid', 401, 'Session expired or invalid');
            END IF;

            SELECT COALESCE(jsonb_agg(p.slug ORDER BY p.slug), '[]'::jsonb)
            INTO v_permissions
            FROM role_permissions rp
            JOIN permissions p ON p.id = rp.permission_id
            WHERE rp.role_id = v_user.role_id
              AND p.deleted_at IS NULL;

            RETURN fn_runtime_success(
                's-session-valid',
                200,
                jsonb_build_object(
                    'id', v_user.user_id,
                    'email', v_user.email,
                    'fullName', v_user.full_name,
                    'firstName', split_part(v_user.full_name, ' ', 1),
                    'lastName', NULLIF(substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2), ''),
                    'role', v_user.role_slug,
                    'roleName', v_user.role_slug,
                    'permissions', v_permissions
                )
            );

        WHEN 'logout' THEN
            DELETE FROM sessions
            WHERE token = NULLIF(v_data->>'token', '')::uuid;

            RETURN fn_runtime_success('s-logout-success', 200, 'null'::jsonb);

        WHEN 'get_profile' THEN
            SELECT u.id, u.email, u.full_name, u.phone, u.avatar_url, r.slug AS role_slug, r.name AS role_name, u.role_id
            INTO v_user
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE u.id = NULLIF(v_data->>'userId', '')::uuid
              AND u.deleted_at IS NULL;

            IF v_user.id IS NULL THEN
                RETURN fn_error_envelope('e-user-not-found', 404, 'User does not exist');
            END IF;

            SELECT COALESCE(jsonb_agg(p.slug ORDER BY p.slug), '[]'::jsonb)
            INTO v_permissions
            FROM role_permissions rp
            JOIN permissions p ON p.id = rp.permission_id
            WHERE rp.role_id = v_user.role_id
              AND p.deleted_at IS NULL;

            RETURN fn_runtime_success(
                's-profile-loaded',
                200,
                jsonb_build_object(
                    'id', v_user.id,
                    'email', v_user.email,
                    'fullName', v_user.full_name,
                    'firstName', split_part(v_user.full_name, ' ', 1),
                    'lastName', NULLIF(substr(v_user.full_name, length(split_part(v_user.full_name, ' ', 1)) + 2), ''),
                    'phone', v_user.phone,
                    'avatarUrl', v_user.avatar_url,
                    'role', v_user.role_slug,
                    'roleName', v_user.role_slug,
                    'permissions', v_permissions
                )
            );

        WHEN 'forgot_password' THEN
            SELECT *
            INTO v_user
            FROM users
            WHERE lower(email) = lower(COALESCE(v_data->>'email', ''))
              AND deleted_at IS NULL
              AND is_active = TRUE;

            IF v_user.id IS NOT NULL THEN
                DELETE FROM password_reset_tokens
                WHERE user_id = v_user.id;

                v_reset_token := gen_random_uuid()::text;
                INSERT INTO password_reset_tokens (user_id, token, expires_at)
                VALUES (v_user.id, v_reset_token, NOW() + INTERVAL '1 hour');
            END IF;

            RETURN fn_runtime_success(
                's-password-reset-requested',
                200,
                jsonb_build_object(
                    'accepted', TRUE,
                    'delivery', 'email'
                ),
                'If the account exists, a reset link will be sent.'
            );

        WHEN 'reset_password' THEN
            SELECT prt.*, u.email
            INTO v_reset
            FROM password_reset_tokens prt
            JOIN users u ON u.id = prt.user_id
            WHERE prt.token = COALESCE(v_data->>'token', '')
              AND prt.expires_at > NOW()
              AND u.deleted_at IS NULL;

            IF v_reset.id IS NULL THEN
                RETURN fn_error_envelope('e-reset-token-invalid', 400, 'Reset token is invalid or expired');
            END IF;

            UPDATE users
            SET password_hash = crypt(COALESCE(v_data->>'password', ''), gen_salt('bf')),
                updated_at = NOW()
            WHERE id = v_reset.user_id;

            DELETE FROM password_reset_tokens
            WHERE user_id = v_reset.user_id;

            DELETE FROM sessions
            WHERE user_id = v_reset.user_id;

            RETURN fn_runtime_success('s-password-reset-success', 200, jsonb_build_object('email', v_reset.email));

        WHEN 'cleanup_sessions' THEN
            DELETE FROM sessions WHERE expires_at <= NOW();
            DELETE FROM password_reset_tokens WHERE expires_at <= NOW();
            RETURN fn_runtime_success('s-auth-cleanup-complete', 200, jsonb_build_object('done', TRUE));

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid auth operation');
    END CASE;
END;
$$;
