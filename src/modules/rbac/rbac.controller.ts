import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { RbacService } from './rbac.service';
import { UpdateRolePermissionsDto } from './dto/rbac.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('rbac')
@UseGuards(SessionGuard, RolesGuard)
@Roles('admin')
export class RbacController {
  constructor(private rbacService: RbacService) {}

  @Get('permissions')
  async listPermissions() {
    return this.rbacService.listPermissions();
  }

  @Get('roles')
  async listRoles() {
    return this.rbacService.listRoles();
  }

  @Post('roles/:id/permissions')
  async updateRolePermissions(@Param('id') id: string, @Body() dto: UpdateRolePermissionsDto) {
    return this.rbacService.updateRolePermissions(id, dto);
  }
}
