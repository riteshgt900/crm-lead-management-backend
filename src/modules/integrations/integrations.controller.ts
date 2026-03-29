import { Controller, ForbiddenException, Get, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { IntegrationsService } from './integrations.service';
import { IntegrationConfigsQueryDto } from './dto/integration-config.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Integrations')
@Controller('integrations')
@UseGuards(SessionGuard)
export class IntegrationsController {
  constructor(private integrationsService: IntegrationsService) {}

  @Get('configs')
  @ApiOperation({ summary: 'Get integration configs' })
  async getConfigs(@Query() query: IntegrationConfigsQueryDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.integrationsService.getConfigs(query, user);
  }

  private assertAdmin(user: any) {
    const roleName = user?.roleName ?? user?.role;
    if (roleName !== 'admin') {
      throw new ForbiddenException({ rid: 'e-forbidden', message: 'Insufficient permissions' });
    }
  }
}
