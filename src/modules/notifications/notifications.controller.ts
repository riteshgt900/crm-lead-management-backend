import { Body, Controller, Get, Patch, Param, Query, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UpdateNotificationDto } from './dto/notification.dto';

@Controller('notifications')
@UseGuards(SessionGuard)
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  async findAll(@Query() query: Record<string, unknown>, @CurrentUser() user: any) {
    return this.notificationsService.findAll(query, user);
  }

  @Patch(':id/read')
  async markAsRead(
    @Param('id') id: string,
    @Body() dto: UpdateNotificationDto,
    @CurrentUser() user: any,
  ) {
    return this.notificationsService.markAsRead(id, dto, user);
  }
}
