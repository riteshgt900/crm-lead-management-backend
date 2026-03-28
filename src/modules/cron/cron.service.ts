import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class CronService {
  private readonly logger = new Logger(CronService.name);

  constructor(private db: DatabaseService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async handleWorkflows() {
    this.logger.debug('Running background workflow engine...');
    // In a real app, this would query pending workflow_executions
    // and process them calling the appropriate module services.
    await this.db.callDispatcher('fn_workflow_operations', {
      operation: 'process_pending_executions',
      data: {},
    });
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
