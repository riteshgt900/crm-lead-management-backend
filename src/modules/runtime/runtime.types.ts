export type RuntimeUser = {
  id?: string;
  role?: string;
  roleName?: string;
  permissions?: string[];
};

export type RuntimeEntitySpec = {
  key: string;
  label: string;
  table?: string;
  permissionSlug: string;
  formKey: string;
  routeBase: string;
  fields: string[];
  filters: string[];
  sampleCreatePayload: Record<string, unknown>;
  sampleUpdatePayload: Record<string, unknown>;
  sampleListPayload: Record<string, unknown>;
  sampleActionPayload?: Record<string, unknown>;
  lookups?: string[];
};

export type RuntimeEndpointSpec = {
  endpointKey: string;
  method: 'GET' | 'POST';
  route: string;
  permissionSlug: string;
  auth: 'public' | 'session';
  dispatcherFn: string;
  entityKey?: string;
  actionKey?: string;
  requestShape: string;
  responseShape: string;
  samplePayload?: Record<string, unknown>;
};

