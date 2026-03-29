import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateContactDto, UpdateContactDto } from './dto/contact.dto';

@Injectable()
export class ContactsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: any, user: any) {
    return this.runContactOperation('list_contacts', 'list', query ?? {}, user);
  }

  async findOne(id: string, user: any) {
    return this.runContactOperation('get_contact', 'get', { id }, user);
  }

  async create(dto: CreateContactDto, user: any) {
    return this.runContactOperation('create_contact', 'create', dto, user);
  }

  async update(id: string, dto: UpdateContactDto, user: any) {
    return this.runContactOperation('update_contact', 'update', { id, ...dto }, user);
  }

  private async runContactOperation(
    legacyOperation: string,
    genericOperation: 'list' | 'get' | 'create' | 'update',
    data: any,
    user: any,
  ) {
    const actor = this.actor(user);

    try {
      return await this.db.callDispatcher('fn_data_operations', {
        entityKey: 'contact',
        operation: genericOperation,
        data,
        ...actor,
      });
    } catch (error) {
      if (!this.shouldFallback(error)) {
        throw error;
      }

      return this.db.callDispatcher('fn_contact_operations', {
        operation: legacyOperation,
        data,
        requestedBy: actor.requestedBy,
        role: actor.role,
      });
    }
  }

  private actor(user: any) {
    return {
      requestedBy: user.id,
      role: user.role ?? user.roleName,
      permissions: user.permissions ?? [],
    };
  }

  private shouldFallback(error: any) {
    const message = String(error?.message ?? error ?? '');
    return (
      message.includes('fn_data_operations') &&
      (message.includes('does not exist') || message.includes('undefined function'))
    );
  }
}
