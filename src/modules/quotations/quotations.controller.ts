import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { QuotationsService } from './quotations.service';
import { CreateQuotationDto } from './dto/quotation.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('quotations')
@UseGuards(SessionGuard)
export class QuotationsController {
  constructor(private quotationsService: QuotationsService) {}

  @Get()
  async findAll(@Query() query: any, @CurrentUser() user: any) {
    return this.quotationsService.findAll(query, user);
  }

  @Post()
  async create(@Body() dto: CreateQuotationDto, @CurrentUser() user: any) {
    return this.quotationsService.create(dto, user);
  }
}
