import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { NotesService } from './notes.service';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Notes')
@Controller('notes')
@UseGuards(SessionGuard)
export class NotesController {
  constructor(private readonly notesService: NotesService) {}

  @Get()
  @ApiOperation({ summary: 'List notes for an entity' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  list(@Query() query: any, @CurrentUser() user: any) {
    return this.notesService.list(query, user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get note by ID' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.notesService.findOne(id, user);
  }

  @Post()
  @ApiOperation({ summary: 'Create note on any entity' })
  @ApiResponse({ status: 201, type: ApiResponseDto })
  create(@Body() dto: any, @CurrentUser() user: any) {
    return this.notesService.create(dto, user);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update note content or pin status' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  update(@Param('id') id: string, @Body() dto: any, @CurrentUser() user: any) {
    return this.notesService.update(id, dto, user);
  }

  @Post(':id/pin')
  @ApiOperation({ summary: 'Toggle pin status of a note' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  pin(@Param('id') id: string, @CurrentUser() user: any) {
    return this.notesService.pin(id, user);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete a note' })
  @ApiResponse({ status: 200, type: ApiResponseDto })
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.notesService.remove(id, user);
  }
}
