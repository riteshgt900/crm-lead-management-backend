import {
  Body,
  Controller,
  Get,
  Post,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { DocumentsService } from './documents.service';
import { ApproveDocumentDto, UploadDocumentDto } from './dto/document.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

@Controller('documents')
@UseGuards(SessionGuard)
export class DocumentsController {
  constructor(private documentsService: DocumentsService) {}

  @Get()
  async findAll(@Query() query: Record<string, unknown>, @CurrentUser() user: any) {
    return this.documentsService.findAll(query, user);
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async upload(
    @Body() dto: UploadDocumentDto,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: any,
  ) {
    return this.documentsService.upload(dto, file, user);
  }

  @Public()
  @Post(':id/approve')
  async approve(
    @Param('id') id: string,
    @Body() dto: ApproveDocumentDto,
    @CurrentUser() user: any,
  ) {
    // CurrentUser might be null for public/external approval
    return this.documentsService.approve(
      id,
      dto,
      user || {
        id: '00000000-0000-0000-0000-000000000000',
        role: 'external',
        roleName: 'external',
        permissions: [],
      },
    );
  }
}
