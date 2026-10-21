import type { DataColumn, ErrorItem, Group, Projector } from '../api/types';
import {
  connectionLabel,
  groupLabel,
  noErrorsLabel,
  powerLabel,
  shutterLabel,
  withUnit,
} from './labels';

/** Plain cell text per column, as the app's Monitoring table shows it (`monitoringCellTexts`). */
export function cellText(
  column: DataColumn,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternLabel: (code: string) => string,
): string {
  switch (column) {
    case 'connection':
      return connectionLabel(p.connection);
    case 'model':
      return p.name;
    case 'serial':
      return p.serial;
    case 'group':
      return groupLabel(p.groupId ? groups.get(p.groupId) : undefined);
    case 'ip':
      return p.ip;
    case 'power':
      return powerLabel(p.power);
    case 'shutter':
      return shutterLabel(p.shutter);
    case 'input':
      return p.input;
    case 'signal':
      return p.signal;
    case 'testPattern':
      return p.testPattern === null ? '-' : patternLabel(p.testPattern);
    case 'runtime':
      return withUnit(p.runtime);
    case 'lightRuntime':
      return withUnit(p.lightRuntime);
    case 'intake':
      return withUnit(p.intakeTemp);
    case 'exhaust':
      return withUnit(p.exhaustTemp);
    case 'voltage':
      return withUnit(p.acVoltage);
    case 'errors': {
      const first = p.connection === 'offline' ? undefined : sortedErrors(p.errorItems)[0];
      return first ? errorBadge(first) : noErrorsLabel(p);
    }
  }
}

/** Critical codes first, as the app's problem list. */
export function sortedErrors(items: readonly ErrorItem[]): ErrorItem[] {
  return [...items].sort(
    (a, b) => (a.severity === 'critical' ? 0 : 1) - (b.severity === 'critical' ? 0 : 1),
  );
}

/** An amber code is the projector's warning, not a fault: `Error F305`, `Warning H001`. */
export function errorBadge(e: ErrorItem): string {
  return `${e.severity === 'critical' ? 'Error' : 'Warning'} ${e.code}`;
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
