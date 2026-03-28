SET search_path = crm, public;

-- V063: Expanding enums for E2E and functional consistency
DO $$
BEGIN
    -- Add missed lead statuses
    IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'lead_status' AND e.enumlabel = 'negotiating') THEN
        ALTER TYPE lead_status ADD VALUE 'negotiating';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'lead_status' AND e.enumlabel = 'proposal') THEN
        ALTER TYPE lead_status ADD VALUE 'proposal';
    END IF;

    -- Add missed task statuses
    IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'task_status' AND e.enumlabel = 'review') THEN
        ALTER TYPE task_status ADD VALUE 'review';
    END IF;
END $$;
