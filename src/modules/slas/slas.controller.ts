import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SlasService } from './slas.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('SLAs')
@Controller('slas')
@UseGuards(SessionGuard)
export class SlasController {
  constructor(private readonly slasService: SlasService) {}

  @Get('policies')
  @ApiOperation({ summary: 'List SLA policies' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  listPolicies(@Query() query: any, @CurrentUser() user: any) {
    return this.slasService.listPolicies(query, user);
  }

  @Post('policies')
  @ApiOperation({ summary: 'Create SLA policy' })
  @ApiResponse({ status: 201, type: ApiResponseDto })
  createPolicy(@Body() dto: any, @CurrentUser() user: any) {
    return this.slasService.createPolicy(dto, user);
  }

  @Patch('policies/:id')
  @ApiOperation({ summary: 'Update SLA policy' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  updatePolicy(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.slasService.updatePolicy(id, dto, user);
  }

  @Delete('policies/:id')
  @ApiOperation({ summary: 'Delete SLA policy' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  deletePolicy(@Param('id') id: string, @CurrentUser() user: any) {
    return this.slasService.deletePolicy(id, user);
  }

  @Post('check-breaches')
  @ApiOperation({ summary: 'Trigger SLA breach check (admin/cron)', description: 'Evaluates all entities against active SLA policies and creates escalation logs.' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  checkBreaches(@CurrentUser() user: any) {
    return this.slasService.checkBreaches(user);
  }

  @Get('escalations')
  @ApiOperation({ summary: 'List escalation logs', description: 'Returns open or resolved escalations filtered by entity type or status.' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  listEscalations(@Query() query: any, @CurrentUser() user: any) {
    return this.slasService.listEscalations(query, user);
  }

  @Post('escalations/:id/resolve')
  @ApiOperation({ summary: 'Resolve an escalation' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  resolveEscalation(@Param('id') id: string, @CurrentUser() user: any) {
    return this.slasService.resolveEscalation(id, user);
  }
}
