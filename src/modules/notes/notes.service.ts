import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class NotesService {
  constructor(private readonly db: DatabaseService) {}

  private dispatch(operation: string, data: any, user: any) {
    return this.db.callDispatcher('fn_notes_operations', {
      operation,
      data,
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    });
  }

  list(query: any, user: any)              { return this.dispatch('list_notes',   query ?? {}, user); }
  findOne(id: string, user: any)           { return this.dispatch('get_note',     { id }, user); }
  create(dto: any, user: any)              { return this.dispatch('create_note',  dto, user); }
  update(id: string, dto: any, user: any)  { return this.dispatch('update_note',  { id, ...dto }, user); }
  pin(id: string, user: any)               { return this.dispatch('pin_note',     { id }, user); }
  remove(id: string, user: any)            { return this.dispatch('delete_note',  { id }, user); }
}
