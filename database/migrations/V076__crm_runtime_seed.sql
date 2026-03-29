SET search_path = crm, public;

INSERT INTO permissions (module, action, slug, description)
SELECT src.module, src.action, src.slug, src.description
FROM (
    VALUES
        ('settings', 'view', 'settings:view', 'View runtime settings and metadata'),
        ('dynamic', 'view', 'dynamic:view', 'View generic runtime entities'),
        ('dynamic', 'create', 'dynamic:create', 'Create generic runtime entities'),
        ('dynamic', 'update', 'dynamic:update', 'Update generic runtime entities'),
        ('dynamic', 'delete', 'dynamic:delete', 'Delete generic runtime entities'),
        ('dynamic', 'bulk', 'dynamic:bulk', 'Bulk update generic runtime entities'),
        ('dynamic', 'action', 'dynamic:action', 'Execute generic runtime actions'),
        ('accounts', 'manage', 'accounts:manage', 'Manage CRM accounts'),
        ('rbac', 'manage', 'rbac:manage', 'Manage roles and permissions'),
        ('users', 'manage', 'users:manage', 'Manage application users')
) AS src(module, action, slug, description)
WHERE NOT EXISTS (
    SELECT 1
    FROM permissions p
    WHERE p.slug = src.slug
      AND p.deleted_at IS NULL
);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.deleted_at IS NULL
WHERE r.slug = 'admin'
  AND NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      WHERE rp.role_id = r.id
        AND rp.permission_id = p.id
  );

INSERT INTO lookup_sets (set_key, label, description, is_system)
SELECT src.set_key, src.label, src.description, TRUE
FROM (
    VALUES
        ('lead_source', 'Lead Source', 'Lead acquisition sources'),
        ('lead_stage', 'Lead Stage', 'Commercial pipeline stages'),
        ('lead_category', 'Lead Category', 'Lead categories'),
        ('account_type', 'Account Type', 'Customer account types'),
        ('project_status', 'Project Status', 'Project lifecycle states'),
        ('project_health', 'Project Health', 'Project health indicators'),
        ('project_type', 'Project Type', 'Project types'),
        ('task_status', 'Task Status', 'Task lifecycle states'),
        ('task_priority', 'Task Priority', 'Task priority levels'),
        ('document_status', 'Document Status', 'Document workflow states'),
        ('document_share_mode', 'Document Share Mode', 'Document sharing modes'),
        ('quotation_status', 'Quotation Status', 'Quotation lifecycle states'),
        ('expense_category', 'Expense Category', 'Expense categories'),
        ('workflow_event', 'Workflow Event', 'Workflow trigger events')
) AS src(set_key, label, description)
WHERE NOT EXISTS (
    SELECT 1
    FROM lookup_sets ls
    WHERE ls.set_key = src.set_key
      AND ls.deleted_at IS NULL
);

INSERT INTO lookup_values (set_id, value_key, label, sort_order, is_default, color, value_json)
SELECT ls.id, src.value_key, src.label, src.sort_order, src.is_default, src.color, '{}'::jsonb
FROM lookup_sets ls
JOIN (
    VALUES
        ('lead_source', 'website', 'Website', 1, TRUE, '#2563eb'),
        ('lead_source', 'referral', 'Referral', 2, FALSE, '#0f766e'),
        ('lead_source', 'social_media', 'Social Media', 3, FALSE, '#7c3aed'),
        ('lead_source', 'cold_call', 'Cold Call', 4, FALSE, '#b45309'),
        ('lead_source', 'email_campaign', 'Email Campaign', 5, FALSE, '#0ea5e9'),
        ('lead_source', 'event', 'Event', 6, FALSE, '#d946ef'),
        ('lead_source', 'partner', 'Partner', 7, FALSE, '#16a34a'),
        ('lead_source', 'other', 'Other', 8, FALSE, '#6b7280'),
        ('lead_stage', 'new', 'New', 1, TRUE, '#2563eb'),
        ('lead_stage', 'contacted', 'Contacted', 2, FALSE, '#0ea5e9'),
        ('lead_stage', 'qualified', 'Qualified', 3, FALSE, '#16a34a'),
        ('lead_stage', 'proposal_sent', 'Proposal Sent', 4, FALSE, '#7c3aed'),
        ('lead_stage', 'negotiation', 'Negotiation', 5, FALSE, '#d97706'),
        ('lead_stage', 'won', 'Won', 6, FALSE, '#15803d'),
        ('lead_stage', 'lost', 'Lost', 7, FALSE, '#dc2626'),
        ('lead_category', 'residential', 'Residential', 1, TRUE, '#2563eb'),
        ('lead_category', 'commercial', 'Commercial', 2, FALSE, '#0f766e'),
        ('lead_category', 'retail', 'Retail', 3, FALSE, '#7c3aed'),
        ('lead_category', 'industrial', 'Industrial', 4, FALSE, '#b45309'),
        ('account_type', 'company', 'Company', 1, TRUE, '#2563eb'),
        ('account_type', 'individual', 'Individual', 2, FALSE, '#0f766e'),
        ('account_type', 'partner', 'Partner', 3, FALSE, '#7c3aed'),
        ('project_status', 'planning', 'Planning', 1, TRUE, '#2563eb'),
        ('project_status', 'active', 'Active', 2, FALSE, '#16a34a'),
        ('project_status', 'on_hold', 'On Hold', 3, FALSE, '#d97706'),
        ('project_status', 'completed', 'Completed', 4, FALSE, '#15803d'),
        ('project_status', 'cancelled', 'Cancelled', 5, FALSE, '#dc2626'),
        ('project_status', 'archived', 'Archived', 6, FALSE, '#6b7280'),
        ('project_health', 'green', 'Green', 1, TRUE, '#16a34a'),
        ('project_health', 'amber', 'Amber', 2, FALSE, '#d97706'),
        ('project_health', 'red', 'Red', 3, FALSE, '#dc2626'),
        ('project_type', 'implementation', 'Implementation', 1, TRUE, '#2563eb'),
        ('project_type', 'design', 'Design', 2, FALSE, '#7c3aed'),
        ('project_type', 'support', 'Support', 3, FALSE, '#0f766e'),
        ('task_status', 'todo', 'To Do', 1, TRUE, '#2563eb'),
        ('task_status', 'in_progress', 'In Progress', 2, FALSE, '#0ea5e9'),
        ('task_status', 'under_review', 'Under Review', 3, FALSE, '#7c3aed'),
        ('task_status', 'completed', 'Completed', 4, FALSE, '#16a34a'),
        ('task_status', 'cancelled', 'Cancelled', 5, FALSE, '#dc2626'),
        ('task_status', 'blocked', 'Blocked', 6, FALSE, '#b45309'),
        ('task_priority', 'low', 'Low', 1, FALSE, '#6b7280'),
        ('task_priority', 'medium', 'Medium', 2, TRUE, '#2563eb'),
        ('task_priority', 'high', 'High', 3, FALSE, '#d97706'),
        ('task_priority', 'critical', 'Critical', 4, FALSE, '#dc2626'),
        ('document_status', 'draft', 'Draft', 1, TRUE, '#6b7280'),
        ('document_status', 'pending_approval', 'Pending Approval', 2, FALSE, '#d97706'),
        ('document_status', 'approved', 'Approved', 3, FALSE, '#16a34a'),
        ('document_status', 'rejected', 'Rejected', 4, FALSE, '#dc2626'),
        ('document_status', 'archived', 'Archived', 5, FALSE, '#4b5563'),
        ('document_share_mode', 'internal', 'Internal', 1, TRUE, '#2563eb'),
        ('document_share_mode', 'client', 'Client', 2, FALSE, '#0f766e'),
        ('document_share_mode', 'public', 'Public', 3, FALSE, '#7c3aed'),
        ('quotation_status', 'draft', 'Draft', 1, TRUE, '#6b7280'),
        ('quotation_status', 'sent', 'Sent', 2, FALSE, '#2563eb'),
        ('quotation_status', 'accepted', 'Accepted', 3, FALSE, '#16a34a'),
        ('quotation_status', 'rejected', 'Rejected', 4, FALSE, '#dc2626'),
        ('quotation_status', 'expired', 'Expired', 5, FALSE, '#4b5563'),
        ('expense_category', 'travel', 'Travel', 1, FALSE, '#2563eb'),
        ('expense_category', 'materials', 'Materials', 2, TRUE, '#16a34a'),
        ('expense_category', 'labor', 'Labor', 3, FALSE, '#d97706'),
        ('expense_category', 'software', 'Software', 4, FALSE, '#7c3aed'),
        ('expense_category', 'marketing', 'Marketing', 5, FALSE, '#0ea5e9'),
        ('expense_category', 'other', 'Other', 6, FALSE, '#6b7280'),
        ('workflow_event', 'lead_created', 'Lead Created', 1, TRUE, '#2563eb'),
        ('workflow_event', 'status_changed', 'Lead Status Changed', 2, FALSE, '#0ea5e9'),
        ('workflow_event', 'lead_converted', 'Lead Converted', 3, FALSE, '#16a34a'),
        ('workflow_event', 'task_created', 'Task Created', 4, FALSE, '#7c3aed'),
        ('workflow_event', 'task_status_changed', 'Task Status Changed', 5, FALSE, '#d97706')
) AS src(set_key, value_key, label, sort_order, is_default, color)
    ON src.set_key = ls.set_key
WHERE NOT EXISTS (
    SELECT 1
    FROM lookup_values lv
    WHERE lv.set_id = ls.id
      AND lv.value_key = src.value_key
      AND lv.deleted_at IS NULL
);

INSERT INTO ui_entity_configs (
    entity_key, label, table_name, primary_key, title_column, default_sort_column,
    permission_slug, form_key, route_base, supports_tags, supports_custom_fields, is_system, sample_payload_json, metadata
)
SELECT
    src.entity_key, src.label, src.table_name, 'id', src.title_column, src.default_sort_column,
    src.permission_slug, src.entity_key, src.route_base, src.supports_tags, TRUE, FALSE, src.sample_payload_json::jsonb, src.metadata::jsonb
FROM (
    VALUES
        ('lead', 'Lead', 'leads', 'title', 'created_at', 'leads:manage', '/api/data/lead', TRUE, '{"create":{"title":"Interior design for 3BHK","source":"website","category":"residential","stage":"new","estimatedValue":1500000},"update":{"id":"uuid","stage":"qualified","probability":65},"list":{"page":1,"limit":20,"q":"villa"}}', '{"module":"sales"}'),
        ('contact', 'Contact', 'contacts', 'first_name', 'created_at', 'contacts:manage', '/api/data/contact', TRUE, '{"create":{"firstName":"John","lastName":"Doe","email":"john@example.com","category":"architect"},"update":{"id":"uuid","designation":"Principal Architect"},"list":{"page":1,"limit":20}}', '{"module":"crm"}'),
        ('account', 'Account', 'accounts', 'name', 'created_at', 'accounts:manage', '/api/data/account', TRUE, '{"create":{"name":"Acme Interiors","type":"company","industry":"real-estate"},"update":{"id":"uuid","website":"https://example.com"},"list":{"page":1,"limit":20}}', '{"module":"crm"}'),
        ('project', 'Project', 'projects', 'title', 'created_at', 'projects:manage', '/api/data/project', TRUE, '{"create":{"title":"Sector 45 Villa","status":"planning","budget":2500000},"update":{"id":"uuid","status":"active","health":"green"},"list":{"page":1,"limit":20}}', '{"module":"delivery"}'),
        ('task', 'Task', 'tasks', 'title', 'created_at', 'tasks:manage', '/api/data/task', TRUE, '{"create":{"projectId":"uuid","title":"Site measurement","priority":"high","status":"todo"},"update":{"id":"uuid","status":"in_progress"},"list":{"page":1,"limit":20}}', '{"module":"delivery"}'),
        ('communication', 'Communication', 'communications', 'subject', 'performed_at', 'communications:manage', '/api/data/communication', FALSE, '{"create":{"entityType":"lead","entityId":"uuid","channel":"call","subject":"Discovery call"},"update":{"id":"uuid","summary":"Client requested revised timeline"},"list":{"entityType":"lead","entityId":"uuid"}}', '{"module":"engagement"}'),
        ('document', 'Document', 'documents', 'title', 'created_at', 'documents:manage', '/api/data/document', TRUE, '{"create":{"entityType":"project","entityId":"uuid","title":"Contract Copy","category":"contract"},"update":{"id":"uuid","approvalRequired":true},"list":{"entityType":"project","entityId":"uuid"}}', '{"module":"documents"}'),
        ('quotation', 'Quotation', 'quotations', 'quotation_number', 'created_at', 'quotations:manage', '/api/data/quotation', FALSE, '{"create":{"leadId":"uuid","currency":"INR","lineItems":[{"description":"Service A","quantity":1,"unitPrice":1000}],"discount":0},"update":{"id":"uuid","status":"sent"},"list":{"page":1,"limit":20}}', '{"module":"finance"}'),
        ('expense', 'Expense', 'expenses', 'description', 'created_at', 'expenses:manage', '/api/data/expense', FALSE, '{"create":{"projectId":"uuid","category":"materials","amount":1200,"currency":"INR"},"update":{"id":"uuid","description":"Updated receipt notes"},"list":{"page":1,"limit":20}}', '{"module":"finance"}')
) AS src(entity_key, label, table_name, title_column, default_sort_column, permission_slug, route_base, supports_tags, sample_payload_json, metadata)
WHERE NOT EXISTS (
    SELECT 1
    FROM ui_entity_configs e
    WHERE e.entity_key = src.entity_key
      AND e.deleted_at IS NULL
);

INSERT INTO report_definitions (report_key, label, description, definition_json)
SELECT src.report_key, src.label, src.description, src.definition_json::jsonb
FROM (
    VALUES
        ('pipeline_overview', 'Pipeline Overview', 'Lead pipeline conversion summary', '{"entity":"lead","metrics":["count","estimatedValue","stage"]}'),
        ('revenue_forecast', 'Revenue Forecast', 'Expected quotation and project revenue', '{"entity":"quotation","metrics":["subtotal_amount","tax_amount","total_amount"]}'),
        ('project_health', 'Project Health', 'Project delivery status and health signals', '{"entity":"project","metrics":["status","health","percent_complete","budget"]}'),
        ('expense_summary', 'Expense Summary', 'Project expense trend summary', '{"entity":"expense","metrics":["amount","tax_amount","category"]}'),
        ('task_workload', 'Task Workload', 'Task ownership and SLA distribution', '{"entity":"task","metrics":["status","priority","estimated_hours","escalation_sla_hours"]}')
) AS src(report_key, label, description, definition_json)
WHERE NOT EXISTS (
    SELECT 1
    FROM report_definitions rd
    WHERE rd.report_key = src.report_key
      AND rd.deleted_at IS NULL
);

INSERT INTO ui_field_configs (
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, is_readonly, include_in_list, include_in_detail, include_in_create, include_in_update,
    lookup_set_key, sample_value_json, config_json
)
SELECT
    src.entity_key, src.field_key, src.label, src.column_name, src.data_type, src.sort_order, src.is_required,
    src.is_filterable, src.is_sortable, FALSE, src.include_in_list, TRUE, src.include_in_create, src.include_in_update,
    src.lookup_set_key, src.sample_value_json::jsonb, src.config_json::jsonb
FROM (
    VALUES
        ('lead','title','Title','title','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Interior design for 3BHK"','{}'),
        ('lead','description','Description','description','text',20,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Lead created by website form"','{}'),
        ('lead','status','Status','status','lead_status',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'lead_stage','"new"','{}'),
        ('lead','source','Source','source','lead_source',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'lead_source','"website"','{}'),
        ('lead','category','Category','category','text',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'lead_category','"residential"','{}'),
        ('lead','stage','Stage','stage','text',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'lead_stage','"new"','{}'),
        ('lead','accountId','Account','account_id','uuid',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('lead','primaryContactId','Primary Contact','primary_contact_id','uuid',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('lead','contactId','Contact','contact_id','uuid',81,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{"legacy":true}'),
        ('lead','phone','Phone','phone','text',90,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"+1-202-555-0111"','{}'),
        ('lead','email','Email','email','text',100,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"lead@example.com"','{}'),
        ('lead','estimatedValue','Estimated Value','estimated_value','numeric',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'1500000','{}'),
        ('lead','budgetMin','Budget Min','budget_min','numeric',120,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'1000000','{}'),
        ('lead','budgetMax','Budget Max','budget_max','numeric',130,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'2000000','{}'),
        ('lead','ownerId','Owner','owner_id','uuid',140,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('lead','assignedTo','Assigned To','assigned_to','uuid',141,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{"legacy":true}'),
        ('lead','expectedCloseAt','Expected Close','expected_close_at','timestamptz',150,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-06-01T00:00:00Z"','{}'),
        ('lead','nextFollowUpAt','Next Follow Up','next_follow_up_at','timestamptz',160,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-04-01T10:00:00Z"','{}'),
        ('lead','probability','Probability','probability','integer',170,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'65','{}'),
        ('lead','requirementSummary','Requirement Summary','requirement_summary','text',180,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"3BHK full interior scope"','{}'),
        ('lead','lostReason','Lost Reason','lost_reason','text',190,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Budget mismatch"','{}'),
        ('lead','tags','Tags',NULL,'jsonb',200,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'["priority","hot"]','{"storage":"record_tags"}'),

        ('contact','firstName','First Name','first_name','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"John"','{}'),
        ('contact','lastName','Last Name','last_name','text',20,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Doe"','{}'),
        ('contact','email','Email','email','text',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"john@example.com"','{}'),
        ('contact','phone','Phone','phone','text',40,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"+1-202-555-0112"','{}'),
        ('contact','altPhone','Alternate Phone','alt_phone','text',50,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"+1-202-555-0113"','{}'),
        ('contact','designation','Designation','designation','text',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Principal Architect"','{}'),
        ('contact','category','Category','category','contact_category',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'contact_category','"architect"','{}'),
        ('contact','accountId','Account','account_id','uuid',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('contact','companyName','Company Name','company_name','text',81,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Acme Interiors"','{"legacy":true}'),
        ('contact','isPrimary','Primary Contact','is_primary','boolean',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'true','{}'),
        ('contact','address','Address','address','text',100,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"123 Main Street"','{}'),
        ('contact','city','City','city','text',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"New York"','{}'),
        ('contact','state','State','state','text',120,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"NY"','{}'),
        ('contact','country','Country','country','text',130,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"USA"','{}'),
        ('contact','postalCode','Postal Code','postal_code','text',140,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"10001"','{}'),
        ('contact','timezone','Timezone','timezone','text',150,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"America/New_York"','{}'),
        ('contact','notes','Notes','notes','text',160,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Important stakeholder"','{}'),

        ('account','name','Account Name','name','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Acme Interiors"','{}'),
        ('account','type','Type','type','text',20,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'account_type','"company"','{}'),
        ('account','industry','Industry','industry','text',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Real Estate"','{}'),
        ('account','website','Website','website','text',40,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"https://example.com"','{}'),
        ('account','ownerId','Owner','owner_id','uuid',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('account','primaryAddress','Primary Address','primary_address','text',60,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"123 Main Street"','{}'),
        ('account','billingAddress','Billing Address','billing_address','text',70,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"456 Billing Avenue"','{}'),
        ('account','taxId','Tax ID','tax_id','text',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"GST-1234"','{}'),
        ('account','notes','Notes','notes','text',90,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Key enterprise account"','{}'),

        ('project','title','Title','title','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Sector 45 Villa"','{}'),
        ('project','description','Description','description','text',20,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Premium interior execution"','{}'),
        ('project','leadId','Lead','lead_id','uuid',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('project','accountId','Account','account_id','uuid',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('project','contactId','Contact','contact_id','uuid',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('project','templateId','Template','template_id','uuid',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('project','projectType','Project Type','project_type','text',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'project_type','"implementation"','{}'),
        ('project','managerId','Manager','project_manager_id','uuid',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('project','projectManagerId','Project Manager','project_manager_id','uuid',81,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{"legacy":true}'),
        ('project','status','Status','status','project_status',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'project_status','"planning"','{}'),
        ('project','health','Health','health','text',100,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'project_health','"green"','{}'),
        ('project','budget','Budget','budget','numeric',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'2500000','{}'),
        ('project','estimatedValue','Estimated Value','estimated_value','numeric',111,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'2500000','{"legacy":true}'),
        ('project','startDate','Start Date','start_date','timestamptz',120,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-04-01T00:00:00Z"','{}'),
        ('project','endDate','End Date','end_date','timestamptz',130,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-09-30T00:00:00Z"','{}'),
        ('project','location','Location','location','text',140,FALSE,TRUE,FALSE,TRUE,TRUE,TRUE,NULL,'"Gurugram"','{}'),
        ('project','percentComplete','Percent Complete','percent_complete','numeric',150,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'20','{}'),

        ('task','projectId','Project','project_id','uuid',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('task','phaseId','Phase','phase_id','uuid',20,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('task','milestoneId','Milestone','milestone_id','uuid',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('task','parentTaskId','Parent Task','parent_task_id','uuid',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('task','title','Title','title','text',50,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Site measurement"','{}'),
        ('task','description','Description','description','text',60,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Complete physical site measurement"','{}'),
        ('task','assigneeId','Assignee','assigned_to','uuid',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('task','assignedTo','Assigned To','assigned_to','uuid',71,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{"legacy":true}'),
        ('task','priority','Priority','priority','task_priority',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'task_priority','"high"','{}'),
        ('task','status','Status','status','task_status',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'task_status','"todo"','{}'),
        ('task','plannedStartAt','Planned Start','planned_start_at','timestamptz',100,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-04-01T09:00:00Z"','{}'),
        ('task','startDate','Start Date','start_date','timestamptz',101,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"2026-04-01T09:00:00Z"','{"legacy":true}'),
        ('task','dueAt','Due At','due_date','timestamptz',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-04-02T18:00:00Z"','{}'),
        ('task','dueDate','Due Date','due_date','timestamptz',111,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"2026-04-02T18:00:00Z"','{"legacy":true}'),
        ('task','estimatedHours','Estimated Hours','estimated_hours','numeric',120,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'8','{}'),
        ('task','dependencyIds','Dependencies',NULL,'jsonb',130,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'["00000000-0000-0000-0000-000000000000"]','{"storage":"task_dependencies"}'),
        ('task','watcherIds','Watchers',NULL,'jsonb',140,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'["00000000-0000-0000-0000-000000000000"]','{"storage":"task_watchers"}')
) AS src(
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, include_in_list, include_in_create, include_in_update,
    lookup_set_key, sample_value_json, config_json
)
WHERE NOT EXISTS (
    SELECT 1
    FROM ui_field_configs f
    WHERE f.entity_key = src.entity_key
      AND f.field_key = src.field_key
      AND f.deleted_at IS NULL
);

INSERT INTO ui_field_configs (
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, is_readonly, include_in_list, include_in_detail, include_in_create, include_in_update,
    lookup_set_key, sample_value_json, config_json
)
SELECT
    src.entity_key, src.field_key, src.label, src.column_name, src.data_type, src.sort_order, src.is_required,
    src.is_filterable, src.is_sortable, FALSE, src.include_in_list, TRUE, src.include_in_create, src.include_in_update,
    src.lookup_set_key, src.sample_value_json::jsonb, src.config_json::jsonb
FROM (
    VALUES
        ('communication','entityType','Entity Type','entity_type','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"lead"','{}'),
        ('communication','moduleName','Module Name','module_name','text',11,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"leads"','{"legacy":true}'),
        ('communication','entityId','Entity ID','entity_id','uuid',20,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('communication','contactId','Contact','contact_id','uuid',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('communication','channel','Channel','channel','text',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"call"','{}'),
        ('communication','type','Type','type','communication_type',41,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"call"','{"legacy":true}'),
        ('communication','direction','Direction','direction','text',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"outbound"','{}'),
        ('communication','subject','Subject','subject','text',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Discovery call"','{}'),
        ('communication','summary','Summary','summary','text',70,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'"Client requested revised timeline"','{}'),
        ('communication','content','Content','content','text',71,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Detailed communication log"','{"legacy":true}'),
        ('communication','occurredAt','Occurred At','performed_at','timestamptz',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-03-28T10:00:00Z"','{}'),
        ('communication','nextActionAt','Next Action','next_action_at','timestamptz',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-03-30T10:00:00Z"','{}'),
        ('communication','participantIds','Participants','participant_ids','jsonb',100,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'["00000000-0000-0000-0000-000000000000"]','{}'),

        ('document','entityType','Entity Type','entity_type','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"project"','{}'),
        ('document','moduleName','Module Name','module_name','text',11,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'"projects"','{"legacy":true}'),
        ('document','entityId','Entity ID','entity_id','uuid',20,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('document','category','Category','category','text',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"contract"','{}'),
        ('document','title','Title','title','text',40,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Contract Copy"','{}'),
        ('document','fileName','File Name','file_name','text',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"contract.pdf"','{}'),
        ('document','filePath','File Path','file_path','text',60,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"/uploads/contract.pdf"','{}'),
        ('document','fileType','File Type','file_type','text',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"application/pdf"','{}'),
        ('document','fileSize','File Size','file_size','bigint',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'1048576','{}'),
        ('document','versionLabel','Version Label','version_label','text',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"v1"','{}'),
        ('document','approvalRequired','Approval Required','approval_required','boolean',100,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'true','{}'),
        ('document','shareMode','Share Mode','share_mode','text',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'document_share_mode','"internal"','{}'),

        ('quotation','leadId','Lead','lead_id','uuid',10,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('quotation','projectId','Project','project_id','uuid',20,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('quotation','accountId','Account','account_id','uuid',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('quotation','contactId','Contact','contact_id','uuid',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('quotation','currency','Currency','currency','text',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"INR"','{}'),
        ('quotation','validUntil','Valid Until','valid_until','timestamptz',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-04-30T00:00:00Z"','{}'),
        ('quotation','taxMode','Tax Mode','tax_mode','text',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"exclusive"','{}'),
        ('quotation','discount','Discount','discount','numeric',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'0','{}'),
        ('quotation','terms','Terms','terms','text',90,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"50% advance, balance on completion"','{}'),
        ('quotation','notes','Notes','notes','text',100,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'"Quote fin-001"','{}'),
        ('quotation','status','Status','status','quotation_status',110,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'quotation_status','"draft"','{}'),
        ('quotation','lineItems','Line Items',NULL,'jsonb',120,TRUE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'[{"description":"Service A","quantity":1,"unitPrice":1000}]','{"storage":"quotation_items"}'),
        ('quotation','items','Items',NULL,'jsonb',121,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'[{"description":"Service A","quantity":1,"unitPrice":1000}]','{"legacy":true,"storage":"quotation_items"}'),

        ('expense','projectId','Project','project_id','uuid',10,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('expense','category','Category','category','expense_category',20,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,'expense_category','"materials"','{}'),
        ('expense','vendorId','Vendor','vendor_id','uuid',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('expense','amount','Amount','amount','numeric',40,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'1200','{}'),
        ('expense','currency','Currency','currency','text',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"INR"','{}'),
        ('expense','expenseDate','Expense Date','expense_date','date',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-03-28"','{}'),
        ('expense','description','Description','description','text',70,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'"Site material purchase"','{}'),
        ('expense','receiptDocumentId','Receipt Document','receipt_document_id','uuid',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('expense','status','Status','status','text',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"submitted"','{}'),
        ('expense','taxAmount','Tax Amount','tax_amount','numeric',100,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'0','{}')
) AS src(
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, include_in_list, include_in_create, include_in_update,
    lookup_set_key, sample_value_json, config_json
)
WHERE NOT EXISTS (
    SELECT 1
    FROM ui_field_configs f
    WHERE f.entity_key = src.entity_key
      AND f.field_key = src.field_key
      AND f.deleted_at IS NULL
);

INSERT INTO api_endpoint_registry (
    endpoint_key, entity_key, action_key, dispatcher_fn, permission_slug, form_key, http_method, route_path,
    auth_mode, is_public, request_schema_json, response_schema_json, filter_schema_json, sample_payload_json, metadata
)
SELECT
    src.endpoint_key, src.entity_key, src.action_key, src.dispatcher_fn, src.permission_slug, src.form_key, src.http_method, src.route_path,
    src.auth_mode, src.is_public, src.request_schema_json::jsonb, src.response_schema_json::jsonb, src.filter_schema_json::jsonb, src.sample_payload_json::jsonb, src.metadata::jsonb
FROM (
    VALUES
        ('meta.bootstrap',NULL,NULL,'fn_metadata_operations','settings:view',NULL,'GET','/api/meta/bootstrap','session',FALSE,'{}','{"rid":"s-meta-bootstrap"}','{}','{}','{"category":"meta"}'),
        ('meta.entities',NULL,NULL,'fn_metadata_operations','settings:view',NULL,'GET','/api/meta/entities','session',FALSE,'{}','{"rid":"s-meta-entities-listed"}','{}','{}','{"category":"meta"}'),
        ('meta.entity',NULL,NULL,'fn_metadata_operations','settings:view',NULL,'GET','/api/meta/entities/:entityKey','session',FALSE,'{"entityKey":"lead"}','{"rid":"s-meta-entity-loaded"}','{}','{}','{"category":"meta"}'),
        ('data.list',NULL,NULL,'fn_data_operations','dynamic:view',NULL,'POST','/api/data/:entityKey/list','session',FALSE,'{"page":1,"limit":20}','{"rid":"s-data-operation-complete"}','{"q":"villa"}','{"page":1,"limit":20}','{"category":"runtime"}'),
        ('data.get',NULL,NULL,'fn_data_operations','dynamic:view',NULL,'POST','/api/data/:entityKey/get','session',FALSE,'{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}','{"id":"uuid"}','{"category":"runtime"}'),
        ('data.create',NULL,NULL,'fn_data_operations','dynamic:create',NULL,'POST','/api/data/:entityKey/create','session',FALSE,'{"title":"Example"}','{"rid":"s-data-operation-complete"}','{}','{"title":"Example"}','{"category":"runtime"}'),
        ('data.update',NULL,NULL,'fn_data_operations','dynamic:update',NULL,'POST','/api/data/:entityKey/update','session',FALSE,'{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}','{"id":"uuid"}','{"category":"runtime"}'),
        ('data.delete',NULL,NULL,'fn_data_operations','dynamic:delete',NULL,'POST','/api/data/:entityKey/delete','session',FALSE,'{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}','{"id":"uuid"}','{"category":"runtime"}'),
        ('data.bulk',NULL,NULL,'fn_data_operations','dynamic:bulk',NULL,'POST','/api/data/:entityKey/bulk','session',FALSE,'{"ids":["uuid-1","uuid-2"],"action":"archive"}','{"rid":"s-data-operation-complete"}','{}','{"ids":["uuid-1","uuid-2"],"action":"archive"}','{"category":"runtime"}'),
        ('action.execute',NULL,NULL,'fn_action_operations','dynamic:action',NULL,'POST','/api/action/:actionKey','session',FALSE,'{"action":"lead.convert"}','{"rid":"s-action-complete"}','{}','{"id":"uuid"}','{"category":"runtime"}'),
        ('contract.frontend',NULL,NULL,'fn_contract_operations','public',NULL,'GET','/api/contracts/frontend','public',TRUE,'{}','{"rid":"s-frontend-contract"}','{}','{}','{"category":"contract"}'),
        ('dashboard.stats',NULL,'dashboard.stats','fn_dashboard_operations','dashboard:view',NULL,'GET','/api/dashboard/stats','session',FALSE,'{}','{"rid":"s-dashboard-stats"}','{}','{}','{"category":"alias"}'),
        ('report.generate',NULL,'report.generate','fn_report_operations','reports:manage',NULL,'GET','/api/reports','session',FALSE,'{"type":"pipeline_overview"}','{"rid":"s-report-generated"}','{}','{"type":"pipeline_overview"}','{"category":"alias"}'),
        ('report.export_csv',NULL,'report.export_csv','fn_report_operations','reports:manage',NULL,'GET','/api/reports/export','session',FALSE,'{"type":"leads"}','{"rid":"s-report-exported"}','{}','{"type":"leads"}','{"category":"alias"}'),
        ('search.global',NULL,'search.global','fn_search_operations','dynamic:view',NULL,'GET','/api/search','session',FALSE,'{"q":"villa"}','{"rid":"s-search-results"}','{}','{"q":"villa"}','{"category":"alias"}'),
        ('audit.list_logs',NULL,'audit.list_logs','fn_audit_operations','settings:view',NULL,'GET','/api/audit','session',FALSE,'{}','{"rid":"s-audit-logs-listed"}','{}','{}','{"category":"alias"}'),
        ('action.lead.update_status','lead','lead.update_status','fn_action_operations','leads:manage','lead','POST','/api/action/lead.update_status','session',FALSE,'{"id":"uuid","status":"qualified"}','{"rid":"s-lead-status-updated"}','{}','{"id":"uuid","status":"qualified"}','{"category":"action"}'),
        ('action.lead.convert','lead','lead.convert','fn_action_operations','leads:manage','lead','POST','/api/action/lead.convert','session',FALSE,'{"id":"uuid","templateId":"uuid"}','{"rid":"s-lead-converted"}','{}','{"id":"uuid","templateId":"uuid"}','{"category":"action"}'),
        ('action.document.upload','document','document.upload','fn_action_operations','documents:manage','document','POST','/api/action/document.upload','session',FALSE,'{"title":"Contract","entityType":"project"}','{"rid":"s-document-uploaded"}','{}','{"title":"Contract","entityType":"project"}','{"category":"action"}'),
        ('action.document.approve','document','document.approve','fn_action_operations','documents:manage','document','POST','/api/action/document.approve','session',FALSE,'{"id":"uuid","decision":"approved"}','{"rid":"s-document-approved"}','{}','{"id":"uuid","decision":"approved"}','{"category":"action"}'),
        ('action.document.share','document','document.share','fn_action_operations','documents:manage','document','POST','/api/action/document.share','session',FALSE,'{"id":"uuid","email":"client@example.com"}','{"rid":"s-document-shared"}','{}','{"id":"uuid","email":"client@example.com"}','{"category":"action"}'),
        ('action.share.resolve','document','share.resolve','fn_action_operations','public','document','GET','/api/share/:token','public',TRUE,'{"token":"token"}','{"rid":"s-share-resolved"}','{}','{"token":"token"}','{"category":"action"}'),
        ('action.workflow.run_due',NULL,'workflow.run_due','fn_action_operations','settings:manage',NULL,'POST','/api/action/workflow.run_due','session',FALSE,'{}','{"rid":"s-workflows-run"}','{}','{}','{"category":"action"}')
) AS src(
    endpoint_key, entity_key, action_key, dispatcher_fn, permission_slug, form_key, http_method, route_path,
    auth_mode, is_public, request_schema_json, response_schema_json, filter_schema_json, sample_payload_json, metadata
)
WHERE NOT EXISTS (
    SELECT 1
    FROM api_endpoint_registry aer
    WHERE aer.endpoint_key = src.endpoint_key
      AND aer.deleted_at IS NULL
);

INSERT INTO api_endpoint_registry (
    endpoint_key, entity_key, dispatcher_fn, permission_slug, form_key, http_method, route_path,
    auth_mode, is_public, request_schema_json, response_schema_json, filter_schema_json, sample_payload_json, metadata
)
SELECT
    format('data.%s.%s', e.entity_key, op.operation),
    e.entity_key,
    'fn_data_operations',
    CASE
        WHEN op.operation IN ('list', 'get') THEN 'dynamic:view'
        WHEN op.operation = 'create' THEN 'dynamic:create'
        WHEN op.operation = 'update' THEN 'dynamic:update'
        WHEN op.operation = 'delete' THEN 'dynamic:delete'
        ELSE 'dynamic:bulk'
    END,
    e.form_key,
    'POST',
    format('/api/data/%s/%s', e.entity_key, op.route_suffix),
    'session',
    FALSE,
    op.request_schema_json::jsonb,
    op.response_schema_json::jsonb,
    op.filter_schema_json::jsonb,
    CASE
        WHEN op.operation = 'list' THEN COALESCE(e.sample_payload_json->'list', '{}'::jsonb)
        WHEN op.operation = 'create' THEN COALESCE(e.sample_payload_json->'create', '{}'::jsonb)
        WHEN op.operation = 'update' THEN COALESCE(e.sample_payload_json->'update', '{}'::jsonb)
        WHEN op.operation IN ('get', 'delete') THEN '{"id":"uuid"}'::jsonb
        ELSE '{"ids":["uuid-1","uuid-2"],"action":"archive"}'::jsonb
    END,
    jsonb_build_object('category', 'entity-runtime')
FROM ui_entity_configs e
CROSS JOIN (
    VALUES
        ('list','list','{"page":1,"limit":20}','{"rid":"s-data-operation-complete"}','{"q":"villa"}'),
        ('get','get','{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}'),
        ('create','create','{"title":"Example"}','{"rid":"s-data-operation-complete"}','{}'),
        ('update','update','{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}'),
        ('delete','delete','{"id":"uuid"}','{"rid":"s-data-operation-complete"}','{}'),
        ('bulk','bulk','{"ids":["uuid-1","uuid-2"],"action":"archive"}','{"rid":"s-data-operation-complete"}','{}')
) AS op(operation, route_suffix, request_schema_json, response_schema_json, filter_schema_json)
WHERE e.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM api_endpoint_registry aer
      WHERE aer.endpoint_key = format('data.%s.%s', e.entity_key, op.operation)
        AND aer.deleted_at IS NULL
  );
