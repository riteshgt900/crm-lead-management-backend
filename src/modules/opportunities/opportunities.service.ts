import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class OpportunitiesService {
  constructor(private readonly db: DatabaseService) {}

  private dispatch(operation: string, data: any, user: any) {
    return this.db.callDispatcher('fn_opportunity_operations', {
      operation,
      data,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  findAll(query: any, user: any) {
    return this.dispatch('list_opportunities', query ?? {}, user);
  }

  findOne(id: string, user: any) {
    return this.dispatch('get_opportunity', { id }, user);
  }

  create(dto: any, user: any) {
    return this.dispatch('create_opportunity', dto, user);
  }

  update(id: string, dto: any, user: any) {
    return this.dispatch('update_opportunity', { id, ...dto }, user);
  }

  updateStage(id: string, dto: any, user: any) {
    return this.dispatch('update_stage', { id, ...dto }, user);
  }

  closeWon(id: string, dto: any, user: any) {
    return this.dispatch('close_won', { id, ...dto }, user);
  }

  closeLost(id: string, dto: any, user: any) {
    return this.dispatch('close_lost', { id, ...dto }, user);
  }

  assign(id: string, dto: any, user: any) {
    return this.dispatch('assign_opportunity', { id, ...dto }, user);
  }

  remove(id: string, user: any) {
    return this.dispatch('delete_opportunity', { id }, user);
  }
}
