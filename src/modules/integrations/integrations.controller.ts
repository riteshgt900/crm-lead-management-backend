import { Controller, Get, UseGuards } from '@nestjs/common';
import { IntegrationsService } from './integrations.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('integrations')
@UseGuards(SessionGuard, RolesGuard)
@Roles('admin')
export class IntegrationsController {
  constructor(private integrationsService: IntegrationsService) {}

  @Get('configs')
  async getConfigs() {
    return this.integrationsService.getConfigs();
  }
}
