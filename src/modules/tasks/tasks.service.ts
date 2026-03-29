import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateTaskDto, TaskListQueryDto, UpdateTaskDto } from './dto/task.dto';

@Injectable()
export class TasksService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: TaskListQueryDto, user: any) {
    const page = query?.page ?? 1;
    const limit = query?.limit ?? 20;
    const offset = (page - 1) * limit;
    const params = [query?.q ?? null, query?.status ?? null, query?.projectId ?? null, limit, offset];

    const result = await this.db.query(
      `
        SELECT
          t.*,
          u.full_name AS assigned_to_name,
          p.title AS project_name
        FROM tasks t
        LEFT JOIN users u ON t.assigned_to = u.id
        LEFT JOIN projects p ON t.project_id = p.id
        WHERE t.deleted_at IS NULL
          AND t.is_template = FALSE
          AND ($1::text IS NULL OR t.title ILIKE '%' || $1 || '%' OR COALESCE(t.description, '') ILIKE '%' || $1 || '%')
          AND ($2::text IS NULL OR t.status::text = $2)
          AND ($3::uuid IS NULL OR t.project_id = $3)
        ORDER BY t.created_at DESC
        LIMIT $4 OFFSET $5
      `,
      params,
    );

    return this.success('s-tasks-listed', 200, result.rows);
  }

  async create(dto: CreateTaskDto, user: any) {
    const assignedTo = dto.assignedTo ?? dto.assigneeId ?? null;
    const result = await this.db.query(
      `
        WITH ctx AS (
          SELECT set_config('crm.current_user_id', $1::text, true)
        )
        INSERT INTO tasks (
          task_number,
          project_id,
          phase_id,
          milestone_id,
          title,
          description,
          status,
          priority,
          assigned_to,
          reporter_id,
          due_date,
          estimated_hours,
          parent_task_id
        )
        SELECT
          generate_task_number(),
          $2::uuid,
          $3::uuid,
          $4::uuid,
          $5::text,
          $6::text,
          COALESCE($7::task_status, 'todo'),
          COALESCE($8::task_priority, 'medium'),
          $9::uuid,
          $1::uuid,
          $10::timestamptz,
          $11::numeric,
          $12::uuid
        FROM ctx
        RETURNING id, task_number AS "taskNumber", title, status, priority
      `,
      [
        user.id,
        dto.projectId,
        dto.phaseId ?? null,
        dto.milestoneId ?? null,
        dto.title,
        dto.description ?? null,
        dto.status ?? null,
        dto.priority ?? null,
        assignedTo,
        dto.dueDate ?? null,
        dto.estimatedHours ?? null,
        dto.parentTaskId ?? null,
      ],
    );

    return this.success('s-task-created', 201, result.rows[0]);
  }

  async update(id: string, dto: UpdateTaskDto, user: any) {
    const assignedTo = dto.assignedTo ?? dto.assigneeId ?? null;
    const result = await this.db.query(
      `
        WITH ctx AS (
          SELECT set_config('crm.current_user_id', $1::text, true)
        )
        UPDATE tasks
        SET
          status = COALESCE($2::task_status, status),
          priority = COALESCE($3::task_priority, priority),
          assigned_to = COALESCE($4::uuid, assigned_to),
          due_date = COALESCE($5::timestamptz, due_date),
          estimated_hours = COALESCE($6::numeric, estimated_hours),
          parent_task_id = COALESCE($7::uuid, parent_task_id),
          updated_at = NOW()
        FROM ctx
        WHERE tasks.id = $8::uuid
        RETURNING id, task_number AS "taskNumber", title, status, priority
      `,
      [
        user.id,
        dto.status ?? null,
        dto.priority ?? null,
        assignedTo,
        dto.dueDate ?? null,
        dto.estimatedHours ?? null,
        dto.parentTaskId ?? null,
        id,
      ],
    );

    if (result.rowCount === 0) {
      return this.error('e-task-not-found', 404, 'Task not found');
    }

    return this.success('s-task-updated', 200, result.rows[0]);
  }

  private success(rid: string, statusCode: number, data: any) {
    return {
      rid,
      statusCode,
      data,
      message: 'Operation successful',
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  }

  private error(rid: string, statusCode: number, message: string) {
    return {
      rid,
      statusCode,
      data: null,
      message,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  }
}
