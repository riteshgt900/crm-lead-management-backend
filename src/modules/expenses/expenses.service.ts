import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateExpenseDto } from './dto/expense.dto';

@Injectable()
export class ExpensesService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_expense_operations', {
      operation: 'list_expenses',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async create(dto: CreateExpenseDto, user: any) {
    return this.db.callDispatcher('fn_expense_operations', {
      operation: 'create_expense',
      data: dto,
      requestedBy: user.id,
      role: user.role,
    });
  }
}
