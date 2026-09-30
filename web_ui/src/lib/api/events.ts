import type { Access, Alignment, Group, ProjectEvent, Projector, SnapshotEvent } from './types';

/** `/api/events` handlers, one per event in openapi.yaml, plus connection state. */
export interface EventHandlers {
  snapshot(data: SnapshotEvent): void;
  projectors(data: Projector[]): void;
  projector(data: Projector): void;
  groups(data: Group[]): void;
  project(data: ProjectEvent): void;
  alignment(data: Alignment): void;
  access(data: Access): void;
  signedOut(): void;
  /** The browser is retrying on its own (network blip, app restarting). */
  reconnecting(): void;
  /** The server refused the stream (session gone); no retries follow. */
  closed(): void;
}

/** Opens the event stream; returns a function that closes it. */
export function connectEvents(h: EventHandlers): () => void {
  const source = new EventSource('/api/events');
  const on = <T>(name: string, handler: (data: T) => void) =>
    source.addEventListener(name, (e) => handler(JSON.parse((e as MessageEvent<string>).data)));

  on<SnapshotEvent>('snapshot', h.snapshot);
  on<Projector[]>('projectors', h.projectors);
  on<Projector>('projector', h.projector);
  on<Group[]>('groups', h.groups);
  on<ProjectEvent>('project', h.project);
  on<Alignment>('alignment', h.alignment);
  on<Access>('access', h.access);
  source.addEventListener('signedOut', () => {
    source.close();
    h.signedOut();
  });
  source.onerror = () => {
    if (source.readyState === EventSource.CLOSED) h.closed();
    else h.reconnecting();
  };
  return () => source.close();
}
