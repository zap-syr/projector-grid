import type { ColumnId, ErrorItem, Group, Projector } from '../api/types';
import { formatStart } from './alerts';
import {
  connectionLabel,
  groupLabel,
  noErrorsLabel,
  powerLabel,
  shutterLabel,
  withUnit,
} from './labels';
import { signalState } from './signal';

/** *RQ25K, last seen 16:41* under an offline projector's IP (`lastSeenLabel`). */
export function modelLine(p: Projector, now: Date): string {
  return p.lastSeen && p.connection === 'offline'
    ? `${p.name}, last seen ${formatStart(new Date(p.lastSeen), now)}`
    : p.name;
}

/**
 * A cell's plain text, line by line, as the app's Monitoring table shows it
 * (`monitoringCellTexts`): what auto-fit measures and a field's title.
 */
export function cellLines(
  column: ColumnId,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternLabel: (code: string) => string,
  now: Date = new Date(),
): string[] {
  switch (column) {
    case 'projector':
      return [p.ip, modelLine(p, now)];
    case 'group':
      return [groupLabel(p.groupId ? groups.get(p.groupId) : undefined)];
    case 'power':
      return [powerLabel(p.power)];
    case 'shutter':
      return [shutterLabel(p.shutter)];
    case 'inputSignal':
      return [p.input, signalState(p).label];
    case 'temperature':
      return [`In ${withUnit(p.intakeTemp)}`, `Ex ${withUnit(p.exhaustTemp)}`];
    case 'runtimes':
      return [withUnit(p.runtime), `Light ${withUnit(p.lightRuntime)}`];
    case 'voltage':
      return [withUnit(p.acVoltage)];
    case 'errors': {
      const first = p.connection === 'offline' ? undefined : sortedErrors(p.errorItems)[0];
      return [first ? errorBadge(first) : noErrorsLabel(p)];
    }
    case 'connection':
      return [connectionLabel(p.connection)];
    case 'testPattern':
      return [p.testPattern === null ? '-' : patternLabel(p.testPattern)];
  }
}

/** [cellLines] in one line, for a title. */
export function cellText(
  column: ColumnId,
  p: Projector,
  groups: ReadonlyMap<string, Group>,
  patternLabel: (code: string) => string,
): string {
  return cellLines(column, p, groups, patternLabel).join(', ');
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

/**
 * The leading number of a display value (`1,644H`, `41°C`), thousands
 * separators ignored; null for '-', 'Timeout' (`leadingNumber` in
 * `monitoring_layout.dart`).
 */
export function leadingNumber(s: string): number | null {
  const m = /-?\d+(\.\d+)?/.exec(s.replace(/,/g, ''));
  return m ? Number(m[0]) : null;
}
