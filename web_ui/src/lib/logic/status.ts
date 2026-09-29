import type { Projector } from '../api/types';

export interface StatusSummary {
  total: number;
  online: number;
  offline: number;
  warnings: number;
}

/** Same counts as the app's status bar (`statusSummaryProvider`). */
export function statusSummary(projectors: readonly Projector[]): StatusSummary {
  let online = 0;
  let offline = 0;
  let warnings = 0;
  for (const p of projectors) {
    if (p.connection === 'connected' || p.connection === 'unprotected') online++;
    if (p.connection === 'offline') offline++;
    if (p.errors !== 'NO ERRORS' && p.errors !== '-') warnings++;
  }
  return { total: projectors.length, online, offline, warnings };
}
