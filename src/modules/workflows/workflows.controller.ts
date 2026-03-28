import { Controller, Get, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { WorkflowsService } from './workflows.service';
import { UpdateWorkflowRuleDto } from './dto/workflow.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('workflows')
@UseGuards(SessionGuard, RolesGuard)
@Roles('admin')
export class WorkflowsController {
  constructor(private workflowsService: WorkflowsService) {}

  @Get()
  async findAll() {
    return this.workflowsService.findAll();
  }

  @Patch(':id')
  async updateRule(@Param('id') id: string, @Body() dto: UpdateWorkflowRuleDto, @CurrentUser() user: any) {
    return this.workflowsService.updateRule(id, dto, user);
  }
}
