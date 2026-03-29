import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class ActivitiesService {
  constructor(private readonly db: DatabaseService) {}

  private dispatch(operation: string, data: any, user: any) {
    return this.db.callDispatcher('fn_activity_operations', {
      operation,
      data,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  list(query: any, user: any) {
    return this.dispatch('list_activities', query ?? {}, user);
  }

  globalTimeline(query: any, user: any) {
    return this.dispatch('list_global_timeline', query ?? {}, user);
  }

  logCall(dto: any, user: any) {
    return this.dispatch('log_call', dto, user);
  }

  logMeeting(dto: any, user: any) {
    return this.dispatch('log_meeting', dto, user);
  }

  logEmail(dto: any, user: any) {
    return this.dispatch('log_email', dto, user);
  }

  create(dto: any, user: any) {
    return this.dispatch('create_activity', dto, user);
  }
}
