import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { ReportsService } from '../reports/reports.service';
import { EmailService } from '../email/email.service';

@Injectable()
export class CronService {
  private readonly logger = new Logger(CronService.name);

  constructor(
    private db: DatabaseService,
    private reportsService: ReportsService,
    private emailService: EmailService,
  ) {}

  @Cron('0 9 * * 1') // Monday at 9:00 AM
  async sendWeeklyPerformanceSummary() {
    this.logger.log('Generating weekly performance summary for admins...');
    
    // 1. Get stats for the last 7 days (Using a system admin role)
    const summary = await this.reportsService.getWeeklySummary({ 
      id: '00000000-0000-0000-0000-000000000000', 
      role: 'admin' 
    });
    
    if (summary.statusCode === 200) {
      const stats = summary.data;
      
      await this.emailService.sendEmail(
        process.env.ADMIN_REPORT_RECIPIENT || 'admin@example.com',
        'Weekly CRM Performance Summary',
        'performance_summary_report', // Template name
        { 
          newLeads: stats.newLeads || 0,
          convertedLeads: stats.convertedLeads || 0,
          completedTasks: stats.completedTasks || 0,
          date: new Date().toLocaleDateString()
        }
      );
      this.logger.log('Weekly performance summary sent successfully.');
    }
  }

  @Cron(CronExpression.EVERY_HOUR)
  async handleEscalations() {
    this.logger.log('Processing task escalations...');
    await this.db.callDispatcher('fn_task_escalations', {});
  }

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async cleanupSessions() {
    this.logger.log('Cleaning up expired sessions...');
    await this.db.callDispatcher('fn_auth_operations', {
      operation: 'cleanup_sessions',
      data: {},
    });
  }
}
