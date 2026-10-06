import type { Projector } from '../api/types';

export interface StatusSummary {
  total: number;
  online: number;
  offline: number;
}

/** Same counts as the app's status bar (`statusSummaryProvider`); alerts count apart. */
export function statusSummary(projectors: readonly Projector[]): StatusSummary {
  let online = 0;
  let offline = 0;
  for (const p of projectors) {
    if (p.connection === 'connected' || p.connection === 'unprotected') online++;
    if (p.connection === 'offline') offline++;
  }
  return { total: projectors.length, online, offline };
}
