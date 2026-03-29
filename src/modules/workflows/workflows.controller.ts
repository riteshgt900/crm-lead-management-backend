import { Body, Controller, ForbiddenException, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { WorkflowsService } from './workflows.service';
import { ListWorkflowRulesQueryDto, UpdateWorkflowRuleDto } from './dto/workflow.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Workflows')
@Controller('workflows')
@UseGuards(SessionGuard)
export class WorkflowsController {
  constructor(private workflowsService: WorkflowsService) {}

  @Get()
  @ApiOperation({ summary: 'List workflow rules' })
  async findAll(@Query() query: ListWorkflowRulesQueryDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.workflowsService.findAll(query, user);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update workflow rule' })
  async updateRule(@Param('id') id: string, @Body() dto: UpdateWorkflowRuleDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.workflowsService.updateRule(id, dto, user);
  }

  private assertAdmin(user: any) {
    const roleName = user?.roleName ?? user?.role;
    if (roleName !== 'admin') {
      throw new ForbiddenException({ rid: 'e-forbidden', message: 'Insufficient permissions' });
    }
  }
}
