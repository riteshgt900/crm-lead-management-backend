SET search_path = crm, public;

-- V064: Enterprise Contact Categories
-- Expanding the contact category enum to include Architects, PMCs, and Vendors as per Scope.docx.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'contact_category' AND n.nspname = 'crm') THEN
        CREATE TYPE contact_category AS ENUM ('individual', 'architect', 'pmc', 'vendor');
    END IF;
END $$;

-- Add category column to contacts if missing (it might be in V009)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'crm' AND table_name = 'contacts' AND column_name = 'category') THEN
        ALTER TABLE contacts ADD COLUMN category contact_category DEFAULT 'individual';
    END IF;
END $$;
