import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { TasksService } from './tasks.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('tasks')
@UseGuards(SessionGuard)
export class TasksController {
  constructor(private tasksService: TasksService) {}

  @Get()
  async findAll(@CurrentUser() user: any) {
    return this.tasksService.findAll(user);
  }

  @Post()
  async create(@Body() dto: CreateTaskDto, @CurrentUser() user: any) {
    return this.tasksService.create(dto, user);
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateTaskDto, @CurrentUser() user: any) {
    return this.tasksService.update(id, dto, user);
  }
}
