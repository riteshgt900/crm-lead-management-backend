import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { OpportunitiesService } from './opportunities.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Opportunities')
@Controller('opportunities')
@UseGuards(SessionGuard)
export class OpportunitiesController {
  constructor(private readonly opportunitiesService: OpportunitiesService) {}

  @Get()
  @ApiOperation({ summary: 'List all opportunities', description: 'Returns paginated list of deals in the pipeline.' })
  @ApiResponse({ status: 200, description: 'Opportunities listed', type: ApiResponseDto })
  findAll(@Query() query: any, @CurrentUser() user: any) {
    return this.opportunitiesService.findAll(query, user);
  }

  @Post('get')
  @ApiOperation({ summary: 'Get opportunity by ID' })
  @ApiResponse({ status: 200, description: 'Opportunity details with related data', type: ApiResponseDto })
  @ApiResponse({ status: 404, description: 'Opportunity not found' })
  findOne(@Body() body: { id: string }, @CurrentUser() user: any) {
    return this.opportunitiesService.findOne(body.id, user);
  }

  @Post()
  @ApiOperation({ summary: 'Create new opportunity' })
  @ApiResponse({ status: 201, description: 'Opportunity created', type: ApiResponseDto })
  create(@Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.create(dto, user);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update opportunity details' })
  @ApiResponse({ status: 200, description: 'Opportunity updated', type: ApiResponseDto })
  update(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.update(id, dto, user);
  }

  @Post(':id/stage')
  @ApiOperation({ summary: 'Move opportunity to a new pipeline stage' })
  @ApiResponse({ status: 200, description: 'Stage updated', type: ApiResponseDto })
  @ApiResponse({ status: 400, description: 'Cannot change stage of closed opportunity' })
  updateStage(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.updateStage(id, dto, user);
  }

  @Post(':id/win')
  @ApiOperation({ summary: 'Mark opportunity as Won and auto-create a Project' })
  @ApiResponse({ status: 200, description: 'Opportunity won, project created', type: ApiResponseDto })
  closeWon(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.closeWon(id, dto, user);
  }

  @Post(':id/lose')
  @ApiOperation({ summary: 'Mark opportunity as Lost' })
  @ApiResponse({ status: 200, description: 'Opportunity closed as lost', type: ApiResponseDto })
  closeLost(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.closeLost(id, dto, user);
  }

  @Post(':id/assign')
  @ApiOperation({ summary: 'Re-assign opportunity to another user' })
  @ApiResponse({ status: 200, description: 'Opportunity reassigned', type: ApiResponseDto })
  assign(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.opportunitiesService.assign(id, dto, user);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete opportunity' })
  @ApiResponse({ status: 200, description: 'Opportunity deleted', type: ApiResponseDto })
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.opportunitiesService.remove(id, user);
  }
}
