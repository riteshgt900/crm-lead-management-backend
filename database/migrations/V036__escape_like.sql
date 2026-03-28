SET search_path = crm, public;
-- V036: fn_escape_like helper

CREATE OR REPLACE FUNCTION fn_escape_like(p_text TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    -- Escape %, _, and \ with \
    RETURN REPLACE(REPLACE(REPLACE(p_text, '\', '\\'), '%', '\%'), '_', '\_');
END; $$;

