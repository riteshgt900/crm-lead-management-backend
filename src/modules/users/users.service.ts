import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateUserDto, UpdateUserDto } from './dto/user.dto';

@Injectable()
export class UsersService {
  constructor(private db: DatabaseService) {}

  async findAll() {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'list_users',
      data: {},
    });
  }

  async invite(dto: CreateUserDto, requestedBy: string) {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'invite_user',
      data: dto,
      requestedBy,
    });
  }

  async update(id: string, dto: UpdateUserDto, requestedBy: string) {
    return this.db.callDispatcher('fn_user_operations', {
      operation: 'update_user',
      data: { id, ...dto },
      requestedBy,
    });
  }
}
