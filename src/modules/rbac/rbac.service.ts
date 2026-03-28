import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UpdateRolePermissionsDto } from './dto/rbac.dto';

@Injectable()
export class RbacService {
  constructor(private db: DatabaseService) {}

  async listPermissions() {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'list_permissions',
      data: {},
    });
  }

  async listRoles() {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'list_roles',
      data: {},
    });
  }

  async updateRolePermissions(roleId: string, dto: UpdateRolePermissionsDto) {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'update_role_permissions',
      data: { roleId, ...dto },
    });
  }
}
