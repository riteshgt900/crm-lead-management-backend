import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { CommunicationsService } from './communications.service';
import { CreateCommunicationDto } from './dto/communication.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('communications')
@UseGuards(SessionGuard)
export class CommunicationsController {
  constructor(private communicationsService: CommunicationsService) {}

  @Get()
  async findAll(@Query() query: any, @CurrentUser() user: any) {
    return this.communicationsService.findAll(query, user);
  }

  @Post()
  async create(@Body() dto: CreateCommunicationDto, @CurrentUser() user: any) {
    return this.communicationsService.create(dto, user);
  }
}
