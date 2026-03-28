import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateLeadDto, UpdateLeadStatusDto, BulkUpdateLeadsDto } from './dto/lead.dto';

@Injectable()
export class LeadsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'list_leads',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async findOne(id: string, user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'get_lead',
      data: { id },
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateLeadDto, user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'create_lead',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }

  async updateStatus(id: string, dto: UpdateLeadStatusDto, user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'update_status',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role,
    });
  }

  async bulkUpdate(dto: BulkUpdateLeadsDto, user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'bulk_update',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }

  async convert(id: string, user: any) {
    return this.db.callDispatcher('fn_lead_operations', {
      operation: 'convert_lead',
      data: { id },
      requestedBy: user.id,
      role: user.role,
    });
  }
}
