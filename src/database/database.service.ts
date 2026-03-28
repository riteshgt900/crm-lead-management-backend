import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  BadRequestException,
  UnauthorizedException,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private pool!: Pool;
  private readonly ALLOWED_FUNCTIONS = new Set([
    'fn_auth_operations',
    'fn_lead_operations',
    'fn_user_operations',
    'fn_contact_operations',
    'fn_project_operations',
    'fn_task_operations',
    'fn_document_operations',
    'fn_communication_operations',
    'fn_quotation_operations',
    'fn_expense_operations',
    'fn_workflow_operations',
    'fn_notification_operations',
    'fn_report_operations',
    'fn_dashboard_operations',
    'fn_search_operations',
    'fn_audit_operations',
    'fn_integration_operations',
    'fn_share_operations',
    'fn_rbac_operations',
    'fn_settings_operations',
  ]);

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    this.pool = new Pool({
      connectionString: this.configService.get<string>('DATABASE_URL'),
      options: '-c search_path=crm,public',
    });
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async callDispatcher(fnName: string, payload: any) {
    if (!this.ALLOWED_FUNCTIONS.has(fnName)) {
      throw new BadRequestException({ rid: 'e-invalid-fn', message: `Function ${fnName} is not allowed` });
    }

    const result = await this.pool.query(`SELECT ${fnName}($1::jsonb) AS res`, [
      JSON.stringify(payload),
    ]);

    const res = result.rows[0].res;

    if (res.statusCode >= 400) {
      this.throwHttpException(res);
    }

    return res;
  }

  private throwHttpException(res: any) {
    const { rid, statusCode, message, errors } = res;
    const errorPayload = { rid, message, errors };

    switch (statusCode) {
      case 400: throw new BadRequestException(errorPayload);
      case 401: throw new UnauthorizedException(errorPayload);
      case 403: throw new ForbiddenException(errorPayload);
      case 404: throw new NotFoundException(errorPayload);
      case 409: throw new ConflictException(errorPayload);
      default: throw new InternalServerErrorException(errorPayload);
    }
  }

  async query(sql: string, params?: any[]) {
    return this.pool.query(sql, params);
  }
}
