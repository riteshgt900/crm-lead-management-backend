import { Controller, Get, Query, UseGuards, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { Response } from 'express';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Reports')
@Controller('reports')
@UseGuards(SessionGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get()
  @ApiOperation({ summary: 'Generate report data' })
  @ApiResponse({ status: 200, description: 'Report data retrieved', type: ApiResponseDto })
  async generate(@Query() dto: ReportQueryDto, @CurrentUser() user: any) {
    return this.reportsService.generate(dto, user);
  }

  @Get('export')
  @ApiOperation({ summary: 'Export report as CSV' })
  async export(
    @Query('type') type: string,
    @CurrentUser() user: any,
    @Res() res: Response
  ) {
    const csv = await this.reportsService.exportCsv(type, user);
    res.set({
      'Content-Disposition': `attachment; filename="report_${type}_${Date.now()}.csv"`,
    });
    return res.status(200).type('text/csv').send(csv);
  }
}
