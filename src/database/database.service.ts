import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, QueryResult, QueryResultRow } from 'pg';

type RegistryEntry = {
  endpointKey: string;
  dispatcherFn: string | null;
  permissionSlug: string | null;
  httpMethod: string | null;
  routePath: string | null;
  isPublic: boolean;
  isEnabled: boolean;
};

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private pool!: Pool;

  private readonly baseAllowedFunctions = new Set([
    'fn_action_operations',
    'fn_audit_operations',
    'fn_auth_operations',
    'fn_communication_operations',
    'fn_contact_operations',
    'fn_contract_operations',
    'fn_dashboard_operations',
    'fn_data_operations',
    'fn_document_operations',
    'fn_expense_operations',
    'fn_integration_operations',
    'fn_lead_operations',
    'fn_metadata_operations',
    'fn_notification_operations',
    'fn_project_operations',
    'fn_quotation_operations',
    'fn_rbac_operations',
    'fn_report_operations',
    'fn_search_operations',
    'fn_settings_operations',
    'fn_share_operations',
    'fn_task_operations',
    'fn_user_operations',
    'fn_workflow_operations',
  ]);

  private readonly registryTtlMs = 30_000;
  private registryLoadedAt = 0;
  private registryCache = new Map<string, RegistryEntry>();
  private registryFunctionCache = new Set<string>();

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    this.pool = new Pool({
      connectionString: this.configService.get<string>('DATABASE_URL'),
      options: '-c search_path=crm,public',
    });

    await this.refreshRuntimeRegistry(true);
  }

  async onModuleDestroy() {
    if (this.pool) {
      await this.pool.end();
    }
  }

  async callDispatcher(fnName: string, payload: unknown) {
    const isAllowed = await this.isAllowedFunction(fnName);
    if (!isAllowed) {
      throw new BadRequestException({
        rid: 'e-invalid-fn',
        message: `Function ${fnName} is not allowed`,
      });
    }

    const result = await this.pool.query(`SELECT ${fnName}($1::jsonb) AS res`, [
      JSON.stringify(payload ?? {}),
    ]);

    const res = result.rows[0]?.res;
    if (!res) {
      throw new InternalServerErrorException({
        rid: 'e-empty-dispatcher-response',
        message: `Function ${fnName} returned an empty response`,
      });
    }

    if (res.statusCode >= 400) {
      this.throwHttpException(res);
    }

    return res;
  }

  async callRegisteredEndpoint(endpointKey: string, payload: unknown) {
    const registry = await this.getRuntimeRegistry();
    const entry = registry.get(endpointKey);

    if (!entry || !entry.isEnabled || !entry.dispatcherFn) {
      throw new BadRequestException({
        rid: 'e-endpoint-not-registered',
        message: `Endpoint ${endpointKey} is not registered`,
      });
    }

    return this.callDispatcher(entry.dispatcherFn, payload);
  }

  async getRegistryEntry(endpointKey: string) {
    const registry = await this.getRuntimeRegistry();
    return registry.get(endpointKey) ?? null;
  }

  async getRuntimeRegistry(force = false) {
    await this.refreshRuntimeRegistry(force);
    return this.registryCache;
  }

  async refreshRuntimeRegistry(force = false) {
    const now = Date.now();
    if (!force && now - this.registryLoadedAt < this.registryTtlMs) {
      return;
    }

    if (!(await this.tableExists('crm', 'api_endpoint_registry'))) {
      this.registryLoadedAt = now;
      this.registryCache.clear();
      this.registryFunctionCache.clear();
      return;
    }

    const result = await this.pool.query<{
      endpoint_key: string;
      dispatcher_fn: string | null;
      permission_slug: string | null;
      http_method: string | null;
      route_path: string | null;
      is_public: boolean;
      is_enabled: boolean;
    }>(
      `
        SELECT
          endpoint_key,
          dispatcher_fn,
          permission_slug,
          http_method,
          route_path,
          is_public,
          is_enabled
        FROM crm.api_endpoint_registry
        WHERE deleted_at IS NULL
      `,
    );

    const nextRegistry = new Map<string, RegistryEntry>();
    const nextFunctionCache = new Set<string>();

    for (const row of result.rows) {
      nextRegistry.set(row.endpoint_key, {
        endpointKey: row.endpoint_key,
        dispatcherFn: row.dispatcher_fn,
        permissionSlug: row.permission_slug,
        httpMethod: row.http_method,
        routePath: row.route_path,
        isPublic: row.is_public,
        isEnabled: row.is_enabled,
      });

      if (row.is_enabled && row.dispatcher_fn) {
        nextFunctionCache.add(row.dispatcher_fn);
      }
    }

    this.registryCache = nextRegistry;
    this.registryFunctionCache = nextFunctionCache;
    this.registryLoadedAt = now;
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params?: unknown[],
  ): Promise<QueryResult<T>> {
    return this.pool.query<T>(sql, params);
  }

  private async isAllowedFunction(fnName: string) {
    if (this.baseAllowedFunctions.has(fnName)) {
      return true;
    }

    await this.refreshRuntimeRegistry();

    if (this.registryFunctionCache.has(fnName)) {
      return true;
    }

    await this.refreshRuntimeRegistry(true);
    return this.registryFunctionCache.has(fnName);
  }

  private async tableExists(schema: string, table: string) {
    const result = await this.pool.query<{ exists: boolean }>(
      `
        SELECT EXISTS (
          SELECT 1
          FROM information_schema.tables
          WHERE table_schema = $1
            AND table_name = $2
        ) AS exists
      `,
      [schema, table],
    );

    return result.rows[0]?.exists ?? false;
  }

  private throwHttpException(res: any) {
    const { rid, statusCode, message, errors } = res;
    const errorPayload = { rid, message, errors };

    switch (statusCode) {
      case 400:
        throw new BadRequestException(errorPayload);
      case 401:
        throw new UnauthorizedException(errorPayload);
      case 403:
        throw new ForbiddenException(errorPayload);
      case 404:
        throw new NotFoundException(errorPayload);
      case 409:
        throw new ConflictException(errorPayload);
      default:
        throw new InternalServerErrorException(errorPayload);
    }
  }
}
