SET search_path = crm, public;
-- V033: Updated_at Triggers

CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
          AND table_schema = 'public' -- Adjust if using crm schema
    LOOP
        EXECUTE format('CREATE TRIGGER trg_update_timestamp_%I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp()', t, t);
    END LOOP;
END $$;

