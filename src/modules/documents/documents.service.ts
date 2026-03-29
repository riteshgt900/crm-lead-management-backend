import { HttpException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ApproveDocumentDto, UploadDocumentDto } from './dto/document.dto';

@Injectable()
export class DocumentsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query: Record<string, unknown>, user: any) {
    const actor = this.resolveActor(user);
    const payload = {
      entityKey: 'document',
      operation: 'list',
      data: query || {},
      requestedBy: actor.requestedBy,
      role: actor.role,
      permissions: actor.permissions,
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_data_operations', payload),
      () => this.db.callDispatcher('fn_document_operations', {
        operation: 'list_documents',
        data: query || {},
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
    );
  }

  async upload(dto: UploadDocumentDto, file: any, user: any) {
    const actor = this.resolveActor(user);
    const metadata = {
      ...dto,
      entityType: dto.entityType || dto.moduleName,
      file: {
        filename: file?.filename,
        path: file?.path,
        size: file?.size,
        mimetype: file?.mimetype,
        originalName: file?.originalname,
      },
      fileName: file?.filename,
      filePath: file?.path,
      fileSize: file?.size,
      fileType: file?.mimetype,
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_action_operations', {
        actionKey: 'document.upload',
        data: metadata,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
      () => this.db.callDispatcher('fn_document_operations', {
        operation: 'upload_document',
        data: metadata,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
    );
  }

  async approve(id: string, dto: ApproveDocumentDto, user: any) {
    const actor = this.resolveActor(user);
    const payload = {
      id,
      decision: dto.decision || 'approved',
      comment: dto.comment,
      versionLabel: dto.versionLabel,
      parentDocumentId: dto.parentDocumentId,
      requestedBy: actor.requestedBy,
      role: actor.role,
      permissions: actor.permissions,
    };

    return this.dispatchWithFallback(
      () => this.db.callDispatcher('fn_action_operations', {
        actionKey: 'document.approve',
        data: payload,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
      () => this.db.callDispatcher('fn_document_operations', {
        operation: 'approve_document',
        data: payload,
        requestedBy: actor.requestedBy,
        role: actor.role,
        permissions: actor.permissions,
      }),
    );
  }

  private resolveActor(user: any) {
    return {
      requestedBy: user?.id ?? '00000000-0000-0000-0000-000000000000',
      role: user?.role ?? user?.roleName ?? 'external',
      permissions: user?.permissions ?? [],
    };
  }

  private async dispatchWithFallback<T>(primary: () => Promise<T>, fallback: () => Promise<T>) {
    try {
      return await primary();
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      return fallback();
    }
  }
}
