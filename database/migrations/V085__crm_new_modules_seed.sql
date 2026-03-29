SET search_path = crm, public;

-- V085: Seed data for new modules
-- Inserts permissions, lookup sets/values, ui_entity_configs, ui_field_configs, api_endpoint_registry
-- for Opportunities, Activities, Notes, Assignments, and SLAs

-- ─────────────────────────────────────────────
-- PERMISSIONS
-- ─────────────────────────────────────────────
INSERT INTO permissions (module, action, slug, description)
SELECT src.module, src.action, src.slug, src.description
FROM (
    VALUES
        ('opportunities', 'manage', 'opportunities:manage', 'Manage CRM opportunities and deal pipeline'),
        ('activities',    'manage', 'activities:manage',    'Log and view activity timeline entries'),
        ('notes',         'manage', 'notes:manage',         'Create and manage entity notes'),
        ('assignments',   'manage', 'assignments:manage',   'Manage assignment pools and history'),
        ('slas',          'manage', 'slas:manage',          'Manage SLA policies and escalations')
) AS src(module, action, slug, description)
WHERE NOT EXISTS (
    SELECT 1 FROM permissions p WHERE p.slug = src.slug AND p.deleted_at IS NULL
);

-- Grant all new permissions to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.deleted_at IS NULL
WHERE r.slug = 'admin'
  AND p.slug IN ('opportunities:manage','activities:manage','notes:manage','assignments:manage','slas:manage')
  AND NOT EXISTS (
      SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- ─────────────────────────────────────────────
-- LOOKUP SETS
-- ─────────────────────────────────────────────
INSERT INTO lookup_sets (set_key, label, description, is_system)
SELECT src.set_key, src.label, src.description, TRUE
FROM (
    VALUES
        ('opportunity_stage', 'Opportunity Stage', 'CRM deal pipeline stages'),
        ('activity_type',     'Activity Type',     'Types of tracked activities'),
        ('assignment_rule',   'Assignment Rule',   'Lead/task assignment strategies')
) AS src(set_key, label, description)
WHERE NOT EXISTS (
    SELECT 1 FROM lookup_sets ls WHERE ls.set_key = src.set_key AND ls.deleted_at IS NULL
);

INSERT INTO lookup_values (set_id, value_key, label, sort_order, is_default, color, value_json)
SELECT ls.id, src.value_key, src.label, src.sort_order, src.is_default, src.color, '{}'::jsonb
FROM lookup_sets ls
JOIN (
    VALUES
        ('opportunity_stage', 'prospecting',  'Prospecting',  1, TRUE,  '#2563eb'),
        ('opportunity_stage', 'proposal',     'Proposal',     2, FALSE, '#7c3aed'),
        ('opportunity_stage', 'negotiation',  'Negotiation',  3, FALSE, '#d97706'),
        ('opportunity_stage', 'won',          'Won',          4, FALSE, '#15803d'),
        ('opportunity_stage', 'lost',         'Lost',         5, FALSE, '#dc2626'),
        ('activity_type',     'call',         'Call',         1, TRUE,  '#2563eb'),
        ('activity_type',     'meeting',      'Meeting',      2, FALSE, '#0f766e'),
        ('activity_type',     'email',        'Email',        3, FALSE, '#7c3aed'),
        ('activity_type',     'note',         'Note',         4, FALSE, '#d97706'),
        ('activity_type',     'task',         'Task',         5, FALSE, '#16a34a'),
        ('activity_type',     'system_event', 'System Event', 6, FALSE, '#6b7280'),
        ('assignment_rule',   'round_robin',  'Round Robin',  1, TRUE,  '#2563eb'),
        ('assignment_rule',   'pool',         'Pool Pick',    2, FALSE, '#7c3aed'),
        ('assignment_rule',   'manual',       'Manual',       3, FALSE, '#6b7280')
) AS src(set_key, value_key, label, sort_order, is_default, color)
ON src.set_key = ls.set_key
WHERE NOT EXISTS (
    SELECT 1 FROM lookup_values lv
    WHERE lv.set_id = ls.id AND lv.value_key = src.value_key AND lv.deleted_at IS NULL
);

-- ─────────────────────────────────────────────
-- UI ENTITY CONFIGS
-- ─────────────────────────────────────────────
INSERT INTO ui_entity_configs (
    entity_key, label, table_name, primary_key, title_column, default_sort_column,
    permission_slug, form_key, route_base, supports_tags, supports_custom_fields, is_system, sample_payload_json, metadata
)
SELECT
    src.entity_key, src.label, src.table_name, 'id', src.title_column, src.default_sort_column,
    src.permission_slug, src.entity_key, src.route_base, TRUE, TRUE, FALSE,
    src.sample_payload_json::jsonb, src.metadata::jsonb
FROM (
    VALUES
        ('opportunity', 'Opportunity', 'opportunities', 'title', 'created_at', 'opportunities:manage',
         '/api/data/opportunity',
         '{"create":{"title":"New Deal","accountId":"uuid","stage":"prospecting","amount":500000},"update":{"id":"uuid","stage":"negotiation","probability":75},"list":{"page":1,"limit":20}}',
         '{"module":"sales"}'),
        ('activity', 'Activity', 'activities', 'title', 'activity_date', 'activities:manage',
         '/api/data/activity',
         '{"create":{"entityType":"lead","entityId":"uuid","type":"call","title":"Discovery call"},"list":{"entityType":"lead","entityId":"uuid"}}',
         '{"module":"engagement"}'),
        ('note', 'Note', 'notes', 'content', 'created_at', 'notes:manage',
         '/api/data/note',
         '{"create":{"entityType":"project","entityId":"uuid","content":"Client requested timeline revision"},"list":{"entityType":"project","entityId":"uuid"}}',
         '{"module":"engagement"}')
) AS src(entity_key, label, table_name, title_column, default_sort_column, permission_slug, route_base, sample_payload_json, metadata)
WHERE NOT EXISTS (
    SELECT 1 FROM ui_entity_configs e WHERE e.entity_key = src.entity_key AND e.deleted_at IS NULL
);

-- ─────────────────────────────────────────────
-- UI FIELD CONFIGS
-- ─────────────────────────────────────────────
INSERT INTO ui_field_configs (
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, is_readonly, include_in_list, include_in_detail, include_in_create, include_in_update,
    lookup_set_key, sample_value_json, config_json
)
SELECT
    src.entity_key, src.field_key, src.label, src.column_name, src.data_type,
    src.sort_order, src.is_required, src.is_filterable, src.is_sortable, FALSE,
    src.inc_list, TRUE, src.inc_create, src.inc_update,
    src.lookup_set_key, src.sample_value_json::jsonb, src.config_json::jsonb
FROM (
    VALUES
        -- Opportunity fields
        ('opportunity','title','Title','title','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Refurbishment Deal"','{}'),
        ('opportunity','description','Description','description','text',20,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Negotiation in progress"','{}'),
        ('opportunity','stage','Stage','stage','opportunity_stage',30,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,'opportunity_stage','"prospecting"','{}'),
        ('opportunity','amount','Amount','amount','numeric',40,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'500000','{}'),
        ('opportunity','probability','Probability','probability','integer',50,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'50','{}'),
        ('opportunity','expectedCloseDate','Expected Close','expected_close_date','date',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-06-30"','{}'),
        ('opportunity','leadId','Lead','lead_id','uuid',70,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('opportunity','accountId','Account','account_id','uuid',80,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('opportunity','contactId','Contact','contact_id','uuid',90,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('opportunity','assignedTo','Assigned To','assigned_to','uuid',100,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('opportunity','lostReason','Lost Reason','lost_reason','text',110,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Budget constraint"','{}'),
        -- Activity fields
        ('activity','entityType','Entity Type','entity_type','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"lead"','{}'),
        ('activity','entityId','Entity ID','entity_id','uuid',20,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('activity','type','Type','type','activity_type',30,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,'activity_type','"call"','{}'),
        ('activity','title','Title','title','text',40,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"Discovery call"','{}'),
        ('activity','description','Description','description','text',50,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,NULL,'"Discussed requirements"','{}'),
        ('activity','activityDate','Date','activity_date','timestamptz',60,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"2026-03-28T10:00:00Z"','{}'),
        -- Note fields
        ('note','entityType','Entity Type','entity_type','text',10,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"project"','{}'),
        ('note','entityId','Entity ID','entity_id','uuid',20,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,NULL,'"00000000-0000-0000-0000-000000000000"','{}'),
        ('note','content','Content','content','text',30,TRUE,FALSE,FALSE,TRUE,TRUE,TRUE,NULL,'"Client wants timeline revision"','{}'),
        ('note','isPinned','Pinned','is_pinned','boolean',40,FALSE,TRUE,TRUE,FALSE,TRUE,TRUE,NULL,'false','{}')
) AS src(
    entity_key, field_key, label, column_name, data_type, sort_order, is_required,
    is_filterable, is_sortable, inc_list, inc_create, inc_update,
    lookup_set_key, sample_value_json, config_json
)
WHERE NOT EXISTS (
    SELECT 1 FROM ui_field_configs f
    WHERE f.entity_key = src.entity_key AND f.field_key = src.field_key AND f.deleted_at IS NULL
);

-- ─────────────────────────────────────────────
-- API ENDPOINT REGISTRY — New module endpoints
-- ─────────────────────────────────────────────
INSERT INTO api_endpoint_registry (
    endpoint_key, entity_key, action_key, dispatcher_fn, permission_slug, form_key,
    http_method, route_path, auth_mode, is_public,
    request_schema_json, response_schema_json, filter_schema_json, sample_payload_json, metadata
)
SELECT
    src.endpoint_key, src.entity_key, src.action_key, src.dispatcher_fn, src.permission_slug,
    src.form_key, src.http_method, src.route_path, 'session', FALSE,
    src.req::jsonb, src.res::jsonb, src.flt::jsonb, src.sample::jsonb, src.meta::jsonb
FROM (
    VALUES
        -- Opportunity endpoints
        ('action.opportunity.list',         'opportunity', 'list_opportunities',    'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities',              '{"page":1,"limit":20}',                   '{"rid":"s-opportunities-listed"}',    '{"stage":"prospecting"}',           '{"page":1,"limit":20}',                       '{"category":"opportunity"}'),
        ('action.opportunity.get',          'opportunity', 'get_opportunity',       'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/get',          '{"id":"uuid"}',                           '{"rid":"s-opportunity-loaded"}',      '{}',                                '{"id":"uuid"}',                               '{"category":"opportunity"}'),
        ('action.opportunity.create',       'opportunity', 'create_opportunity',    'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/create',       '{"title":"New Deal","stage":"prospecting"}','{"rid":"s-opportunity-created"}',    '{}',                                '{"title":"New Deal","accountId":"uuid"}',     '{"category":"opportunity"}'),
        ('action.opportunity.update',       'opportunity', 'update_opportunity',    'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/update',       '{"id":"uuid","amount":600000}',            '{"rid":"s-opportunity-updated"}',     '{}',                                '{"id":"uuid","amount":600000}',               '{"category":"opportunity"}'),
        ('action.opportunity.update_stage', 'opportunity', 'update_stage',          'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/update-stage', '{"id":"uuid","stage":"negotiation"}',      '{"rid":"s-opportunity-stage-updated"}','{}',                               '{"id":"uuid","stage":"negotiation"}',         '{"category":"opportunity"}'),
        ('action.opportunity.close_won',    'opportunity', 'close_won',             'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/close-won',    '{"id":"uuid"}',                           '{"rid":"s-opportunity-won"}',         '{}',                                '{"id":"uuid","projectTitle":"Villa Project"}', '{"category":"opportunity"}'),
        ('action.opportunity.close_lost',   'opportunity', 'close_lost',            'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/close-lost',   '{"id":"uuid","lostReason":"Budget"}',     '{"rid":"s-opportunity-lost"}',        '{}',                                '{"id":"uuid","lostReason":"Budget mismatch"}','{"category":"opportunity"}'),
        ('action.opportunity.assign',       'opportunity', 'assign_opportunity',    'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/assign',       '{"id":"uuid","userId":"uuid"}',            '{"rid":"s-opportunity-assigned"}',    '{}',                                '{"id":"uuid","userId":"uuid"}',               '{"category":"opportunity"}'),
        ('action.opportunity.delete',       'opportunity', 'delete_opportunity',    'fn_opportunity_operations', 'opportunities:manage', 'opportunity', 'POST', '/api/opportunities/delete',       '{"id":"uuid"}',                           '{"rid":"s-opportunity-deleted"}',     '{}',                                '{"id":"uuid"}',                               '{"category":"opportunity"}'),
        -- Activity endpoints
        ('action.activity.list',            'activity',    'list_activities',       'fn_activity_operations',    'activities:manage',    NULL,          'POST', '/api/activities',                 '{"entityType":"lead","entityId":"uuid"}',  '{"rid":"s-activities-listed"}',       '{"type":"call"}',                   '{"entityType":"lead","entityId":"uuid"}',     '{"category":"activity"}'),
        ('action.activity.timeline',        NULL,          'list_global_timeline',  'fn_activity_operations',    'activities:manage',    NULL,          'POST', '/api/activities/timeline',        '{"limit":30}',                            '{"rid":"s-timeline-listed"}',         '{}',                                '{"limit":30}',                                '{"category":"activity"}'),
        ('action.activity.log_call',        'activity',    'log_call',              'fn_activity_operations',    'activities:manage',    NULL,          'POST', '/api/activities/log-call',        '{"entityType":"lead","entityId":"uuid"}',  '{"rid":"s-call-logged"}',             '{}',                                '{"entityType":"lead","entityId":"uuid","title":"Call with client"}','{"category":"activity"}'),
        ('action.activity.log_meeting',     'activity',    'log_meeting',           'fn_activity_operations',    'activities:manage',    NULL,          'POST', '/api/activities/log-meeting',     '{"entityType":"lead","entityId":"uuid"}',  '{"rid":"s-meeting-logged"}',          '{}',                                '{"entityType":"lead","entityId":"uuid","title":"Kickoff meeting"}', '{"category":"activity"}'),
        ('action.activity.log_email',       'activity',    'log_email',             'fn_activity_operations',    'activities:manage',    NULL,          'POST', '/api/activities/log-email',       '{"entityType":"lead","entityId":"uuid"}',  '{"rid":"s-email-logged"}',            '{}',                                '{"entityType":"lead","entityId":"uuid","title":"Follow-up email"}', '{"category":"activity"}'),
        -- Notes endpoints
        ('action.note.list',                'note',        'list_notes',            'fn_notes_operations',       'notes:manage',         NULL,          'POST', '/api/notes',                      '{"entityType":"project","entityId":"uuid"}','{"rid":"s-notes-listed"}',            '{}',                                '{"entityType":"project","entityId":"uuid"}',  '{"category":"note"}'),
        ('action.note.create',              'note',        'create_note',           'fn_notes_operations',       'notes:manage',         'note',        'POST', '/api/notes/create',               '{"entityType":"project","entityId":"uuid","content":"Note text"}','{"rid":"s-note-created"}','{}','{"entityType":"project","entityId":"uuid","content":"Note text"}','{"category":"note"}'),
        ('action.note.update',              'note',        'update_note',           'fn_notes_operations',       'notes:manage',         'note',        'POST', '/api/notes/update',               '{"id":"uuid","content":"Updated text"}',   '{"rid":"s-note-updated"}',            '{}',                                '{"id":"uuid","content":"Updated text"}',      '{"category":"note"}'),
        ('action.note.pin',                 'note',        'pin_note',              'fn_notes_operations',       'notes:manage',         NULL,          'POST', '/api/notes/pin',                  '{"id":"uuid"}',                           '{"rid":"s-note-pinned"}',             '{}',                                '{"id":"uuid"}',                               '{"category":"note"}'),
        ('action.note.delete',              'note',        'delete_note',           'fn_notes_operations',       'notes:manage',         NULL,          'POST', '/api/notes/delete',               '{"id":"uuid"}',                           '{"rid":"s-note-deleted"}',            '{}',                                '{"id":"uuid"}',                               '{"category":"note"}'),
        -- Assignment pool endpoints
        ('action.assignment.list_pools',           NULL, 'list_pools',             'fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/pools',           '{"entityType":"lead"}',                   '{"rid":"s-pools-listed"}',            '{}',                                '{"entityType":"lead"}',                       '{"category":"assignment"}'),
        ('action.assignment.create_pool',          NULL, 'create_pool',            'fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/pools/create',    '{"name":"Sales Team Pool","entityType":"lead"}','{"rid":"s-pool-created"}',       '{}',                                '{"name":"Sales Team Pool","ruleType":"round_robin"}','{"category":"assignment"}'),
        ('action.assignment.add_member',           NULL, 'add_pool_member',        'fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/pools/add-member','{"poolId":"uuid","userId":"uuid"}',        '{"rid":"s-pool-member-added"}',       '{}',                                '{"poolId":"uuid","userId":"uuid"}',            '{"category":"assignment"}'),
        ('action.assignment.remove_member',        NULL, 'remove_pool_member',     'fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/pools/remove-member','{"poolId":"uuid","userId":"uuid"}',     '{"rid":"s-pool-member-removed"}',     '{}',                                '{"poolId":"uuid","userId":"uuid"}',            '{"category":"assignment"}'),
        ('action.assignment.history',              NULL, 'list_assignment_history','fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/history',         '{"entityType":"lead","entityId":"uuid"}',  '{"rid":"s-assignment-history-listed"}','{}',                               '{"entityType":"lead","entityId":"uuid"}',     '{"category":"assignment"}'),
        ('action.assignment.unassigned_leads',     NULL, 'get_unassigned_leads',   'fn_assignment_operations',  'assignments:manage',   NULL,          'POST', '/api/assignments/unassigned',      '{}',                                      '{"rid":"s-unassigned-leads-listed"}', '{}',                                '{}',                                          '{"category":"assignment"}'),
        -- SLA endpoints
        ('action.sla.list_policies',    NULL, 'list_sla_policies',  'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/policies',         '{}',                                  '{"rid":"s-sla-policies-listed"}',  '{}', '{"entityType":"task"}',              '{"category":"sla"}'),
        ('action.sla.create_policy',    NULL, 'create_sla_policy',  'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/policies/create',  '{"name":"Critical Tasks","entityType":"task","dueTimeHours":4}', '{"rid":"s-sla-policy-created"}', '{}', '{"name":"Critical Tasks","entityType":"task","dueTimeHours":4,"escalationTimeHours":8}', '{"category":"sla"}'),
        ('action.sla.update_policy',    NULL, 'update_sla_policy',  'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/policies/update',  '{"id":"uuid","dueTimeHours":8}',      '{"rid":"s-sla-policy-updated"}',   '{}', '{"id":"uuid","dueTimeHours":8}',     '{"category":"sla"}'),
        ('action.sla.delete_policy',    NULL, 'delete_sla_policy',  'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/policies/delete',  '{"id":"uuid"}',                       '{"rid":"s-sla-policy-deleted"}',   '{}', '{"id":"uuid"}',                     '{"category":"sla"}'),
        ('action.sla.check_breaches',   NULL, 'check_sla_breaches', 'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/check-breaches',   '{}',                                  '{"rid":"s-sla-check-complete"}',   '{}', '{}',                               '{"category":"sla"}'),
        ('action.sla.list_escalations', NULL, 'list_escalations',   'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/escalations',      '{"status":"open"}',                   '{"rid":"s-escalations-listed"}',   '{}', '{"status":"open","entityType":"task"}', '{"category":"sla"}'),
        ('action.sla.resolve',          NULL, 'resolve_escalation', 'fn_sla_operations', 'slas:manage', NULL, 'POST', '/api/slas/escalations/resolve','{"id":"uuid"}',                     '{"rid":"s-escalation-resolved"}',  '{}', '{"id":"uuid"}',                    '{"category":"sla"}')
) AS src(
    endpoint_key, entity_key, action_key, dispatcher_fn, permission_slug, form_key,
    http_method, route_path, req, res, flt, sample, meta
)
WHERE NOT EXISTS (
    SELECT 1 FROM api_endpoint_registry aer
    WHERE aer.endpoint_key = src.endpoint_key AND aer.deleted_at IS NULL
);

-- ─────────────────────────────────────────────
-- REPORT DEFINITIONS (Pipeline + Escalations)
-- ─────────────────────────────────────────────
INSERT INTO report_definitions (report_key, label, description, definition_json)
SELECT src.report_key, src.label, src.description, src.definition_json::jsonb
FROM (
    VALUES
        ('deal_pipeline',    'Deal Pipeline',    'Opportunity stage conversion summary',     '{"entity":"opportunity","metrics":["count","amount","stage","probability"]}'),
        ('sla_breach_log',   'SLA Breach Log',   'Active and historical escalation records', '{"entity":"escalation_logs","metrics":["status","entity_type","escalated_at"]}'),
        ('activity_summary', 'Activity Summary', 'Cross-entity activity and engagement log', '{"entity":"activities","metrics":["type","entity_type","activity_date"]}')
) AS src(report_key, label, description, definition_json)
WHERE NOT EXISTS (
    SELECT 1 FROM report_definitions rd
    WHERE rd.report_key = src.report_key AND rd.deleted_at IS NULL
);

-- ─────────────────────────────────────────────
-- WORKFLOW EVENTS for new modules
-- ─────────────────────────────────────────────
INSERT INTO lookup_values (set_id, value_key, label, sort_order, color, value_json)
SELECT ls.id, src.value_key, src.label, src.sort_order, src.color, '{}'::jsonb
FROM lookup_sets ls
JOIN (
    VALUES
        ('workflow_event', 'opportunity_created', 'Opportunity Created',    6, '#2563eb'),
        ('workflow_event', 'opportunity_won',      'Opportunity Won',        7, '#15803d'),
        ('workflow_event', 'opportunity_lost',     'Opportunity Lost',       8, '#dc2626'),
        ('workflow_event', 'sla_breached',         'SLA Breached',           9, '#dc2626'),
        ('workflow_event', 'lead_assigned',        'Lead Assigned',         10, '#0ea5e9')
) AS src(set_key, value_key, label, sort_order, color)
ON src.set_key = ls.set_key
WHERE NOT EXISTS (
    SELECT 1 FROM lookup_values lv
    WHERE lv.set_id = ls.id AND lv.value_key = src.value_key AND lv.deleted_at IS NULL
);
