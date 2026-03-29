import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ProjectsService } from './projects.service';
import { CreateProjectDto, ProjectListQueryDto, UpdateProjectDto } from './dto/project.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Projects')
@Controller('projects')
@UseGuards(SessionGuard)
export class ProjectsController {
  constructor(private projectsService: ProjectsService) {}

  @Get('templates')
  @ApiOperation({ summary: 'List project templates', description: 'Returns blueprints for project structures (Phases/Tasks).' })
  @ApiResponse({ status: 200, description: 'Templates retrieved', type: ApiResponseDto })
  async listTemplates(@CurrentUser() user: any) {
    return this.projectsService.listTemplates(user);
  }

  @Get()
  @ApiOperation({ summary: 'List all projects' })
  @ApiResponse({ status: 200, description: 'Return all projects', type: ApiResponseDto })
  async findAll(@Query() query: ProjectListQueryDto, @CurrentUser() user: any) {
    return this.projectsService.findAll(query, user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get project details' })
  @ApiResponse({ status: 200, description: 'Return project details', type: ApiResponseDto })
  @ApiResponse({ status: 404, description: 'Project not found' })
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.projectsService.findOne(id, user);
  }

  @Get(':id/tasks')
  @ApiOperation({ summary: 'Get project tasks' })
  @ApiResponse({ status: 200, description: 'Return list of project tasks', type: ApiResponseDto })
  async findTasks(@Param('id') id: string, @CurrentUser() user: any) {
    return this.projectsService.findTasks(id, user);
  }

  @Get(':id/activity')
  @ApiOperation({ summary: 'Get project activity feed', description: 'Returns a chronological log of all changes and actions taken on this project.' })
  @ApiResponse({ status: 200, description: 'Activity feed retrieved', type: ApiResponseDto })
  async findActivity(@Param('id') id: string, @CurrentUser() user: any) {
    return this.projectsService.findActivity(id, user);
  }

  @Post()
  @ApiOperation({ summary: 'Create new project' })
  @ApiResponse({ status: 201, description: 'Project created successfully', type: ApiResponseDto })
  async create(@Body() dto: CreateProjectDto, @CurrentUser() user: any) {
    return this.projectsService.create(dto, user);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update project details' })
  @ApiResponse({ status: 200, description: 'Project updated successfully', type: ApiResponseDto })
  async updateProject(@Param('id') id: string, @Body() dto: UpdateProjectDto, @CurrentUser() user: any) {
    return this.projectsService.updateProject(id, dto, user);
  }
}
