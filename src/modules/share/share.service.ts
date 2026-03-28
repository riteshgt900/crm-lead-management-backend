import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class ShareService {
  constructor(private db: DatabaseService) {}

  async getSharedEntity(token: string) {
    return this.db.callDispatcher('fn_share_operations', {
      operation: 'get_shared_entity',
      data: { token },
    });
  }
}
