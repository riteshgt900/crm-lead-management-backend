import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateProjectDto, UpdateProjectDto } from './dto/project.dto';

@Injectable()
export class ProjectsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_project_operations', {
      operation: 'list_projects',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async findOne(id: string, user: any) {
    return this.db.callDispatcher('fn_project_operations', {
      operation: 'get_project',
      data: { id },
      requestedBy: user.id,
      role: user.role,
    });
  }

  async findTasks(id: string, user: any) {
    return this.db.callDispatcher('fn_project_operations', {
      operation: 'list_project_tasks',
      data: { projectId: id },
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateProjectDto, user: any) {
    return this.db.callDispatcher('fn_project_operations', {
      operation: 'create_project',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
