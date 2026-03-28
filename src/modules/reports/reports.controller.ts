import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('reports')
@UseGuards(SessionGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get()
  async generate(@Query() dto: ReportQueryDto, @CurrentUser() user: any) {
    return this.reportsService.generate(dto, user);
  }
}
