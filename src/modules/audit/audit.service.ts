import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class AuditService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_audit_operations', {
      operation: 'list_audit_logs',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }
}
