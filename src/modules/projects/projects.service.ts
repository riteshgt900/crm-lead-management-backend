import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateProjectDto, ProjectListQueryDto, UpdateProjectDto } from './dto/project.dto';

@Injectable()
export class ProjectsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: ProjectListQueryDto, user: any) {
    const page = query?.page ?? 1;
    const limit = query?.limit ?? 20;
    const offset = (page - 1) * limit;
    const params = [query?.q ?? null, query?.status ?? null, query?.projectManagerId ?? null, limit, offset];

    const result = await this.db.query(
      `
        SELECT
          p.*,
          u.full_name AS manager_name,
          c.first_name || ' ' || c.last_name AS contact_name
        FROM projects p
        LEFT JOIN users u ON p.project_manager_id = u.id
        LEFT JOIN contacts c ON p.contact_id = c.id
        WHERE p.deleted_at IS NULL
          AND ($1::text IS NULL OR p.title ILIKE '%' || $1 || '%' OR p.project_number ILIKE '%' || $1 || '%')
          AND ($2::text IS NULL OR p.status::text = $2)
          AND ($3::uuid IS NULL OR p.project_manager_id = $3)
        ORDER BY p.created_at DESC
        LIMIT $4 OFFSET $5
      `,
      params,
    );

    return this.success('s-projects-listed', 200, result.rows);
  }

  async findOne(id: string, user: any) {
    const projectRes = await this.db.query(
      `
        SELECT
          p.*,
          u.full_name AS manager_name,
          c.first_name || ' ' || c.last_name AS contact_name
        FROM projects p
        LEFT JOIN users u ON p.project_manager_id = u.id
        LEFT JOIN contacts c ON p.contact_id = c.id
        WHERE p.id = $1::uuid AND p.deleted_at IS NULL
      `,
      [id],
    );

    const project = projectRes.rows[0];
    if (!project) {
      return this.error('e-project-not-found', 404, 'Project not found');
    }

    const [phases, milestones, tasks, documents] = await Promise.all([
      this.db.query('SELECT * FROM project_phases WHERE project_id = $1::uuid AND deleted_at IS NULL ORDER BY sort_order', [id]),
      this.db.query('SELECT * FROM project_milestones WHERE project_id = $1::uuid AND deleted_at IS NULL ORDER BY due_date NULLS LAST', [id]),
      this.db.query('SELECT * FROM tasks WHERE project_id = $1::uuid AND deleted_at IS NULL ORDER BY created_at DESC', [id]),
      this.db.query(
        `
          SELECT *
          FROM documents
          WHERE entity_id = $1::uuid
            AND module_name = 'projects'
            AND deleted_at IS NULL
          ORDER BY created_at DESC
        `,
        [id],
      ),
    ]);

    return this.success('s-project-loaded', 200, {
      ...project,
      phases: phases.rows,
      milestones: milestones.rows,
      tasks: tasks.rows,
      documents: documents.rows,
    });
  }

  async findTasks(id: string, user: any) {
    const tasks = await this.db.query(
      `
        SELECT
          t.*,
          u.full_name AS assigned_to_name,
          p.title AS project_name
        FROM tasks t
        LEFT JOIN users u ON t.assigned_to = u.id
        LEFT JOIN projects p ON t.project_id = p.id
        WHERE t.deleted_at IS NULL
          AND t.project_id = $1::uuid
          AND t.is_template = FALSE
        ORDER BY t.created_at DESC
      `,
      [id],
    );

    return this.success('s-tasks-listed', 200, tasks.rows);
  }

  async listTemplates(user: any) {
    const templates = await this.db.query(
      `
        SELECT
          pt.*,
          COALESCE(phase_counts.phase_count, 0) AS phase_count
        FROM project_templates pt
        LEFT JOIN (
          SELECT template_id, COUNT(*)::int AS phase_count
          FROM project_phases
          WHERE deleted_at IS NULL
          GROUP BY template_id
        ) phase_counts ON phase_counts.template_id = pt.id
        WHERE pt.deleted_at IS NULL
        ORDER BY pt.name
      `,
    );

    return this.success('s-templates-listed', 200, templates.rows);
  }

  async findActivity(id: string, user: any) {
    const logs = await this.db.query(
      `
        SELECT al.*, u.full_name AS user_name
        FROM audit_logs al
        LEFT JOIN users u ON al.changed_by = u.id
        WHERE al.table_name = 'projects'
          AND al.record_id = $1::uuid
        ORDER BY al.changed_at DESC
      `,
      [id],
    );

    return this.success('s-audit-logs-listed', 200, logs.rows);
  }

  async create(dto: CreateProjectDto, user: any) {
    const managerId = dto.projectManagerId ?? dto.managerId ?? null;
    const estimatedValue = dto.estimatedValue ?? dto.budget ?? null;
    const result = await this.db.query(
      `
        WITH ctx AS (
          SELECT set_config('crm.current_user_id', $1::text, true)
        )
        INSERT INTO projects (
          project_number,
          title,
          description,
          lead_id,
          contact_id,
          project_manager_id,
          estimated_value,
          start_date,
          end_date,
          status
        )
        SELECT
          generate_project_number(),
          $2::text,
          $3::text,
          $4::uuid,
          $5::uuid,
          $6::uuid,
          $7::numeric,
          $8::timestamptz,
          $9::timestamptz,
          COALESCE($10::project_status, 'planning')
        FROM ctx
        RETURNING id, project_number AS "projectNumber", title, status
      `,
      [
        user.id,
        dto.title,
        dto.description ?? null,
        dto.leadId ?? null,
        dto.contactId ?? null,
        managerId,
        estimatedValue,
        dto.startDate ?? null,
        dto.endDate ?? null,
        dto.status ?? null,
      ],
    );

    const project = result.rows[0];
    return this.success('s-project-created', 201, project);
  }

  async updateProject(id: string, dto: UpdateProjectDto, user: any) {
    const managerId = dto.projectManagerId ?? dto.managerId ?? null;
    const estimatedValue = dto.estimatedValue ?? dto.budget ?? null;
    const result = await this.db.query(
      `
        WITH ctx AS (
          SELECT set_config('crm.current_user_id', $1::text, true)
        )
        UPDATE projects
        SET
          title = COALESCE($2::text, title),
          description = COALESCE($3::text, description),
          status = COALESCE($4::project_status, status),
          lead_id = COALESCE($5::uuid, lead_id),
          contact_id = COALESCE($6::uuid, contact_id),
          project_manager_id = COALESCE($7::uuid, project_manager_id),
          estimated_value = COALESCE($8::numeric, estimated_value),
          start_date = COALESCE($9::timestamptz, start_date),
          end_date = COALESCE($10::timestamptz, end_date),
          updated_at = NOW()
        FROM ctx
        WHERE projects.id = $11::uuid
        RETURNING id, project_number AS "projectNumber", title, status
      `,
      [
        user.id,
        dto.title ?? null,
        dto.description ?? null,
        dto.status ?? null,
        dto.leadId ?? null,
        dto.contactId ?? null,
        managerId,
        estimatedValue,
        dto.startDate ?? null,
        dto.endDate ?? null,
        id,
      ],
    );

    if (result.rowCount === 0) {
      return this.error('e-project-not-found', 404, 'Project not found');
    }

    return this.success('s-project-updated', 200, result.rows[0]);
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
