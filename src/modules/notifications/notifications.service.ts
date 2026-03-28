import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UpdateNotificationDto } from './dto/notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_notification_operations', {
      operation: 'list_notifications',
      data: { userId: user.id },
    });
  }

  async markAsRead(id: string, user: any) {
    return this.db.callDispatcher('fn_notification_operations', {
      operation: 'mark_as_read',
      data: { id, userId: user.id },
    });
  }
}
