import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { SessionGuard } from '../../common/guards/session.guard';
import { RuntimeService } from './runtime.service';
import { RuntimeUser } from './runtime.types';

@ApiTags('Runtime')
@Controller()
@UseGuards(SessionGuard)
export class RuntimeController {
  constructor(private readonly runtimeService: RuntimeService) {}

  @Get('meta/bootstrap')
  @ApiOperation({ summary: 'Load CRM runtime bootstrap metadata' })
  bootstrap(@CurrentUser() user: RuntimeUser) {
    return this.runtimeService.bootstrap(user);
  }

  @Get('meta/entities')
  @ApiOperation({ summary: 'List runtime entities' })
  listEntities() {
    return this.runtimeService.listEntities();
  }

  @Get('meta/entities/:entityKey')
  @ApiOperation({ summary: 'Load runtime entity metadata' })
  getEntity(@Param('entityKey') entityKey: string) {
    return this.runtimeService.getEntity(entityKey);
  }

  @Post('data/:entityKey/list')
  @ApiOperation({ summary: 'Generic entity list' })
  listRecords(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.listRecords(entityKey, body, user);
  }

  @Post('data/:entityKey/get')
  @ApiOperation({ summary: 'Generic entity get' })
  getRecord(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.getRecord(entityKey, body, user);
  }

  @Post('data/:entityKey/create')
  @ApiOperation({ summary: 'Generic entity create' })
  createRecord(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.createRecord(entityKey, body, user);
  }

  @Post('data/:entityKey/update')
  @ApiOperation({ summary: 'Generic entity update' })
  updateRecord(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.updateRecord(entityKey, body, user);
  }

  @Post('data/:entityKey/delete')
  @ApiOperation({ summary: 'Generic entity delete' })
  deleteRecord(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.deleteRecord(entityKey, body, user);
  }

  @Post('data/:entityKey/bulk')
  @ApiOperation({ summary: 'Generic entity bulk operation' })
  bulkRecord(
    @Param('entityKey') entityKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.bulkRecord(entityKey, body, user);
  }

  @Post('action/:actionKey')
  @ApiOperation({ summary: 'Execute a generic CRM action' })
  executeAction(
    @Param('actionKey') actionKey: string,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: RuntimeUser,
  ) {
    return this.runtimeService.executeAction(actionKey, body, user);
  }

  @Public()
  @Get('contracts/frontend')
  @ApiOperation({ summary: 'Return frontend contract JSON' })
  getFrontendContract() {
    return this.runtimeService.frontendContract();
  }
}

