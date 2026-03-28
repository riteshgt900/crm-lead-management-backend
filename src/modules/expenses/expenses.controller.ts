import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/expense.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('expenses')
@UseGuards(SessionGuard)
export class ExpensesController {
  constructor(private expensesService: ExpensesService) {}

  @Get()
  async findAll(@CurrentUser() user: any) {
    return this.expensesService.findAll(user);
  }

  @Post()
  async create(@Body() dto: CreateExpenseDto, @CurrentUser() user: any) {
    return this.expensesService.create(dto, user);
  }
}
