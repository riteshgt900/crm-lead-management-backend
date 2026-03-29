import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class AuditService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.callRuntimeAware('audit.list_logs', 'fn_audit_operations', {
      operation: 'list_logs',
      data: {},
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
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
