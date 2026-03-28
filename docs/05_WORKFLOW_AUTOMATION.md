# 05_WORKFLOW_AUTOMATION.md
# CRM for Lead Management — Workflow Automation

## 1. AUTOMATION ENGINE
The system uses an event-trigger architecture. After any mutation, the NestJS service calls the Workflow Evaluator.

### Trigger Lifecycle
1. **Event**: Lead is converted.
2. **Hook**: `LeadsService` calls `fn_workflow_operations('evaluate_trigger', { trigger: 'lead_converted' })`.
3. **SQL Engine**: Checks `workflow_rules` table for active rules matching the trigger.
4. **Execution**: Performs defined actions (Create project, send notification, email).
5. **Transactional Integrity**: All rules run in the **SAME TRANSACTION** as the trigger (ACID).
6. **Execution Logging**: Every execution attempt is written to `workflow_executions`.

---

## 2. SUPPORTED ACTIONS & STANDARDS
- `create_project`: From template linked to lead category.
- `create_task`: Sequential phases and milestones.
- `send_notification`: Real-time in-app alerts.
- `send_email`: External client/stakeholder updates.
- `update_status`: Cascade status changes (e.g., Project Done -> Lead Closed).

### Standard Action Payload
All actions must be defined as `fn_action_NAME(p_data JSONB)` to ensure the engine can call them dynamically with uniform data passing.

---

## 3. DEFAULT SEEDED RULES

### Rule: Auto-Project Creation
- **Trigger**: `lead_converted`
- **Action**: 
    - Create record in `projects`.
    - Map `contact_id` and `estimated_value`.
    - Assign `project_manager_id`.

### Rule: Overdue Task Escalation
- **Trigger**: `task_overdue` (Run via Daily Cron 8:00 AM)
- **Condition**: `days_overdue >= 3`
- **Action**: Notify Project Manager and Admin.

---

## 4. CRON JOBS (NestJS @Cron)
1. **Hourly**: `session-cleanup` (Removes expired `sessions`).
2. **Daily (7 AM)**: `report-generator` (Emails daily project digests).
3. **Daily (8 AM)**: `overdue-checker` (Fires `task_overdue` triggers).
