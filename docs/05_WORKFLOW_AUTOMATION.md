# 05_WORKFLOW_AUTOMATION.md
# CRM Platform — Workflow Automation & Cron System

## 1. AUTOMATION ENGINE
The system uses an **event-trigger architecture**. After any mutation, the NestJS service calls the Workflow Evaluator inside the same DB transaction.

### Trigger Lifecycle
1. **Event**: A mutation occurs (e.g., Lead converted to Opportunity).
2. **Hook**: Dispatcher calls `fn_trigger_workflow('event_key', entity_id)`.
3. **SQL Engine**: Queries `workflow_rules` table for active rules matching the trigger event.
4. **Execution**: Performs defined actions (create project, send notification, email, etc.).
5. **ACID**: All rules run in the **SAME TRANSACTION** as the trigger → auto-rollback on failure.
6. **Logging**: Every attempt written to `workflow_executions`.

---

## 2. ALL SUPPORTED TRIGGER EVENTS

| Event Key | When It Fires |
|-----------|--------------|
| `lead_created` | After a new lead is inserted |
| `status_changed` | After lead status is updated |
| `lead_converted` | After lead is converted to Opportunity |
| `lead_assigned` | After lead is assigned or claimed from pool |
| `opportunity_created` | After a new opportunity is created |
| `opportunity_won` | After close_won — project has been auto-generated |
| `opportunity_lost` | After close_lost |
| `sla_breached` | After a SLA breach is detected (cron) |
| `task_created` | After a task is created |
| `task_status_changed` | After a task changes status |
| `task_overdue` | When task is overdue (daily cron fires this) |
| `project_status_changed` | After project changes status |

---

## 3. SUPPORTED ACTION TYPES

| Action | Description |
|--------|------------|
| `create_project` | Create a project from a template linked to lead category |
| `create_task` | Create a task inside a project |
| `send_notification` | Create an in-app notification record |
| `send_email` | Queue an email via the Email module |
| `update_status` | Cascade a status change (e.g., Project Done → Lead Closed) |
| `assign_round_robin` | Pick next member from an assignment pool |
| `create_escalation` | Insert an escalation log entry |

---

## 4. DEFAULT SEEDED WORKFLOW RULES

### Rule 1: Auto-Pool Assignment on Lead Create
- **Trigger**: `lead_created`
- **Condition**: No `assigned_to` provided
- **Action**: Auto-pick next user from `assignment_pools` WHERE `entity_type = 'lead'` AND `rule_type = 'round_robin'`
- **Effect**: Lead is assigned, `assignment_history` logged

### Rule 2: Opportunity Stage Notification
- **Trigger**: `opportunity_won`
- **Action**: `send_notification` to project manager and admin

### Rule 3: Overdue Task Escalation
- **Trigger**: `task_overdue` (fired by Daily Cron at 8 AM)
- **Condition**: `days_overdue >= 3`
- **Action**: Notify Project Manager + Admin; create `escalation_log` entry

### Rule 4: SLA Breach Escalation
- **Trigger**: `sla_breached` (fired by SLA Cron)
- **Condition**: Entity exceeded `escalation_time_hours`
- **Action**: Create `escalation_log`, send notification to escalation_user_id

---

## 5. CRON JOBS (NestJS @Cron)

| Schedule | Job Name | Description |
|----------|----------|-------------|
| Every hour | `session-cleanup` | Removes expired sessions from `sessions` table |
| Daily 7 AM | `report-generator` | Emails daily project digest to system admins |
| Daily 8 AM | `overdue-checker` | For each overdue task, fires `task_overdue` workflow trigger |
| Daily 9 AM | `sla-breach-checker` | Calls `fn_sla_operations('check_sla_breaches')` — scans all active SLA policies |
| Weekly Mon 7 AM | `weekly-summary` | Emails KPI summary (Leads, Opportunities, Projects, Tasks) to admins |

### Adding SLA Check to Cron
In the existing `CronModule`:
```typescript
@Cron('0 9 * * *', { name: 'sla-breach-checker' })
async checkSlaBreaches() {
    await this.slasService.checkBreaches({ id: SYSTEM_USER_ID, role: 'admin', permissions: [] });
}
```

---

## 6. WORKFLOW RULE SCHEMA

```sql
-- workflow_rules table
{
  "id":           "uuid",
  "name":         "Auto-notify on opportunity won",
  "trigger_event":"opportunity_won",
  "conditions":   { "stage": "won" },         -- optional JSONB match conditions
  "action_type":  "send_notification",
  "action_data":  { "message": "New project created!", "role": "admin" },
  "is_active":    true,
  "created_at":   "timestamptz"
}
```
