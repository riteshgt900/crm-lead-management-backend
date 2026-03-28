import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateContactDto, UpdateContactDto } from './dto/contact.dto';

@Injectable()
export class ContactsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_contact_operations', {
      operation: 'list_contacts',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateContactDto, user: any) {
    return this.db.callDispatcher('fn_contact_operations', {
      operation: 'create_contact',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }

  async update(id: string, dto: UpdateContactDto, user: any) {
    return this.db.callDispatcher('fn_contact_operations', {
      operation: 'update_contact',
      data: { id, ...dto },
      requestedBy: user.id,
      role: user.role,
    });
  }
}
