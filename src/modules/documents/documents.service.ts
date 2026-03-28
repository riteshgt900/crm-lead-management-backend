import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UploadDocumentDto } from './dto/document.dto';

@Injectable()
export class DocumentsService {
  constructor(private db: DatabaseService) {}

  async findAll(user: any) {
    return this.db.callDispatcher('fn_document_operations', {
      operation: 'list_documents',
      data: {},
      requestedBy: user.id,
      role: user.role,
    });
  }

  async upload(dto: UploadDocumentDto, file: any, user: any) {
    return this.db.callDispatcher('fn_document_operations', {
      operation: 'upload_document',
      data: { ...dto, fileName: file.filename, filePath: file.path, fileSize: file.size, fileType: file.mimetype },
      requestedBy: user.id,
      role: user.role,
    });
  }

  async approve(id: string, user: any) {
    return this.db.callDispatcher('fn_document_operations', {
      operation: 'approve_document',
      data: { id },
      requestedBy: user.id,
      role: user.role,
    });
  }
}
