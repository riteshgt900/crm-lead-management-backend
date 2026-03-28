import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { LeadsService } from './leads.service';
import { CreateLeadDto, UpdateLeadStatusDto, BulkUpdateLeadsDto } from './dto/lead.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Leads')
@Controller('leads')
@UseGuards(SessionGuard)
export class LeadsController {
  constructor(private leadsService: LeadsService) {}

  @Get()
  @ApiOperation({ summary: 'List all leads', description: 'Returns a paginated list of leads assigned to or visible to the current user.' })
  @ApiResponse({ status: 200, description: 'List of leads retrieved successfully', type: ApiResponseDto })
  async findAll(@CurrentUser() user: any) {
    return this.leadsService.findAll(user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get lead by ID' })
  @ApiResponse({ status: 200, description: 'Lead details retrieved', type: ApiResponseDto })
  @ApiResponse({ status: 404, description: 'Lead not found' })
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.leadsService.findOne(id, user);
  }

  @Post()
  @ApiOperation({ summary: 'Create new lead' })
  @ApiResponse({ status: 201, description: 'Lead created successfully', type: ApiResponseDto })
  @ApiResponse({ status: 400, description: 'Validation failed' })
  async create(@Body() dto: CreateLeadDto, @CurrentUser() user: any) {
    return this.leadsService.create(dto, user);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update lead status' })
  @ApiResponse({ status: 200, description: 'Status updated successfully', type: ApiResponseDto })
  async updateStatus(@Param('id') id: string, @Body() dto: UpdateLeadStatusDto, @CurrentUser() user: any) {
    return this.leadsService.updateStatus(id, dto, user);
  }

  @Post('bulk')
  @ApiOperation({ summary: 'Bulk update leads' })
  @ApiResponse({ status: 200, description: 'Leads updated successfully', type: ApiResponseDto })
  async bulkUpdate(@Body() dto: BulkUpdateLeadsDto, @CurrentUser() user: any) {
    return this.leadsService.bulkUpdate(dto, user);
  }

  @Post(':id/convert')
  @ApiOperation({ summary: 'Convert lead to project' })
  @ApiResponse({ status: 201, description: 'Lead converted successfully', type: ApiResponseDto })
  @ApiResponse({ status: 400, description: 'Contact mapping required before conversion' })
  async convert(@Param('id') id: string, @CurrentUser() user: any) {
    return this.leadsService.convert(id, user);
  }
}
