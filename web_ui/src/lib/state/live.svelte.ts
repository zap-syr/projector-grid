import { connectEvents } from '../api/events';
import type { Group, Projector } from '../api/types';
import { session } from './session.svelte';

type Connection = 'connecting' | 'live' | 'reconnecting';

/**
 * Projectors and groups as the app reports them. The SSE stream is the only
 * writer; components just read.
 */
class LiveState {
  projectors = $state<Projector[]>([]);
  groups = $state<Group[]>([]);
  connection = $state<Connection>('connecting');
  #close: (() => void) | null = null;

  connect(): void {
    this.disconnect();
    this.connection = 'connecting';
    this.#close = connectEvents({
      snapshot: (d) => {
        this.projectors = d.projectors;
        this.groups = d.groups;
        session.projectName = d.projectName;
        this.connection = 'live';
      },
      projectors: (d) => (this.projectors = d),
      projector: (d) => {
        const i = this.projectors.findIndex((p) => p.id === d.id);
        if (i >= 0) this.projectors[i] = d;
      },
      groups: (d) => (this.groups = d),
      project: (d) => (session.projectName = d.name),
      signedOut: () => void session.ended(),
      reconnecting: () => (this.connection = 'reconnecting'),
      closed: () => void session.ended(),
    });
  }

  disconnect(): void {
    this.#close?.();
    this.#close = null;
  }
}

export const live = new LiveState();
