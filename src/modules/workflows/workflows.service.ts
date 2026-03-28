import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UpdateWorkflowRuleDto } from './dto/workflow.dto';

@Injectable()
export class WorkflowsService {
  constructor(private db: DatabaseService) {}

  async findAll() {
    return this.db.callDispatcher('fn_workflow_operations', {
      operation: 'list_rules',
      data: {},
    });
  }

  async updateRule(id: string, dto: UpdateWorkflowRuleDto, user: any) {
    return this.db.callDispatcher('fn_workflow_operations', {
      operation: 'update_rule',
      data: { id, ...dto },
      requestedBy: user.id,
    });
  }
}
