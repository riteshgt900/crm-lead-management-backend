import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ListRbacQueryDto, UpdateRolePermissionsDto } from './dto/rbac.dto';

function buildRbacContext(user: any) {
  return {
    requestedBy: user?.id,
    role: user?.roleName ?? user?.role ?? null,
    permissions: user?.permissions ?? [],
  };
}

@Injectable()
export class RbacService {
  constructor(private db: DatabaseService) {}

  async listPermissions(query: ListRbacQueryDto, user: any) {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'list_permissions',
      data: query || {},
      ...buildRbacContext(user),
    });
  }

  async listRoles(query: ListRbacQueryDto, user: any) {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'list_roles',
      data: query || {},
      ...buildRbacContext(user),
    });
  }

  async updateRolePermissions(roleId: string, dto: UpdateRolePermissionsDto, user: any) {
    return this.db.callDispatcher('fn_rbac_operations', {
      operation: 'update_role_permissions',
      data: { roleId, ...dto },
      ...buildRbacContext(user),
    });
  }
}
