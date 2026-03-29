import { Body, Controller, ForbiddenException, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { RbacService } from './rbac.service';
import { ListRbacQueryDto, UpdateRolePermissionsDto } from './dto/rbac.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('RBAC')
@Controller('rbac')
@UseGuards(SessionGuard)
export class RbacController {
  constructor(private rbacService: RbacService) {}

  @Get('permissions')
  @ApiOperation({ summary: 'List available permissions' })
  async listPermissions(@Query() query: ListRbacQueryDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.rbacService.listPermissions(query, user);
  }

  @Get('roles')
  @ApiOperation({ summary: 'List roles' })
  async listRoles(@Query() query: ListRbacQueryDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.rbacService.listRoles(query, user);
  }

  @Post('roles/:id/permissions')
  @ApiOperation({ summary: 'Update role permissions' })
  async updateRolePermissions(@Param('id') id: string, @Body() dto: UpdateRolePermissionsDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.rbacService.updateRolePermissions(id, dto, user);
  }

  private assertAdmin(user: any) {
    const roleName = user?.roleName ?? user?.role;
    if (roleName !== 'admin') {
      throw new ForbiddenException({ rid: 'e-forbidden', message: 'Insufficient permissions' });
    }
  }
}
