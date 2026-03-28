import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { SearchQueryDto } from './dto/search.dto';

@Injectable()
export class SearchService {
  constructor(private db: DatabaseService) {}

  async globalSearch(dto: SearchQueryDto, user: any) {
    return this.db.callDispatcher('fn_search_operations', {
      operation: 'global_search',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
