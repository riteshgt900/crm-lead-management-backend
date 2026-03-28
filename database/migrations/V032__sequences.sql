SET search_path = crm, public;
-- V032: Sequences and Number Generation

CREATE SEQUENCE IF NOT EXISTS lead_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS project_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS task_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS quotation_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_lead_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'LEAD-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('lead_number_seq')::TEXT, 4, '0');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_project_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'PROJ-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('project_number_seq')::TEXT, 4, '0');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_task_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'TASK-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('task_number_seq')::TEXT, 4, '0');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_quotation_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'QUOT-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('quotation_number_seq')::TEXT, 4, '0');
END; $$ LANGUAGE plpgsql;

