import { BadRequestException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ENDPOINT_SPECS, ENTITY_SPECS } from './runtime.constants';
import { RuntimeEntitySpec, RuntimeEndpointSpec, RuntimeUser } from './runtime.types';

@Injectable()
export class RuntimeService {
  constructor(private readonly db: DatabaseService) {}

  async bootstrap(user: RuntimeUser) {
    const registry = await this.getRegistrySnapshot();

    return this.envelope('s-meta-bootstrap', {
      app: {
        name: 'CRM Runtime',
        version: '1.0',
        noRedeployContract: true,
      },
      user: this.sanitizeUser(user),
      entities: ENTITY_SPECS.map((entity) => this.decorateEntity(entity, registry)),
      endpoints: ENDPOINT_SPECS.map((endpoint) => this.decorateEndpoint(endpoint, registry)),
      registry: Array.from(registry.values()),
      counts: {
        entities: ENTITY_SPECS.length,
        endpoints: ENDPOINT_SPECS.length,
        registeredEndpoints: registry.size,
      },
    });
  }

  async listEntities() {
    const registry = await this.getRegistrySnapshot();
    return this.envelope(
      's-meta-entities-listed',
      ENTITY_SPECS.map((entity) => this.decorateEntity(entity, registry)),
    );
  }

  async getEntity(entityKey: string) {
    const entity = this.findEntity(entityKey);
    if (!entity) {
      throw new BadRequestException({
        rid: 'e-unknown-entity',
        message: `Unknown entity key: ${entityKey}`,
      });
    }

    const registry = await this.getRegistrySnapshot();
    return this.envelope('s-meta-entity-loaded', this.decorateEntity(entity, registry));
  }

  async listRecords(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'list', body, user, 'fn_data_operations');
  }

  async getRecord(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'get', body, user, 'fn_data_operations');
  }

  async createRecord(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'create', body, user, 'fn_data_operations');
  }

  async updateRecord(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'update', body, user, 'fn_data_operations');
  }

  async deleteRecord(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'delete', body, user, 'fn_data_operations');
  }

  async bulkRecord(entityKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    return this.dispatchEntityOperation(entityKey, 'bulk', body, user, 'fn_data_operations');
  }

  async executeAction(actionKey: string, body: Record<string, unknown>, user: RuntimeUser) {
    const payload = {
      actionKey,
      data: body ?? {},
      requestedBy: user.id,
      role: this.roleName(user),
      permissions: user.permissions ?? [],
    };

    return this.dispatchByRegistryOrFunction(`action.${actionKey}`, 'fn_action_operations', payload);
  }

  async frontendContract() {
    const registry = await this.getRegistrySnapshot();

    return this.envelope('s-frontend-contract', {
      generatedAt: new Date().toISOString(),
      auth: {
        strategy: 'cookie',
        cookieName: 'crm_session',
        withCredentials: true,
      },
      endpoints: ENDPOINT_SPECS.map((endpoint) => this.decorateEndpoint(endpoint, registry)),
      entities: ENTITY_SPECS.map((entity) => this.decorateEntity(entity, registry)),
      lookups: this.buildLookups(),
      samples: this.buildSamples(),
      permissions: Array.from(
        new Set([
          ...ENTITY_SPECS.map((entity) => entity.permissionSlug),
          ...ENDPOINT_SPECS.map((endpoint) => endpoint.permissionSlug),
        ]),
      ).sort(),
    });
  }

  private async dispatchEntityOperation(
    entityKey: string,
    operation: 'list' | 'get' | 'create' | 'update' | 'delete' | 'bulk',
    body: Record<string, unknown>,
    user: RuntimeUser,
    fallbackFn: string,
  ) {
    const entity = this.findEntity(entityKey);
    if (!entity) {
      throw new BadRequestException({
        rid: 'e-unknown-entity',
        message: `Unknown entity key: ${entityKey}`,
      });
    }

    const payload = {
      entityKey,
      entityTable: entity.table,
      operation,
      data: body ?? {},
      requestedBy: user.id,
      role: this.roleName(user),
      permissions: user.permissions ?? [],
    };

    return this.dispatchByRegistryOrFunction(`data.${entityKey}.${operation}`, fallbackFn, payload);
  }

  private async dispatchByRegistryOrFunction(endpointKey: string, fallbackFn: string, payload: Record<string, unknown>) {
    const registry = await this.getRegistrySnapshot();
    const entry = registry.get(endpointKey);

    if (entry?.isEnabled && entry.dispatcherFn) {
      return this.db.callDispatcher(entry.dispatcherFn, payload);
    }

    return this.db.callDispatcher(fallbackFn, payload);
  }

  private async getRegistrySnapshot() {
    const registry = await this.db.getRuntimeRegistry();
    return registry;
  }

  private findEntity(entityKey: string) {
    return ENTITY_SPECS.find((entity) => entity.key === entityKey) ?? null;
  }

  private decorateEntity(entity: RuntimeEntitySpec, registry: Map<string, any>) {
    const endpointPrefix = `data.${entity.key}`;

    return {
      ...entity,
      operations: this.buildEntityOperations(entity, registry),
      registry: {
        endpointKey: endpointPrefix,
        source: registry.get(endpointPrefix) ?? null,
      },
    };
  }

  private buildEntityOperations(entity: RuntimeEntitySpec, registry: Map<string, any>) {
    const operations: Array<Record<string, unknown>> = [];

    const operationSpecs: Array<{
      operation: 'list' | 'get' | 'create' | 'update' | 'delete' | 'bulk';
      method: 'GET' | 'POST';
      routeSuffix: string;
      permissionSlug: string;
      requestShape: string;
      responseShape: string;
      samplePayload: Record<string, unknown>;
    }> = [
      {
        operation: 'list',
        method: 'POST',
        routeSuffix: 'list',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:view`,
        requestShape: '{ filters, query, page, limit }',
        responseShape: '{ rid, statusCode, data[], meta }',
        samplePayload: entity.sampleListPayload,
      },
      {
        operation: 'get',
        method: 'POST',
        routeSuffix: 'get',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:view`,
        requestShape: '{ id }',
        responseShape: '{ rid, statusCode, data }',
        samplePayload: { id: 'uuid' },
      },
      {
        operation: 'create',
        method: 'POST',
        routeSuffix: 'create',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:create`,
        requestShape: '{ ...entityFields }',
        responseShape: '{ rid, statusCode, data }',
        samplePayload: entity.sampleCreatePayload,
      },
      {
        operation: 'update',
        method: 'POST',
        routeSuffix: 'update',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:update`,
        requestShape: '{ id, ...entityFields }',
        responseShape: '{ rid, statusCode, data }',
        samplePayload: entity.sampleUpdatePayload,
      },
      {
        operation: 'delete',
        method: 'POST',
        routeSuffix: 'delete',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:delete`,
        requestShape: '{ id }',
        responseShape: '{ rid, statusCode, data }',
        samplePayload: { id: 'uuid' },
      },
      {
        operation: 'bulk',
        method: 'POST',
        routeSuffix: 'bulk',
        permissionSlug: `${entity.permissionSlug.split(':')[0]}:bulk`,
        requestShape: '{ ids[], action, payload }',
        responseShape: '{ rid, statusCode, data }',
        samplePayload: { ids: ['uuid-1', 'uuid-2'], action: 'archive' },
      },
    ];

    for (const spec of operationSpecs) {
      const endpointKey = `data.${entity.key}.${spec.operation}`;
      const registryEntry = registry.get(endpointKey) ?? null;

      operations.push({
        endpointKey,
        method: spec.method,
        route: `/api/data/${entity.key}/${spec.routeSuffix}`,
        permissionSlug: spec.permissionSlug,
        requestShape: spec.requestShape,
        responseShape: spec.responseShape,
        samplePayload: spec.samplePayload,
        registry: registryEntry,
      });
    }

    return operations;
  }

  private decorateEndpoint(endpoint: RuntimeEndpointSpec, registry: Map<string, any>) {
    return {
      ...endpoint,
      registry: registry.get(endpoint.endpointKey) ?? null,
    };
  }

  private buildLookups() {
    return {
      lead_source: ['website', 'referral', 'social_media', 'cold_call', 'email_campaign', 'event', 'partner', 'other'],
      contact_category: ['individual', 'architect', 'pmc', 'vendor'],
      project_status: ['planning', 'active', 'on_hold', 'completed', 'cancelled', 'archived'],
      task_status: ['todo', 'in_progress', 'under_review', 'completed', 'cancelled', 'blocked'],
      task_priority: ['low', 'medium', 'high', 'critical'],
      document_status: ['draft', 'pending_approval', 'approved', 'rejected', 'archived'],
    };
  }

  private buildSamples() {
    return ENTITY_SPECS.reduce<Record<string, unknown>>((acc, entity) => {
      acc[entity.key] = {
        create: entity.sampleCreatePayload,
        update: entity.sampleUpdatePayload,
        list: entity.sampleListPayload,
        action: entity.sampleActionPayload ?? null,
      };
      return acc;
    }, {});
  }

  private envelope(rid: string, data: unknown) {
    return {
      rid,
      statusCode: 200,
      data,
      message: 'Operation successful',
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  }

  private sanitizeUser(user: RuntimeUser) {
    if (!user) {
      return null;
    }

    return {
      id: user.id ?? null,
      role: this.roleName(user),
      permissions: user.permissions ?? [],
    };
  }

  private roleName(user: RuntimeUser) {
    return user.role ?? user.roleName ?? 'guest';
  }
}
