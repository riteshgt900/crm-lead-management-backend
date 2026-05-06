SET search_path = crm, public;
-- V087__fn_portal_ops.sql

CREATE OR REPLACE FUNCTION public.fn_portal_operations(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_operation VARCHAR := p_payload->>'operation';
    v_data JSONB := p_payload->'data';
    v_result JSONB;
    v_user_id UUID;
    v_token VARCHAR;
    v_session_id UUID;
    v_portal_user RECORD;
    v_project_access RECORD;
    v_doc_id UUID;
    v_note_id UUID;
BEGIN
    CASE v_operation
        WHEN 'invite_portal_user' THEN
            -- Create portal user and link access
            INSERT INTO public.portal_users (contact_id, email, password_hash)
            VALUES (
                (v_data->>'contact_id')::UUID,
                v_data->>'email',
                v_data->>'password_hash' -- Would normally be hashed before DB
            )
            RETURNING id INTO v_user_id;

            INSERT INTO public.portal_project_access (portal_user_id, project_id, can_view, can_comment, can_upload)
            VALUES (
                v_user_id,
                (v_data->>'project_id')::UUID,
                COALESCE((v_data->>'can_view')::BOOLEAN, true),
                COALESCE((v_data->>'can_comment')::BOOLEAN, false),
                COALESCE((v_data->>'can_upload')::BOOLEAN, false)
            );

            v_result := jsonb_build_object(
                'success', true,
                'portal_user_id', v_user_id,
                'message', 'Portal user invited successfully'
            );

        WHEN 'portal_login' THEN
            -- Check password and return token
            SELECT * INTO v_portal_user FROM public.portal_users WHERE email = v_data->>'email' AND is_active = true;
            
            IF NOT FOUND THEN
                RETURN jsonb_build_object('error', 'Invalid credentials or inactive user');
            END IF;

            -- In a real scenario, compare a hashed password. 
            -- Assuming the middleware handles crypto and passes raw hash, or DB uses pgcrypto.
            IF v_portal_user.password_hash != v_data->>'password_hash' THEN
                RETURN jsonb_build_object('error', 'Invalid credentials');
            END IF;

            -- Generate token (simple uuid for example)
            v_token := gen_random_uuid()::VARCHAR;

            INSERT INTO public.portal_sessions (portal_user_id, token, expires_at)
            VALUES (v_portal_user.id, v_token, CURRENT_TIMESTAMP + INTERVAL '24 hours')
            RETURNING id INTO v_session_id;

            v_result := jsonb_build_object(
                'success', true,
                'token', v_token,
                'portal_user_id', v_portal_user.id
            );

        WHEN 'portal_validate_session' THEN
            SELECT * INTO v_portal_user
            FROM public.portal_sessions ps
            JOIN public.portal_users pu ON ps.portal_user_id = pu.id
            WHERE ps.token = v_data->>'token' AND ps.expires_at > CURRENT_TIMESTAMP AND pu.is_active = true;

            IF NOT FOUND THEN
                RETURN jsonb_build_object('valid', false);
            END IF;

            v_result := jsonb_build_object('valid', true, 'portal_user_id', v_portal_user.id);

        WHEN 'portal_get_projects' THEN
            SELECT jsonb_agg(jsonb_build_object(
                'project_id', ppa.project_id,
                'can_view', ppa.can_view,
                'can_comment', ppa.can_comment,
                'can_upload', ppa.can_upload
            )) INTO v_result
            FROM public.portal_project_access ppa
            WHERE ppa.portal_user_id = (v_data->>'portal_user_id')::UUID;

            v_result := COALESCE(v_result, '[]'::jsonb);

        WHEN 'portal_add_comment' THEN
            -- Check permissions
            SELECT * INTO v_project_access FROM public.portal_project_access
            WHERE portal_user_id = (v_data->>'portal_user_id')::UUID
              AND project_id = (v_data->>'project_id')::UUID
              AND can_comment = true;

            IF NOT FOUND THEN
                RETURN jsonb_build_object('error', 'Not permitted to comment on this project');
            END IF;

            -- Insert to notes
            INSERT INTO public.notes (project_id, content, is_external, created_by)
            VALUES (
                (v_data->>'project_id')::UUID,
                v_data->>'content',
                true,
                (v_data->>'portal_user_id')::UUID -- Store as creator
            ) RETURNING id INTO v_note_id;

            v_result := jsonb_build_object('success', true, 'note_id', v_note_id);

        WHEN 'portal_upload_doc' THEN
            -- Check permissions
            SELECT * INTO v_project_access FROM public.portal_project_access
            WHERE portal_user_id = (v_data->>'portal_user_id')::UUID
              AND project_id = (v_data->>'project_id')::UUID
              AND can_upload = true;

            IF NOT FOUND THEN
                RETURN jsonb_build_object('error', 'Not permitted to upload documents to this project');
            END IF;

            -- Insert to documents
            INSERT INTO public.documents (project_id, title, file_path, is_external, uploaded_by)
            VALUES (
                (v_data->>'project_id')::UUID,
                v_data->>'title',
                v_data->>'file_path',
                true,
                (v_data->>'portal_user_id')::UUID
            ) RETURNING id INTO v_doc_id;

            v_result := jsonb_build_object('success', true, 'document_id', v_doc_id);

        ELSE
            RETURN jsonb_build_object('error', 'Unknown portal operation: ' || COALESCE(v_operation, 'NULL'));
    END CASE;

    RETURN jsonb_build_object(
        'status', 'success',
        'operation', v_operation,
        'data', v_result
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'status', 'error',
        'operation', v_operation,
        'message', SQLERRM,
        'detail', SQLDETAIL
    );
END;
$$;
