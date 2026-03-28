import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuditService } from './audit.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('audit')
@UseGuards(SessionGuard, RolesGuard)
@Roles('admin')
export class AuditController {
  constructor(private auditService: AuditService) {}

  @Get()
  async findAll(@CurrentUser() user: any) {
    return this.auditService.findAll(user);
  }
}
