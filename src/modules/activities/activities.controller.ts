import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ActivitiesService } from './activities.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Activities')
@Controller('activities')
@UseGuards(SessionGuard)
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  @Get()
  @ApiOperation({ summary: 'List activities for an entity', description: 'Returns unified activity timeline for the given entity.' })
  @ApiResponse({ status: 200, description: 'Activities listed', type: ApiResponseDto })
  list(@Query() query: any, @CurrentUser() user: any) {
    return this.activitiesService.list(query, user);
  }

  @Get('timeline')
  @ApiOperation({ summary: 'Global activity timeline', description: 'Returns recent activity across all entities for the current user.' })
  @ApiResponse({ status: 200, description: 'Timeline listed', type: ApiResponseDto })
  globalTimeline(@Query() query: any, @CurrentUser() user: any) {
    return this.activitiesService.globalTimeline(query, user);
  }

  @Post('log-call')
  @ApiOperation({ summary: 'Log a call activity' })
  @ApiResponse({ status: 201, description: 'Call logged', type: ApiResponseDto })
  logCall(@Body() dto: any, @CurrentUser() user: any) {
    return this.activitiesService.logCall(dto, user);
  }

  @Post('log-meeting')
  @ApiOperation({ summary: 'Log a meeting activity' })
  @ApiResponse({ status: 201, description: 'Meeting logged', type: ApiResponseDto })
  logMeeting(@Body() dto: any, @CurrentUser() user: any) {
    return this.activitiesService.logMeeting(dto, user);
  }

  @Post('log-email')
  @ApiOperation({ summary: 'Log an email activity' })
  @ApiResponse({ status: 201, description: 'Email logged', type: ApiResponseDto })
  logEmail(@Body() dto: any, @CurrentUser() user: any) {
    return this.activitiesService.logEmail(dto, user);
  }

  @Post()
  @ApiOperation({ summary: 'Create a generic activity entry' })
  @ApiResponse({ status: 201, description: 'Activity created', type: ApiResponseDto })
  create(@Body() dto: any, @CurrentUser() user: any) {
    return this.activitiesService.create(dto, user);
  }
}
