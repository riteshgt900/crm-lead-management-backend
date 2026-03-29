import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { SearchQueryDto } from './dto/search.dto';

@Injectable()
export class SearchService {
  constructor(private db: DatabaseService) {}

  async globalSearch(dto: SearchQueryDto, user: any) {
    return this.callRuntimeAware('search.global', 'fn_search_operations', {
      operation: 'global_search',
      data: dto,
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
