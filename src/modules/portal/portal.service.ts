import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { LoginDto, AddCommentDto, UploadDocDto, InviteDto } from './dto/portal.dto';

@Injectable()
export class PortalService {
  constructor(private readonly db: DatabaseService) {}

  async login(dto: LoginDto): Promise<any> {
    return this.db.callDispatcher('fn_portal_operations', {
      operation: 'join',
      token: dto.token
    });
  }

  async getProjects(token: string): Promise<any> {
    return this.db.callDispatcher('fn_portal_operations', {
      operation: 'list_projects',
      token
    });
  }

  async getProjectDetails(token: string, projectId: string): Promise<any> {
    return this.db.callDispatcher('fn_portal_operations', {
      operation: 'get_project_details',
      token,
      project_id: projectId
    });
  }

  async addComment(token: string, dto: AddCommentDto): Promise<any> {
    const result = await this.db.callDispatcher('fn_portal_operations', {
      operation: 'add_comment',
      token,
      task_id: dto.taskId,
      content: dto.content
    });

    // Basic notification dispatching for internal users
    try {
      await this.db.callDispatcher('fn_notification_operations', {
        operation: 'create_notification',
        title: 'New Portal Comment',
        message: `An external client added a comment to task: ${dto.taskId}`,
        action_url: `/tasks/${dto.taskId}`
      });
    } catch (error) {
      console.warn('Failed to dispatch notification:', error);
    }
    return result;
  }

  async uploadDocument(token: string, dto: UploadDocDto): Promise<any> {
    const result = await this.db.callDispatcher('fn_portal_operations', {
      operation: 'upload_document',
      token,
      project_id: dto.projectId,
      file_name: dto.fileName
    });

    // Basic notification dispatching for internal users
    try {
      await this.db.callDispatcher('fn_notification_operations', {
        operation: 'create_notification',
        title: 'New Portal Document Upload',
        message: `An external client uploaded a document (${dto.fileName}) to project: ${dto.projectId}`,
        action_url: `/projects/${dto.projectId}`
      });
    } catch (error) {
      console.warn('Failed to dispatch notification:', error);
    }
    return result;
  }

  async invite(userId: string, dto: InviteDto): Promise<any> {
    return this.db.callDispatcher('fn_portal_operations', {
      operation: 'invite',
      req_user_id: userId,
      project_id: dto.projectId,
      email: dto.email,
      role: dto.role
    });
  }
}
