import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class IntegrationsService {
  constructor(private db: DatabaseService) {}

  async getConfigs(query: any, user: any) {
    return this.db.callDispatcher('fn_integration_operations', {
      operation: 'get_configs',
      data: query || {},
      requestedBy: user?.id,
      role: user?.roleName ?? user?.role ?? null,
      permissions: user?.permissions ?? [],
    });
  }
}
