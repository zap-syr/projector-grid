import type { ColumnId, Group, Projector } from '../api/types';

/** Plain cell text per column, as the app's Monitoring table shows it (`_Column.text`). */
export function cellText(
  column: ColumnId,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternLabel: (code: string) => string,
): string {
  switch (column) {
    case 'connection':
      return {
        connected: 'Online',
        unprotected: 'Online',
        unauthorized: 'Auth Error',
        offline: 'Offline',
      }[p.connection];
    case 'model':
      return p.name;
    case 'serial':
      return p.serial;
    case 'group':
      return (p.groupId && groups.get(p.groupId)?.name) || '—';
    case 'ip':
      return p.ip;
    case 'power':
      return { on: 'ON', turningOn: 'TURNING ON', cooling: 'COOLING', standby: 'STANDBY' }[p.power];
    case 'shutter':
      return p.shutter === 'open' ? 'OPEN' : 'CLOSED';
    case 'input':
      return p.input;
    case 'signal':
      return p.signal;
    case 'testPattern':
      return p.testPattern === null ? '-' : patternLabel(p.testPattern);
    case 'runtime':
      return p.runtime;
    case 'lightRuntime':
      return p.lightRuntime;
    case 'intake':
      return p.intakeTemp;
    case 'exhaust':
      return p.exhaustTemp;
    case 'voltage':
      return p.acVoltage;
    case 'errors':
      if (p.errors === '-') return '-';
      return p.errors === 'NO ERRORS' || p.errors === '' ? 'NO ERRORS' : p.errors;
  }
}

/** Mirrors `testPatternLabel` in `domain/test_patterns.dart`. */
export function testPatternLabel(code: string, labels: ReadonlyMap<string, string>): string {
  return labels.get(code) ?? (code === 'OTS:00' ? 'Off' : code.replace('OTS:', 'Pattern '));
}

/** Leading number of a display string like "41°C" or "1518H"; null for '-', 'Timeout'. */
export function leadingNumber(s: string): number | null {
  const m = /-?\d+(\.\d+)?/.exec(s);
  return m ? Number(m[0]) : null;
}

export type Tint = 'warm' | 'hot' | null;

/** Temperature tint, same rule as the app's `_tempTint`. */
export function tempTint(display: string, t: { warm: number; hot: number }): Tint {
  const n = leadingNumber(display);
  if (n === null) return null;
  if (n >= t.hot) return 'hot';
  if (n >= t.warm) return 'warm';
  return null;
}
