import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SlasService {
  constructor(private readonly db: DatabaseService) {}

  private dispatch(operation: string, data: any, user: any) {
    return this.db.callDispatcher('fn_sla_operations', {
      operation,
      data,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  listPolicies(query: any, user: any)         { return this.dispatch('list_sla_policies',   query ?? {}, user); }
  createPolicy(dto: any, user: any)            { return this.dispatch('create_sla_policy',   dto, user); }
  updatePolicy(id: string, dto: any, user: any){ return this.dispatch('update_sla_policy',   { id, ...dto }, user); }
  deletePolicy(id: string, user: any)          { return this.dispatch('delete_sla_policy',   { id }, user); }
  checkBreaches(user: any)                     { return this.dispatch('check_sla_breaches',  {}, user); }
  listEscalations(query: any, user: any)       { return this.dispatch('list_escalations',    query ?? {}, user); }
  resolveEscalation(id: string, user: any)     { return this.dispatch('resolve_escalation',  { id }, user); }
}
