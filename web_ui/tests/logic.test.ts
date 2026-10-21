import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { describe, expect, test } from 'vitest';

import type { Group, Projector } from '../src/lib/api/types';
import { cellText, leadingNumber, testPatternLabel } from '../src/lib/logic/cells';
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
  // n1 unprotected, n2 connected, n3 unauthorized, n4 offline.
  expect(statusSummary(projectors)).toEqual({ total: 4, online: 2, offline: 1 });
});

describe('cellText', () => {
  test('connection', () => {
    expect(text('connection', 'n1')).toBe('No login');
    expect(text('connection', 'n2')).toBe('Online');
    expect(text('connection', 'n3')).toBe('Wrong login');
    expect(text('connection', 'n4')).toBe('Offline');
  });

  test('power, shutter, group', () => {
    expect(text('power', 'n1')).toBe('Cooling');
    expect(text('power', 'n2')).toBe('On');
    expect(text('shutter', 'n2')).toBe('Open');
    expect(text('group', 'n2')).toBe('Stage');
    expect(text('group', 'n4')).toBe('None');
  });

  test('test pattern and errors', () => {
    expect(text('testPattern', 'n2')).toBe('Cross Hatch');
    expect(text('testPattern', 'n1')).toBe('Off');
    expect(text('testPattern', 'n3')).toBe('-');
    expect(text('errors', 'n2')).toBe('None');
    expect(text('errors', 'n1')).toBe('Error 000100000000');
    expect(text('errors', 'n4')).toBe('Unknown');
  });

  test('unknown pattern codes fall back to the raw code', () => {
    expect(testPatternLabel('OTS:52', labels)).toBe('Pattern 52');
  });
});

test('leadingNumber', () => {
  expect(leadingNumber('41°C')).toBe(41);
  expect(leadingNumber('1518H')).toBe(1518);
  expect(leadingNumber('-')).toBeNull();
  expect(leadingNumber('Timeout')).toBeNull();
});
