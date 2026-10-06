import { describe, expect, test } from 'vitest';

import type { Alert, Projector } from '../src/lib/api/types';
import {
  alertBadge,
  alertPill,
  alertsInSections,
  alertTint,
  byProjectGroup,
  compareAlerts,
  countAlerts,
  formatDuration,
  formatStart,
  groupAlerts,
  groupPills,
  raisedAlerts,
  signalLost,
} from '../src/lib/logic/alerts';

const T0 = Date.parse('2026-10-06T14:00:00Z');

const al = (
  projectorId: string,
  rule: Alert['rule'],
  severity: Alert['severity'],
  minute: number,
  over: Partial<Alert> = {},
): Alert => ({
  id: `${projectorId}|${rule}|${over.item ?? ''}`,
  projectorId,
  projector: `PJ-${projectorId}`,
  ip: `10.0.0.${projectorId}`,
  rule,
  label: rule,
  item: '',
  severity,
  value: '',
  since: new Date(T0 + minute * 60_000).toISOString(),
  acknowledged: false,
  restoredAt: null,
  ...over,
});

const back = (a: Alert): Alert => ({ ...a, restoredAt: a.since });

describe('order and counts (alerts.dart)', () => {
  test('unacknowledged, problems before returned signals, critical, newest', () => {
    const list = [
      al('1', 'intake-temp', 'warning', 1),
      al('2', 'offline', 'critical', 9, { acknowledged: true }),
      back(al('3', 'signal-lost', 'critical', 8)),
      al('4', 'offline', 'critical', 2),
      al('5', 'offline', 'critical', 5),
    ];
    expect([...list].sort(compareAlerts).map((a) => a.projectorId)).toEqual([
      '5',
      '4',
      '1',
      '3',
      '2',
    ]);
  });

  test('counts unacknowledged and totals per severity, returned signals apart', () => {
    expect(
      countAlerts([
        al('1', 'offline', 'critical', 1),
        al('2', 'offline', 'critical', 1, { acknowledged: true }),
        al('3', 'intake-temp', 'warning', 1),
        back(al('4', 'signal-lost', 'critical', 1)),
      ]),
    ).toEqual({ critical: 1, warning: 1, criticalTotal: 2, warningTotal: 1, recovered: 1 });
  });
});

describe('alertBadge', () => {
  test('none without alerts', () => expect(alertBadge([])).toBeNull());

  test('colour follows the unacknowledged problems; count only what the icon stands for', () => {
    expect(
      alertBadge([
        al('1', 'offline', 'critical', 1, { acknowledged: true }),
        al('1', 'intake-temp', 'warning', 1),
      ]),
    ).toEqual({ severity: 'warning', acknowledged: false, recovered: false, count: 1 });
    expect(
      alertBadge([
        al('1', 'error', 'critical', 1, { item: 'F011' }),
        al('1', 'error', 'warning', 1),
      ]),
    ).toEqual({ severity: 'critical', acknowledged: false, recovered: false, count: 1 });
  });

  test('outlined once all acknowledged; a green check while only a returned signal waits', () => {
    expect(alertBadge([al('1', 'offline', 'critical', 1, { acknowledged: true })])).toMatchObject({
      acknowledged: true,
      recovered: false,
    });
    expect(alertBadge([back(al('1', 'signal-lost', 'critical', 1))])).toMatchObject({
      recovered: true,
      count: 1,
    });
  });
});

describe('grouping', () => {
  const list = [
    al('10', 'exhaust-temp', 'warning', 5),
    al('9', 'offline', 'critical', 1),
    al('100', 'offline', 'critical', 2),
  ];

  test('by projector: IP ascending, numerically', () => {
    expect(groupAlerts(list, 'projector').map((g) => g.key)).toEqual(['9', '10', '100']);
  });

  test('by alert: most urgent first, rows newest first', () => {
    const groups = groupAlerts(list, 'alert');
    expect(groups.map((g) => g.key)).toEqual(['offline', 'exhaust-temp']);
    expect(groups[0]?.alerts.map((a) => a.projectorId)).toEqual(['100', '9']);
  });

  const groupOf = (id: string) => ({ '9': 'stage', '10': 'gone', '100': 'balcony' })[id];

  test('sections follow the Manage Groups order, Ungrouped (and deleted groups) last', () => {
    const sections = alertsInSections(groupAlerts(list, 'projector'), groupOf, [
      'stage',
      'balcony',
      'truss',
    ]);
    expect(sections.map((s) => s.groupId)).toEqual(['stage', 'balcony', null]);
    expect(sections[2]?.items.map((g) => g.key)).toEqual(['10']);
  });

  test("a rule's rows split by project group, keeping their order", () => {
    const offline = groupAlerts(list, 'alert')[0]?.alerts ?? [];
    const subs = byProjectGroup(offline, (a) => a.projectorId, groupOf, ['stage', 'balcony']);
    expect(subs.map((s) => [s.groupId, s.items.map((a) => a.projectorId)])).toEqual([
      ['stage', ['9']],
      ['balcony', ['100']],
    ]);
  });
});

test('durations and start times, as the app writes them', () => {
  expect(formatDuration(30_000)).toBe('< 1 min');
  expect(formatDuration(-5_000)).toBe('< 1 min');
  expect(formatDuration(12 * 60_000)).toBe('12 min');
  expect(formatDuration(65 * 60_000)).toBe('1 h 05 min');
  const since = new Date(2026, 9, 6, 14, 2);
  expect(formatStart(since, new Date(2026, 9, 6, 18, 0))).toBe('14:02');
  expect(formatStart(since, new Date(2026, 9, 7, 9, 0))).toBe('Oct 6 14:02');
});

describe('raisedAlerts (the cues)', () => {
  const a = al('1', 'offline', 'critical', 1);

  test('new ones, ones back after acknowledge, a new dropout, an escalation', () => {
    expect(raisedAlerts([], [a])).toEqual([a]);
    expect(raisedAlerts([{ ...a, acknowledged: true }], [a])).toEqual([a]);
    const later = { ...a, since: new Date(T0 + 9 * 60_000).toISOString() };
    expect(raisedAlerts([a], [later])).toEqual([later]);
    const warm = al('1', 'intake-temp', 'warning', 1);
    const hot = { ...warm, severity: 'critical' as const };
    expect(raisedAlerts([warm], [hot])).toEqual([hot]);
  });

  test('not: unchanged, acknowledged, or a signal coming back', () => {
    expect(raisedAlerts([a], [a])).toEqual([]);
    expect(raisedAlerts([a], [{ ...a, acknowledged: true }])).toEqual([]);
    const lost = al('2', 'signal-lost', 'critical', 1);
    expect(raisedAlerts([lost], [back(lost)])).toEqual([]);
  });
});

describe('group header pills and the touch pill', () => {
  const pj = (id: string, connection: Projector['connection'] = 'connected') =>
    ({ id, connection }) as Projector;

  test('alerts by severity; auth errors only when nothing else is wrong', () => {
    const members = [pj('1'), pj('2', 'unauthorized')];
    expect(groupPills(members, [])).toEqual([
      { text: '1 auth error', tone: 'warn', kind: 'auth', count: 1 },
    ]);
    expect(
      groupPills(members, [
        al('1', 'offline', 'critical', 1),
        al('1', 'error', 'critical', 1, { item: 'F011' }),
        back(al('2', 'signal-lost', 'critical', 1)),
        al('9', 'offline', 'critical', 1),
      ]),
    ).toEqual([
      { text: '2 critical', tone: 'crit', kind: 'critical', count: 2 },
      { text: '1 recovered', tone: 'ok', kind: 'recovered', count: 1 },
    ]);
  });

  test('the pill', () => {
    expect(alertPill([])).toBeNull();
    expect(
      alertPill([al('1', 'offline', 'critical', 1), back(al('2', 'signal-lost', 'critical', 1))]),
    ).toEqual({ tone: 'critical', text: '1 new alert', extra: '1 signal back' });
    expect(alertPill([back(al('2', 'signal-lost', 'critical', 1))])).toEqual({
      tone: 'recovered',
      text: 'Signal back on 1 projector',
      extra: null,
    });
  });
});

test('cell tints come from the active alert', () => {
  const own = [al('1', 'intake-temp', 'warning', 1), al('1', 'exhaust-temp', 'critical', 1)];
  expect(alertTint(own, 'intake-temp')).toBe('warm');
  expect(alertTint(own, 'exhaust-temp')).toBe('hot');
  expect(alertTint([], 'intake-temp')).toBeNull();
  const lost = al('1', 'signal-lost', 'critical', 1);
  expect(signalLost([lost])).toBe(true);
  expect(signalLost([back(lost)])).toBe(false);
});
