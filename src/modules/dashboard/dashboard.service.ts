import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class DashboardService {
  constructor(private readonly db: DatabaseService) {}

  async getStats(user: any) {
    return this.callRuntimeAware(
      'dashboard.stats',
      'fn_dashboard_operations',
      {
        operation: 'get_stats',
        data: {},
        requestedBy: user.id,
        role: user.role ?? user.roleName,
        permissions: user.permissions ?? [],
      },
    );
  }

  private async callRuntimeAware(
    endpointKey: string,
    fallbackFn: string,
    payload: Record<string, unknown>,
  ) {
    const registryEntry = await this.db.getRegistryEntry(endpointKey);

    if (registryEntry?.dispatcherFn && registryEntry.isEnabled) {
      return this.db.callDispatcher(registryEntry.dispatcherFn, payload);
    }

    return this.db.callDispatcher(fallbackFn, payload);
  }
}
