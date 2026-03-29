import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import {
  BulkUpdateLeadsDto,
  ConvertLeadDto,
  CreateLeadDto,
  UpdateLeadDto,
  UpdateLeadStatusDto,
} from './dto/lead.dto';

@Injectable()
export class LeadsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: any, user: any) {
    return this.db.callDispatcher('fn_data_operations', {
      entityKey: 'lead',
      operation: 'list',
      data: query ?? {},
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async findOne(id: string, user: any) {
    return this.db.callDispatcher('fn_data_operations', {
      entityKey: 'lead',
      operation: 'get',
      data: { id },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async create(dto: CreateLeadDto, user: any) {
    return this.db.callDispatcher('fn_data_operations', {
      entityKey: 'lead',
      operation: 'create',
      data: dto,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async updateLead(id: string, dto: UpdateLeadDto, user: any) {
    return this.db.callDispatcher('fn_data_operations', {
      entityKey: 'lead',
      operation: 'update',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async updateStatus(id: string, dto: UpdateLeadStatusDto, user: any) {
    return this.db.callDispatcher('fn_action_operations', {
      actionKey: 'lead.update_status',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async bulkUpdate(dto: BulkUpdateLeadsDto, user: any) {
    return this.db.callDispatcher('fn_data_operations', {
      entityKey: 'lead',
      operation: 'bulk',
      data: dto,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  async convert(id: string, dto: ConvertLeadDto, user: any) {
    return this.db.callDispatcher('fn_action_operations', {
      actionKey: 'lead.convert',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }
}
