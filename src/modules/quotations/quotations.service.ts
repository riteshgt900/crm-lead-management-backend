import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateQuotationDto } from './dto/quotation.dto';

@Injectable()
export class QuotationsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_quotation_operations', {
      operation: 'list_quotations',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateQuotationDto, user: any) {
    return this.db.callDispatcher('fn_quotation_operations', {
      operation: 'create_quotation',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
