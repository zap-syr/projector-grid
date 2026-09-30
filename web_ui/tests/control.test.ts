import { describe, expect, test } from 'vitest';

import type { Group, Projector } from '../src/lib/api/types';
import { act, confirmationFor } from '../src/lib/logic/actions';
import {
  isSelectable,
  presetSelection,
  selectedRange,
  toggledAll,
  triState,
} from '../src/lib/logic/selection';

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
  runtime: '-',
  lightRuntime: '-',
  intakeTemp: '-',
  exhaustTemp: '-',
  acVoltage: '-',
  errors: 'NO ERRORS',
  ...over,
});

const rows = [
  pj('1', { groupId: 'g' }),
  pj('2', { connection: 'offline' }),
  pj('3', { connection: 'unprotected', errors: '0001', groupId: 'g' }),
  pj('4', { connection: 'unauthorized' }),
  pj('5'),
];
const ids = (s: Set<string>) => [...s].sort();

describe('selection', () => {
  test('offline and auth-error projectors can’t be selected', () => {
    expect(rows.filter(isSelectable).map((p) => p.id)).toEqual(['1', '3', '5']);
  });

  test('tri-state counts only selectable rows', () => {
    expect(triState(rows, new Set())).toBe('none');
    expect(triState(rows, new Set(['1']))).toBe('some');
    expect(triState(rows, new Set(['1', '3', '5']))).toBe('all');
  });

  test('toggledAll selects every selectable row, or clears them when all are', () => {
    expect(ids(toggledAll(rows, new Set(['1'])))).toEqual(['1', '3', '5']);
    expect(ids(toggledAll(rows, new Set(['1', '3', '5', 'x'])))).toEqual(['x']);
  });

  test('shift-click range adds selectable rows between anchor and target', () => {
    expect(ids(selectedRange(rows, '5', '1', new Set()))).toEqual(['1', '3', '5']);
    expect(ids(selectedRange(rows, '1', '3', new Set(['5'])))).toEqual(['1', '3', '5']);
    // No anchor on screen: a plain toggle.
    expect(ids(selectedRange(rows, 'gone', '3', new Set(['3'])))).toEqual([]);
  });

  test('Select ▾ presets', () => {
    const group: Group = { id: 'g', name: 'Stage', color: '#000000' };
    expect(ids(presetSelection({ kind: 'all' }, rows, new Set()))).toEqual(['1', '3', '5']);
    expect(ids(presetSelection({ kind: 'warnings' }, rows, new Set()))).toEqual(['3']);
    expect(ids(presetSelection({ kind: 'invert' }, rows, new Set(['1'])))).toEqual(['3', '5']);
    expect(ids(presetSelection({ kind: 'group', group }, rows, new Set()))).toEqual(['1', '3']);
    expect(ids(presetSelection({ kind: 'clear' }, rows, new Set(['1'])))).toEqual([]);
  });
});

describe('confirmation rules', () => {
  const label = (c: string) => (c === 'OTS:07' ? 'Cross Hatch' : c);

  test('power and lens home always ask; power off is red', () => {
    expect(confirmationFor(act.power(true), 1, label)).toMatchObject({ danger: false });
    expect(confirmationFor(act.power(false), 1, label)).toMatchObject({
      question: 'Put 1 projector in standby?',
      danger: true,
    });
    expect(confirmationFor(act.lensHome(), 4, label)?.question).toBe(
      'Move the lens to its home position on 4 projectors?',
    );
  });

  test('shutter and test pattern ask only for more than one projector', () => {
    expect(confirmationFor(act.shutter(false), 1, label)).toBeNull();
    expect(confirmationFor(act.shutter(false), 2, label)).toMatchObject({
      question: 'Close the shutter on 2 projectors?',
      danger: true,
    });
    expect(confirmationFor(act.shutter(true), 2, label)).toMatchObject({ danger: false });
    expect(confirmationFor(act.testPattern('OTS:07'), 1, label)).toBeNull();
    expect(confirmationFor(act.testPattern('OTS:07'), 3, label)?.question).toBe(
      'Show Cross Hatch on 3 projectors?',
    );
  });

  test('input asks for several projectors; lens calibration / type always; OSD never', () => {
    expect(confirmationFor(act.input('IIS:SD1'), 1, label)).toBeNull();
    expect(confirmationFor(act.input('IIS:SD1'), 2, label)?.confirmLabel).toBe('Switch');
    expect(confirmationFor(act.lensCalibration('VXX:LNSI0=+00001'), 1, label)).not.toBeNull();
    expect(confirmationFor(act.lensType('VXX:LNEI1=+00001'), 1, label)).not.toBeNull();
    expect(confirmationFor(act.osd(false), 5, label)).toBeNull();
  });

  test('lens steps never ask', () => {
    expect(confirmationFor(act.lensStep('shiftH', true, 'fast'), 12, label)).toBeNull();
  });
});
