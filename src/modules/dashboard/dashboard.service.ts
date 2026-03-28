import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class DashboardService {
  constructor(private db: DatabaseService) {}

  async getStats(user: any) {
    return this.db.callDispatcher('fn_dashboard_operations', {
      operation: 'get_stats',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }
}
