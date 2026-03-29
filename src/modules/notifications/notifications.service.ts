import { HttpException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UpdateNotificationDto } from './dto/notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: Record<string, unknown>, user: any) {
    const actor = this.resolveActor(user);
    const payload = {
      entityKey: 'notification',
      operation: 'list',
      data: { ...(query || {}), userId: actor.requestedBy },
      requestedBy: actor.requestedBy,
      role: actor.role,
      permissions: actor.permissions,
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_data_operations', payload),
      () => this.db.callDispatcher('fn_notification_operations', {
        operation: 'list_notifications',
        data: { ...(query || {}), userId: actor.requestedBy },
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
    );
  }

  async markAsRead(id: string, dto: UpdateNotificationDto, user: any) {
    const actor = this.resolveActor(user);
    const payload = {
      id,
      userId: actor.requestedBy,
      isRead: dto?.isRead ?? true,
      readAt: dto?.readAt,
      note: dto?.note,
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_action_operations', {
        actionKey: 'notification.mark_read',
        data: payload,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
      () => this.db.callDispatcher('fn_notification_operations', {
        operation: 'mark_as_read',
        data: payload,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
    );
  }

  private resolveActor(user: any) {
    return {
      requestedBy: user?.id ?? '00000000-0000-0000-0000-000000000000',
      role: user?.role ?? user?.roleName ?? 'external',
      permissions: user?.permissions ?? [],
    };
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
