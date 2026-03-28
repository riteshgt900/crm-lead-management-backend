import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateCommunicationDto } from './dto/communication.dto';

@Injectable()
export class CommunicationsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_communication_operations', {
      operation: 'list_communications',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateCommunicationDto, user: any) {
    return this.db.callDispatcher('fn_communication_operations', {
      operation: 'create_communication',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
