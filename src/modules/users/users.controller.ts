import { Body, Controller, Get, Param, Patch, Post, Query, ForbiddenException, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto, ListUsersQueryDto, UpdateUserDto } from './dto/user.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Users')
@Controller('users')
@UseGuards(SessionGuard)
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'List users', description: 'Returns the current tenant user list with pagination and filters.' })
  async findAll(@Query() query: ListUsersQueryDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.usersService.findAll(query, user);
  }

  @Post('invite')
  async invite(@Body() dto: CreateUserDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.usersService.invite(dto, user);
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateUserDto, @CurrentUser() user: any) {
    this.assertAdmin(user);
    return this.usersService.update(id, dto, user);
  }

  private assertAdmin(user: any) {
    const roleName = user?.roleName ?? user?.role;
    if (roleName !== 'admin') {
      throw new ForbiddenException({ rid: 'e-forbidden', message: 'Insufficient permissions' });
    }
  }
}
