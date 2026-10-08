import type {
  AcknowledgeRequest,
  AcknowledgeResult,
  Access,
  ActionRequest,
  Alignment,
  AlignmentOp,
  ApiErrorBody,
  Config,
  DispatchResult,
  Group,
  LoginResponse,
  PreShowRequest,
  Projector,
  RefreshResult,
  Session,
} from './types';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: ApiErrorBody | null,
  ) {
    super(body?.error ?? `HTTP ${status}`);
  }
}

async function request<T>(method: 'GET' | 'POST', path: string, body?: unknown): Promise<T> {
  const res = await fetch(path, {
    method,
    credentials: 'same-origin',
    headers: body === undefined ? undefined : { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    const errorBody = (await res.json().catch(() => null)) as ApiErrorBody | null;
    throw new ApiError(res.status, errorBody);
  }
  return (res.status === 204 ? undefined : await res.json()) as T;
}

/** Every call the page makes; components never `fetch` directly. */
export const api = {
  session: () => request<Session>('GET', '/api/session'),
  login: (pin: string) => request<LoginResponse>('POST', '/api/login', { pin }),
  logout: () => request<undefined>('POST', '/api/logout'),
  unlock: (pin: string) => request<Access>('POST', '/api/unlock', { pin }),
  lock: () => request<Access>('POST', '/api/lock'),
  act: (req: ActionRequest) => request<DispatchResult>('POST', '/api/actions', req),
  refresh: () => request<RefreshResult>('POST', '/api/refresh'),
  config: () => request<Config>('GET', '/api/config'),
  projectors: () => request<Projector[]>('GET', '/api/projectors'),
  groups: () => request<Group[]>('GET', '/api/groups'),
  alignment: (op: AlignmentOp, body?: Record<string, unknown>) =>
    request<Alignment>('POST', `/api/alignment/${op}`, body),
  previewRetry: (id: string) =>
    request<undefined>('POST', `/api/preview/${encodeURIComponent(id)}/retry`),
  acknowledge: (req: AcknowledgeRequest) =>
    request<AcknowledgeResult>('POST', '/api/alerts/acknowledge', req),
  previewPreShow: (id: string, on: boolean) =>
    request<PreShowRequest>('POST', `/api/preview/${encodeURIComponent(id)}/preshow`, { on }),
};
