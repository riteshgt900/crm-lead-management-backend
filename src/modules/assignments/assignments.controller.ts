import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AssignmentsService } from './assignments.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Assignments')
@Controller('assignments')
@UseGuards(SessionGuard)
export class AssignmentsController {
  constructor(private readonly assignmentsService: AssignmentsService) {}

  @Get('pools')
  @ApiOperation({ summary: 'List assignment pools', description: 'Returns all active pools with member details.' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  listPools(@Query() query: any, @CurrentUser() user: any) {
    return this.assignmentsService.listPools(query, user);
  }

  @Post('pools')
  @ApiOperation({ summary: 'Create a new assignment pool' })
  @ApiResponse({ status: 201, type: ApiResponseDto })
  createPool(@Body() dto: any, @CurrentUser() user: any) {
    return this.assignmentsService.createPool(dto, user);
  }

  @Delete('pools/:id')
  @ApiOperation({ summary: 'Delete an assignment pool' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  deletePool(@Param('id') id: string, @CurrentUser() user: any) {
    return this.assignmentsService.deletePool(id, user);
  }

  @Post('pools/members/add')
  @ApiOperation({ summary: 'Add a user to an assignment pool' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  addMember(@Body() dto: any, @CurrentUser() user: any) {
    return this.assignmentsService.addMember(dto, user);
  }

  @Post('pools/members/remove')
  @ApiOperation({ summary: 'Remove a user from an assignment pool' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  removeMember(@Body() dto: any, @CurrentUser() user: any) {
    return this.assignmentsService.removeMember(dto, user);
  }

  @Get('history')
  @ApiOperation({ summary: 'Get assignment history for an entity' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  listHistory(@Query() query: any, @CurrentUser() user: any) {
    return this.assignmentsService.listHistory(query, user);
  }

  @Get('unassigned')
  @ApiOperation({ summary: 'Get unassigned leads available for pool pick' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  getUnassignedLeads(@Query() query: any, @CurrentUser() user: any) {
    return this.assignmentsService.getUnassignedLeads(query, user);
  }
}
