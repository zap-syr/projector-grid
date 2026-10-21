import type { ColumnId, Group, Projector } from '../api/types';
import { leadingNumber } from './cells';

type Key = string | number;

/** Zero-padded dotted quad, so a plain string compare orders IPs numerically. */
const ipKey = (ip: string) =>
  ip
    .split('.')
    .map((o) => String(Number.parseInt(o, 10) || 0).padStart(3, '0'))
    .join('.');

/** `-` and other non-numbers sort first ascending (`leadingNumber`'s -infinity). */
const num = (s: string) => leadingNumber(s) ?? Number.NEGATIVE_INFINITY;

/** Sort key per column, the app's `monitoringSortKey`. */
export function sortKey(
  column: ColumnId,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternText: (p: Projector) => string,
): Key {
  switch (column) {
    case 'projector':
      return ipKey(p.ip);
    case 'group':
      // Ungrouped sorts last ascending.
      return ((p.groupId && groups.get(p.groupId)?.name) || '￿').toLowerCase();
    case 'power':
      return { on: 0, turningOn: 1, cooling: 2, standby: 3 }[p.power];
    case 'shutter':
      return p.shutter === 'open' ? 0 : 1;
    case 'inputSignal':
      return p.input.toLowerCase();
    case 'temperature':
      return Math.max(num(p.intakeTemp), num(p.exhaustTemp));
    case 'runtimes':
      return num(p.runtime);
    case 'voltage':
      return num(p.acVoltage);
    case 'errors':
      // Faulted first ascending; not polled yet sorts with the healthy ones.
      return p.errors === '-' || p.errors === 'NO ERRORS' || p.errors === '' ? '1' : `0${p.errors}`;
    case 'connection':
      return { connected: 0, unprotected: 1, unauthorized: 2, offline: 3 }[p.connection];
    case 'testPattern':
      return patternText(p).toLowerCase();
  }
}

/** Ascending by IP, numerically per octet (10.0.0.9 before 10.0.0.10). */
export function sortByIp(projectors: readonly Projector[]): Projector[] {
  return projectors
    .map((p) => ({ p, k: ipKey(p.ip) }))
    .sort((a, b) => (a.k < b.k ? -1 : a.k > b.k ? 1 : 0))
    .map((e) => e.p);
}

/** Sorted by [column]; ties keep their IP order, so rows don't swap places between polls. */
export function sortProjectors(
  projectors: readonly Projector[],
  column: ColumnId,
  ascending: boolean,
  groups: ReadonlyMap<string, Group>,
  patternText: (p: Projector) => string,
): Projector[] {
  const keyed = projectors.map((p) => ({ p, k: sortKey(column, p, groups, patternText) }));
  keyed.sort((a, b) => {
    const cmp = a.k < b.k ? -1 : a.k > b.k ? 1 : 0;
    if (cmp !== 0) return ascending ? cmp : -cmp;
    const ia = ipKey(a.p.ip);
    const ib = ipKey(b.p.ip);
    return ia < ib ? -1 : ia > ib ? 1 : 0;
  });
  return keyed.map((e) => e.p);
}
