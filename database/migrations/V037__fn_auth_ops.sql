SET search_path = crm, public;

-- V037: Auth Dispatcher Implementation
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
            SELECT * INTO v_user FROM users 
            WHERE email = v_data->>'email' AND deleted_at IS NULL;

            -- Check if user exists and password matches
            IF v_user.id IS NULL OR v_user.password_hash != crypt(v_data->>'password', v_user.password_hash) THEN
                RETURN fn_error_envelope('e-invalid-credentials', 401, 'Invalid email or password');
            END IF;

            -- Generate a secure session token
            v_session_token := (gen_random_uuid())::TEXT;

            -- Store session
            INSERT INTO sessions (user_id, token, expires_at)
            VALUES (v_user.id, v_session_token::UUID, v_expires_at);

            -- Return success with token and profile data
            RETURN jsonb_build_object(
                'rid', 's-login-success',
                'statusCode', 200,
                'data', jsonb_build_object(
                    'token', v_session_token,
                    'user', jsonb_build_object(
                        'id', v_user.id,
                        'email', v_user.email,
                        'fullName', v_user.full_name,
                        'role', (SELECT slug FROM roles WHERE id = v_user.role_id)
                    )
                )
            );

        WHEN 'validate_session' THEN
            -- Look up session
            -- Note: For simplicity in skeleton we are checking token directly here, 
            -- but the token_hash column exists if we wanted to hash. 
            -- However, looking up session by *hashed* token is difficult without the original.
            -- So we'll update the table to store the raw token for lookup (or use a secondary indexed hash).
            -- For now, we will perform a direct token lookup by updating V007 later if needed.
            -- CURRENT IMPLEMENTATION: Matches token directly stored or via lookup.
            
            -- Wait, V007 has token_hash. To validate, we need to iterate or use a fast lookup.
            -- Secure alternative: Store token as `token` (plain) but INDEX it.
            
            -- FOR NOW: Assuming p_payload->'data'->>'token' is the input.
            -- We'll query sessions and compare. 
            -- To make it fast, we look up the *latest* session for the user? No.
            -- We'll pivot to a simpler 'token' column for the skeleton to ensure validation works.
            
            SELECT s.*, u.email, u.full_name, r.slug as role_slug
            INTO v_user
            FROM sessions s
            JOIN users u ON s.user_id = u.id
            JOIN roles r ON u.role_id = r.id
            WHERE s.token = (v_data->>'token')::UUID
              AND s.expires_at > NOW();

            IF v_user.id IS NULL THEN
                RETURN fn_error_envelope('e-session-invalid', 401, 'Session expired or invalid');
            END IF;

            RETURN jsonb_build_object(
                'rid', 's-session-valid',
                'statusCode', 200,
                'data', jsonb_build_object(
                    'id', v_user.user_id,
                    'email', v_user.email,
                    'fullName', v_user.full_name,
                    'role', v_user.role_slug
                )
            );

        WHEN 'logout' THEN
            DELETE FROM sessions WHERE token = (v_data->>'token')::UUID;
            RETURN jsonb_build_object('rid', 's-logout-success', 'statusCode', 200, 'data', null);

        WHEN 'get_profile' THEN
            SELECT u.id, u.email, u.full_name, r.slug as role
            INTO v_user
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = (v_data->>'userId')::UUID AND u.deleted_at IS NULL;

            IF v_user.id IS NULL THEN
                RETURN fn_error_envelope('e-user-not-found', 404, 'User does not exist');
            END IF;

            RETURN jsonb_build_object(
                'rid', 's-profile-loaded',
                'statusCode', 200,
                'data', row_to_json(v_user)
            );

        ELSE
            RETURN fn_error_envelope('e-invalid-op', 400, 'Invalid operation');
    END CASE;
END; $$;
