import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateCommunicationDto } from './dto/communication.dto';

@Injectable()
export class CommunicationsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: any, user: any) {
    return this.runCommunicationOperation('list_communications', 'list', query ?? {}, user);
  }

  async create(dto: CreateCommunicationDto, user: any) {
    const payload = {
      ...dto,
      channel: dto.channel ?? dto.type,
    };

    return this.runCommunicationOperation('create_communication', 'create', payload, user);
  }

  private async runCommunicationOperation(
    legacyOperation: string,
    genericOperation: 'list' | 'create',
    data: Record<string, unknown>,
    user: any,
  ) {
    const actor = this.actor(user);

    try {
      return await this.db.callDispatcher('fn_data_operations', {
        entityKey: 'communication',
        operation: genericOperation,
        data,
        ...actor,
      });
    } catch (error) {
      if (!this.shouldFallback(error)) {
        throw error;
      }

      return this.db.callDispatcher('fn_communication_operations', {
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
