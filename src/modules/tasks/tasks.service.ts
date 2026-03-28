import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';

@Injectable()
export class TasksService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_task_operations', {
      operation: 'list_tasks',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateTaskDto, user: any) {
    return this.db.callDispatcher('fn_task_operations', {
      operation: 'create_task',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }

  async update(id: string, dto: UpdateTaskDto, user: any) {
    return this.db.callDispatcher('fn_task_operations', {
      operation: 'update_task',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role,
    });
  }
}
