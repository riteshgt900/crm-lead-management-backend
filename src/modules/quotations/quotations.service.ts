import { BadRequestException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateQuotationDto } from './dto/quotation.dto';

@Injectable()
export class QuotationsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: any, user: any) {
    return this.runQuotationOperation('list_quotations', 'list', query ?? {}, user);
  }

  async create(dto: CreateQuotationDto, user: any) {
    const items = dto.lineItems ?? dto.items ?? [];
    if (items.length === 0) {
      throw new BadRequestException({
        rid: 'e-quotation-items-required',
        message: 'At least one quotation item is required',
      });
    }

    const payload = {
      ...dto,
      items,
      lineItems: items,
    };

    return this.runQuotationOperation('create_quotation', 'create', payload, user);
  }

  private async runQuotationOperation(
    legacyOperation: string,
    genericOperation: 'list' | 'create',
    data: Record<string, unknown>,
    user: any,
  ) {
    const actor = this.actor(user);

    try {
      return await this.db.callDispatcher('fn_data_operations', {
        entityKey: 'quotation',
        operation: genericOperation,
        data,
        ...actor,
      });
    } catch (error) {
      if (!this.shouldFallback(error)) {
        throw error;
      }

      return this.db.callDispatcher('fn_quotation_operations', {
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
