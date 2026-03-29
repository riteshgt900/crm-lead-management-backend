import { HttpException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class ShareService {
  constructor(private readonly db: DatabaseService) {}

  async getSharedEntity(token: string) {
    const payload = {
      actionKey: 'share.resolve',
      data: { token, accessToken: token, shareMode: 'public' },
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_action_operations', payload),
      () => this.db.callDispatcher('fn_share_operations', {
        operation: 'get_shared_entity',
        data: { token },
      }),
    );
  }

  private async dispatchWithFallback<T>(primary: () => Promise<T>, fallback: () => Promise<T>) {
    try {
      return await primary();
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      return fallback();
    }
  }
}
