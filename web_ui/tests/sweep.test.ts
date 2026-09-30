import { expect, test } from 'vitest';

import type { Projector } from '../src/lib/api/types';
import { draggedSelection } from '../src/lib/logic/selection';

const pj = (id: string, connection: Projector['connection'] = 'connected') =>
  ({ id, connection }) as Projector;
const order = [pj('1'), pj('2'), pj('3', 'offline'), pj('4'), pj('5')];
const ids = (s: Set<string>) => [...s].sort();

test('sweeping from an unselected row selects everything passed, skipping offline', () => {
  expect(ids(draggedSelection(order, new Set(['5']), '1', '4'))).toEqual(['1', '2', '4', '5']);
  // Upwards works the same.
  expect(ids(draggedSelection(order, new Set(), '4', '2'))).toEqual(['2', '4']);
});

test('sweeping from a selected row deselects instead', () => {
  expect(ids(draggedSelection(order, new Set(['1', '2', '4', '5']), '2', '4'))).toEqual(['1', '5']);
});

test('each move recomputes from the selection at the press, so moving back shrinks it', () => {
  const base = new Set<string>();
  expect(ids(draggedSelection(order, base, '1', '5'))).toEqual(['1', '2', '4', '5']);
  expect(ids(draggedSelection(order, base, '1', '2'))).toEqual(['1', '2']);
});
