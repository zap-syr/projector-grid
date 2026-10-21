import { describe, expect, test } from 'vitest';

import type { ColumnId, Group, Projector } from '../src/lib/api/types';
import {
  renderedColumns,
  reorderColumn,
  resolveColumns,
  toggledColumn,
} from '../src/lib/logic/columns';
import { buildEntries, matchesFilter, matchesSearch, UNGROUPED } from '../src/lib/logic/rows';
import { sortByIp, sortProjectors } from '../src/lib/logic/sort';
import { autoFitWidth, layoutWidths, resizeBase } from '../src/lib/logic/widths';

const CATALOGUE: ColumnId[] = [
  'projector', 'group', 'power', 'shutter', 'inputSignal', 'temperature', 'runtimes', 'voltage',
  'errors', 'connection', 'testPattern',
]; // prettier-ignore
const DEFAULTS = CATALOGUE.filter((c) => c !== 'connection' && c !== 'testPattern');

const pj = (id: string, over: Partial<Projector> = {}): Projector => ({
  id,
  name: `PJ-${id}`,
  ip: `10.0.0.${id}`,
  groupId: null,
  x: 0,
  y: 0,
  connection: 'connected',
  power: 'on',
  shutter: 'open',
  serial: `SN${id}`,
  input: 'SDI1',
  signal: '1080/60p',
  testPattern: 'OTS:00',
  runtime: '100H',
  lightRuntime: '50H',
  intakeTemp: '30°C',
  exhaustTemp: '40°C',
  acVoltage: '230V',
  errors: 'NO ERRORS',
  errorItems: [],
  lastSeen: null,
  status: {
    level: 'none',
    online: true,
    standby: false,
    intake: null,
    exhaust: null,
    problems: [],
  },
  ...over,
});

describe('columns', () => {
  test('empty or unknown saved columns fall back to the defaults', () => {
    expect(resolveColumns([], CATALOGUE, DEFAULTS)).toEqual(DEFAULTS);
    expect(resolveColumns(['nope'], CATALOGUE, DEFAULTS)).toEqual(DEFAULTS);
    expect(resolveColumns(['power', 'nope', 'projector'], CATALOGUE, DEFAULTS)).toEqual([
      'power',
      'projector',
    ]);
  });

  test('hiding, and never the last column', () => {
    expect(toggledColumn(['projector', 'power'], 'power', CATALOGUE)).toEqual(['projector']);
    expect(toggledColumn(['power'], 'power', CATALOGUE)).toBeNull();
  });

  test('a re-shown column returns to its canonical slot', () => {
    expect(toggledColumn(['projector', 'power', 'errors'], 'group', CATALOGUE)).toEqual([
      'projector',
      'group',
      'power',
      'errors',
    ]);
    // Canonical slot is relative to what's visible, even after a reorder.
    expect(toggledColumn(['errors', 'projector'], 'power', CATALOGUE)).toEqual([
      'power',
      'errors',
      'projector',
    ]);
    expect(toggledColumn(['projector'], 'errors', CATALOGUE)).toEqual(['projector', 'errors']);
  });

  test('reorder: left→right lands after the target, right→left before it', () => {
    const cols: ColumnId[] = ['projector', 'group', 'power', 'shutter'];
    expect(reorderColumn(cols, 'projector', 'power')).toEqual([
      'group',
      'power',
      'projector',
      'shutter',
    ]);
    expect(reorderColumn(cols, 'shutter', 'group')).toEqual([
      'projector',
      'shutter',
      'group',
      'power',
    ]);
    expect(reorderColumn(cols, 'power', 'power')).toEqual(cols);
  });

  test('group-by hides Group, but never the only column', () => {
    expect(renderedColumns(['projector', 'group', 'power'], true)).toEqual(['projector', 'power']);
    expect(renderedColumns(['projector', 'group', 'power'], false)).toEqual([
      'projector',
      'group',
      'power',
    ]);
    expect(renderedColumns(['group'], true)).toEqual(['group']);
  });
});

describe('sort', () => {
  const groups = new Map<string, Group>([['g', { id: 'g', name: 'Stage', color: '#FFFFFF' }]]);
  const text = () => '-';
  const ids = (list: Projector[]) => list.map((p) => p.id);

  test('IPs sort numerically', () => {
    const list = [pj('1', { ip: '10.0.0.20' }), pj('2', { ip: '10.0.0.3' })];
    expect(ids(sortProjectors(list, 'projector', true, groups, text))).toEqual(['2', '1']);
    expect(ids(sortProjectors(list, 'projector', false, groups, text))).toEqual(['1', '2']);
    expect(ids(sortByIp(list))).toEqual(['2', '1']);
  });

  test('numbers from display strings; "-" first ascending', () => {
    const list = [
      pj('1', { runtime: '1,644H' }),
      pj('2', { runtime: '-' }),
      pj('3', { runtime: '900H' }),
    ];
    expect(ids(sortProjectors(list, 'runtimes', true, groups, text))).toEqual(['2', '3', '1']);
  });

  test('temperature sorts by the hotter reading; ties keep IP order', () => {
    const list = [
      pj('9', { intakeTemp: '30°C', exhaustTemp: '50°C' }),
      pj('1', { intakeTemp: '55°C', exhaustTemp: '40°C' }),
      pj('2', { intakeTemp: '30°C', exhaustTemp: '50°C' }),
    ];
    expect(ids(sortProjectors(list, 'temperature', true, groups, text))).toEqual(['2', '9', '1']);
    expect(ids(sortProjectors(list, 'temperature', false, groups, text))).toEqual(['1', '2', '9']);
  });

  test('status order: connection, power', () => {
    const list = [
      pj('1', { connection: 'offline', power: 'standby' }),
      pj('2', { connection: 'unprotected', power: 'cooling' }),
      pj('3'),
    ];
    expect(ids(sortProjectors(list, 'connection', true, groups, text))).toEqual(['3', '2', '1']);
    expect(ids(sortProjectors(list, 'power', true, groups, text))).toEqual(['3', '2', '1']);
  });

  test('errors first, unpolled with healthy; ungrouped last', () => {
    const list = [pj('1'), pj('2', { errors: '0001' }), pj('3', { errors: '-', groupId: 'g' })];
    expect(ids(sortProjectors(list, 'errors', true, groups, text))).toEqual(['2', '1', '3']);
    expect(ids(sortProjectors(list, 'group', true, groups, text))[0]).toBe('3');
  });
});

describe('widths', () => {
  test('fit-to-width scales up only when there is room', () => {
    expect(layoutWidths([100, 300], 800, true)).toEqual({
      widths: [200, 600],
      tableWidth: 800,
      scaling: true,
    });
    expect(layoutWidths([100, 300], 300, true)).toEqual({
      widths: [100, 300],
      tableWidth: 400,
      scaling: false,
    });
    expect(layoutWidths([100, 300], 800, false).tableWidth).toBe(400);
  });

  test('resize while scaling: the edge follows the pointer', () => {
    // Columns 100 + 300 in 800 px render at 200 + 600. Drag the first by +100 → 300 on screen.
    const start = { startWidth: 200, otherBase: 300, viewport: 800, scaling: true };
    const base = resizeBase(start, 100, 60);
    expect(base).toBeCloseTo(180);
    expect(layoutWidths([base, 300], 800, true).widths[0]).toBeCloseTo(300);
  });

  test('resize past the scaling limit and the clamps', () => {
    const start = { startWidth: 200, otherBase: 300, viewport: 800, scaling: true };
    expect(resizeBase(start, 350, 60)).toBe(550); // 550 ≥ 800 − 300 → base = on-screen
    expect(resizeBase(start, -500, 60)).toBe(60);
    expect(resizeBase({ ...start, scaling: false }, 900, 60)).toBe(600);
  });

  test('auto-fit takes the widest text plus padding', () => {
    expect(autoFitWidth(50, [80, 120], 32, 60)).toBe(158);
    expect(autoFitWidth(10, [], 0, 60)).toBe(60);
    expect(autoFitWidth(900, [], 32, 60)).toBe(600);
  });
});

describe('rows', () => {
  test('filters match the header counts', () => {
    const offline = pj('1', { connection: 'offline', errors: '-' });
    const faulty = pj('2', { connection: 'unprotected', errors: '0001' });
    const alerting = new Set(['2']);
    expect(matchesFilter(offline, 'offline', alerting)).toBe(true);
    expect(matchesFilter(offline, 'alerts', alerting)).toBe(false);
    expect(matchesFilter(faulty, 'online', alerting)).toBe(true);
    expect(matchesFilter(faulty, 'alerts', alerting)).toBe(true);
  });

  test('search by name, IP or serial', () => {
    const p = pj('7', { serial: 'SH4213007' });
    expect(matchesSearch(p, ' pj-7 ')).toBe(true);
    expect(matchesSearch(p, '10.0.0.7')).toBe(true);
    expect(matchesSearch(p, 'sh42')).toBe(true);
    expect(matchesSearch(p, 'balcony')).toBe(false);
  });

  const groups: Group[] = [
    { id: 'b', name: 'balcony', color: '#000000' },
    { id: 'a', name: 'Stage', color: '#000000' },
  ];
  const sorted = [
    pj('1', { groupId: 'a' }),
    pj('2'),
    pj('3', { groupId: 'b' }),
    pj('4', { groupId: 'gone' }),
    pj('5', { groupId: 'a' }),
  ];

  test('flat list: stripes alternate', () => {
    const e = buildEntries(sorted, groups, false);
    expect(e.map((x) => (x.kind === 'row' ? x.stripe : null))).toEqual([
      false,
      true,
      false,
      true,
      false,
    ]);
  });

  test('grouped: by name, ungrouped and orphaned last, stripes restart', () => {
    const e = buildEntries(sorted, groups, true);
    const flat = e.map((x) => (x.kind === 'group' ? `[${x.key}]` : x.projector.id));
    expect(flat).toEqual(['[b]', '3', '[a]', '1', '5', `[${UNGROUPED}]`, '2', '4']);
    const stageRows = e.filter((x) => x.kind === 'row' && x.projector.groupId === 'a');
    expect(stageRows.map((x) => x.kind === 'row' && x.stripe)).toEqual([false, true]);
  });

  test('collapsed groups keep their header only', () => {
    const e = buildEntries(sorted, groups, true, new Set(['a']));
    expect(e.some((x) => x.kind === 'row' && x.projector.groupId === 'a')).toBe(false);
    expect(e.some((x) => x.kind === 'group' && x.key === 'a')).toBe(true);
  });
});
