import type { ColumnId, Group, Projector } from '../api/types';
import { leadingNumber } from './cells';

type Key = string | number;

const errorsOk = (errors: string) => errors === 'NO ERRORS' || errors === '';

/** Zero-padded dotted quad, so a plain string compare orders IPs numerically. */
const ipKey = (ip: string) =>
  ip
    .split('.')
    .map((o) => String(Number.parseInt(o, 10) || 0).padStart(3, '0'))
    .join('.');

/** `-` and other non-numbers sort first ascending, like `_leadingNum`'s -infinity. */
const num = (s: string) => leadingNumber(s) ?? Number.NEGATIVE_INFINITY;

/** Sort key per column — the app's `_Column.sortKey`. */
export function sortKey(
  column: ColumnId,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternText: (p: Projector) => string,
): Key {
  switch (column) {
    case 'connection':
      return { connected: 0, unprotected: 1, unauthorized: 2, offline: 3 }[p.connection];
    case 'model':
      return p.name.toLowerCase();
    case 'serial':
      return p.serial.toLowerCase();
    case 'group':
      // Ungrouped sorts last ascending.
      return ((p.groupId && groups.get(p.groupId)?.name) || '￿').toLowerCase();
    case 'ip':
      return ipKey(p.ip);
    case 'power':
      return { on: 0, turningOn: 1, cooling: 2, standby: 3 }[p.power];
    case 'shutter':
      return p.shutter === 'open' ? 0 : 1;
    case 'input':
      return p.input.toLowerCase();
    case 'signal':
      return p.signal.toLowerCase();
    case 'testPattern':
      return patternText(p).toLowerCase();
    case 'runtime':
      return num(p.runtime);
    case 'lightRuntime':
      return num(p.lightRuntime);
    case 'intake':
      return num(p.intakeTemp);
    case 'exhaust':
      return num(p.exhaustTemp);
    case 'voltage':
      return num(p.acVoltage);
    case 'errors':
      // Faulted rows first ascending; unpolled sorts with healthy.
      return p.errors === '-' ? '1-' : `${errorsOk(p.errors) ? 1 : 0}${p.errors}`;
  }
}

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
    return ascending ? cmp : -cmp;
  });
  return keyed.map((e) => e.p);
}
