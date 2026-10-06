import { connectEvents } from '../api/events';
import type { Alignment, Group, Projector } from '../api/types';
import { alerts } from './alerts.svelte';
import { session } from './session.svelte';

type Connection = 'connecting' | 'live' | 'reconnecting';

/**
 * Projectors and groups as the app reports them. The SSE stream is the only
 * writer; components just read.
 */
class LiveState {
  projectors = $state<Projector[]>([]);
  groups = $state<Group[]>([]);
  /** The app's Alignment mode; null until the stream sends it. */
  alignment = $state<Alignment | null>(null);
  connection = $state<Connection>('connecting');
  #close: (() => void) | null = null;

  connect(): void {
    this.disconnect();
    this.connection = 'connecting';
    alerts.reset();
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
      alignment: (d) => (this.alignment = d),
      alerts: (d) => alerts.apply(d),
      access: (d) => session.applyAccess(d),
      signedOut: () => void session.ended(),
      reconnecting: () => {
        this.connection = 'reconnecting';
        // Alerts raised while the page was away shouldn't all go off at once.
        alerts.reset();
      },
      closed: () => void session.ended(),
    });
  }

  disconnect(): void {
    this.#close?.();
    this.#close = null;
  }
}

export const live = new LiveState();
