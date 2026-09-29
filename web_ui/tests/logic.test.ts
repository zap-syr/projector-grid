import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { describe, expect, test } from 'vitest';

import type { Group, Projector } from '../src/lib/api/types';
import { cellText, leadingNumber, tempTint, testPatternLabel } from '../src/lib/logic/cells';
import { statusSummary } from '../src/lib/logic/status';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const projectors = fixture<Projector[]>('projectors');
const groups = new Map(fixture<Group[]>('groups').map((g) => [g.id, g]));
const byId = (id: string) => projectors.find((p) => p.id === id) as Projector;
const labels = new Map([['OTS:07', 'Cross Hatch']]);
const text = (col: Parameters<typeof cellText>[0], id: string) =>
  cellText(col, byId(id), groups, (c) => testPatternLabel(c, labels));

test('statusSummary counts like the app status bar', () => {
  // n1 unprotected + errors, n2 connected, n3 unauthorized, n4 offline.
  expect(statusSummary(projectors)).toEqual({ total: 4, online: 2, offline: 1, warnings: 1 });
});

describe('cellText', () => {
  test('connection', () => {
    expect(text('connection', 'n1')).toBe('Online');
    expect(text('connection', 'n3')).toBe('Auth Error');
    expect(text('connection', 'n4')).toBe('Offline');
  });

  test('power, shutter, group', () => {
    expect(text('power', 'n1')).toBe('COOLING');
    expect(text('power', 'n2')).toBe('ON');
    expect(text('shutter', 'n2')).toBe('OPEN');
    expect(text('group', 'n2')).toBe('Stage');
    expect(text('group', 'n4')).toBe('—');
  });

  test('test pattern and errors', () => {
    expect(text('testPattern', 'n2')).toBe('Cross Hatch');
    expect(text('testPattern', 'n1')).toBe('Off');
    expect(text('testPattern', 'n3')).toBe('-');
    expect(text('errors', 'n2')).toBe('NO ERRORS');
    expect(text('errors', 'n1')).toBe('000100000000');
    expect(text('errors', 'n4')).toBe('-');
  });

  test('unknown pattern codes fall back to the raw code', () => {
    expect(testPatternLabel('OTS:52', labels)).toBe('Pattern 52');
  });
});

describe('temperature tint', () => {
  const intake = { warm: 40, hot: 45 };

  test('leadingNumber', () => {
    expect(leadingNumber('41°C')).toBe(41);
    expect(leadingNumber('1518H')).toBe(1518);
    expect(leadingNumber('-')).toBeNull();
    expect(leadingNumber('Timeout')).toBeNull();
  });

  test('thresholds are inclusive', () => {
    expect(tempTint('39°C', intake)).toBeNull();
    expect(tempTint('40°C', intake)).toBe('warm');
    expect(tempTint('45°C', intake)).toBe('hot');
    expect(tempTint('-', intake)).toBeNull();
  });
});
