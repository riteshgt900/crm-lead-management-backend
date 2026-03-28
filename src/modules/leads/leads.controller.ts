import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { LeadsService } from './leads.service';
import { CreateLeadDto, UpdateLeadStatusDto, BulkUpdateLeadsDto } from './dto/lead.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('leads')
@UseGuards(SessionGuard)
export class LeadsController {
  constructor(private leadsService: LeadsService) {}

  @Get()
  async findAll(@CurrentUser() user: any) {
    return this.leadsService.findAll(user);
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.leadsService.findOne(id, user);
  }

  @Post()
  async create(@Body() dto: CreateLeadDto, @CurrentUser() user: any) {
    return this.leadsService.create(dto, user);
  }

  @Patch(':id/status')
  async updateStatus(@Param('id') id: string, @Body() dto: UpdateLeadStatusDto, @CurrentUser() user: any) {
    return this.leadsService.updateStatus(id, dto, user);
  }

  @Post('bulk')
  async bulkUpdate(@Body() dto: BulkUpdateLeadsDto, @CurrentUser() user: any) {
    return this.leadsService.bulkUpdate(dto, user);
  }

  @Post(':id/convert')
  async convert(@Param('id') id: string, @CurrentUser() user: any) {
    return this.leadsService.convert(id, user);
  }
}
