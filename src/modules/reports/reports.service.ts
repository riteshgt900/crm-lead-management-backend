import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ReportQueryDto } from './dto/report.dto';

@Injectable()
export class ReportsService {
  constructor(private db: DatabaseService) {}

  async generate(dto: ReportQueryDto, user: any) {
    return this.db.callDispatcher('fn_report_operations', {
      operation: 'generate_report',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
