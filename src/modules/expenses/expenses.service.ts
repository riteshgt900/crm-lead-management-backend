import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateExpenseDto } from './dto/expense.dto';

@Injectable()
export class ExpensesService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: any, user: any) {
    return this.runExpenseOperation('list_expenses', 'list', query ?? {}, user);
  }

  async create(dto: CreateExpenseDto, user: any) {
    return this.runExpenseOperation('create_expense', 'create', dto, user);
  }

  private async runExpenseOperation(
    legacyOperation: string,
    genericOperation: 'list' | 'create',
    data: any,
    user: any,
  ) {
    const actor = this.actor(user);

    try {
      return await this.db.callDispatcher('fn_data_operations', {
        entityKey: 'expense',
        operation: genericOperation,
        data,
        ...actor,
      });
    } catch (error) {
      if (!this.shouldFallback(error)) {
        throw error;
      }

      return this.db.callDispatcher('fn_expense_operations', {
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
