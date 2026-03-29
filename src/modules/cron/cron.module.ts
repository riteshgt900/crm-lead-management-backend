import { Module } from '@nestjs/common';
import { CronService } from './cron.service';
import { ReportsModule } from '../reports/reports.module';
import { EmailModule } from '../email/email.module';

@Module({
  imports: [ReportsModule, EmailModule],
  providers: [CronService],
})
export class CronModule {}
