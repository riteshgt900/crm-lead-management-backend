import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateUserDto, ListUsersQueryDto, UpdateUserDto } from './dto/user.dto';

function buildUserContext(user: any) {
  return {
    requestedBy: user?.id,
    role: user?.roleName ?? user?.role ?? null,
    permissions: user?.permissions ?? [],
  };
}

@Injectable()
export class UsersService {
  constructor(private db: DatabaseService) {}

  async findAll(query: ListUsersQueryDto, user: any) {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'list_users',
      data: query || {},
      ...buildUserContext(user),
    });
  }

  async invite(dto: CreateUserDto, user: any) {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'invite_user',
      data: dto,
      ...buildUserContext(user),
    });
  }

  async update(id: string, dto: UpdateUserDto, user: any) {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'update_user',
      data: { id, ...dto },
      ...buildUserContext(user),
    });
  }
}
