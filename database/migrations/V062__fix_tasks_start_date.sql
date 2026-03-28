SET search_path = crm, public;

-- V062: Fix missing start_date in tasks table (stabilization)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'crm' AND table_name = 'tasks' AND column_name = 'start_date') THEN
        ALTER TABLE tasks ADD COLUMN start_date TIMESTAMPTZ;
    END IF;
END $$;
