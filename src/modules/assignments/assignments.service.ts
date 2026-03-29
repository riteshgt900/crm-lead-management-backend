import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class AssignmentsService {
  constructor(private readonly db: DatabaseService) {}

  private dispatch(operation: string, data: any, user: any) {
    return this.db.callDispatcher('fn_assignment_operations', {
      operation,
      data,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  listPools(query: any, user: any)              { return this.dispatch('list_pools',             query ?? {}, user); }
  createPool(dto: any, user: any)               { return this.dispatch('create_pool',            dto, user); }
  deletePool(id: string, user: any)             { return this.dispatch('delete_pool',            { id }, user); }
  addMember(dto: any, user: any)                { return this.dispatch('add_pool_member',        dto, user); }
  removeMember(dto: any, user: any)             { return this.dispatch('remove_pool_member',     dto, user); }
  listHistory(query: any, user: any)            { return this.dispatch('list_assignment_history',query ?? {}, user); }
  getUnassignedLeads(query: any, user: any)     { return this.dispatch('get_unassigned_leads',   query ?? {}, user); }
}
