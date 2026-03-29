import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ListWorkflowRulesQueryDto, UpdateWorkflowRuleDto } from './dto/workflow.dto';

function buildWorkflowContext(user: any) {
  return {
    requestedBy: user?.id,
    role: user?.roleName ?? user?.role ?? null,
    permissions: user?.permissions ?? [],
  };
}

@Injectable()
export class WorkflowsService {
  constructor(private db: DatabaseService) {}

  async findAll(query: ListWorkflowRulesQueryDto, user: any) {
    return this.db.callDispatcher('fn_workflow_operations', {
      operation: 'list_rules',
      data: query || {},
      ...buildWorkflowContext(user),
    });
  }

  async updateRule(id: string, dto: UpdateWorkflowRuleDto, user: any) {
    return this.db.callDispatcher('fn_workflow_operations', {
      operation: 'update_rule',
      data: { id, ...dto },
      ...buildWorkflowContext(user),
    });
  }
}
