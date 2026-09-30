import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { render, screen } from '@testing-library/svelte';
import type { ComponentProps } from 'svelte';
import { describe, expect, test } from 'vitest';

import type { Group, Projector } from '../src/lib/api/types';
import MapTile from '../src/lib/components/map/MapTile.svelte';
import {
  CARD_H,
  CARD_W,
  CHIP_H,
  chipText,
  clampZoom,
  fitZoom,
  mapBounds,
  marqueeSelection,
  PAD,
  rectFrom,
  scrollFor,
  stageOffset,
  tileSelection,
} from '../src/lib/logic/map';
import { mapAllowed, type Screen } from '../src/lib/state/device.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const projectors = fixture<Projector[]>('projectors');
const groups = fixture<Group[]>('groups');
const byId = (id: string) => projectors.find((p) => p.id === id) as Projector;
// n1 (20,40) n2 (160,40) n3 (20,180) n4 (160,180); n4 is offline.
const at = (id: string, x: number, y: number): Projector => ({ ...byId(id), x, y });

describe('map geometry', () => {
  test('bounds cover every card and its group chip, padded', () => {
    expect(mapBounds(projectors)).toEqual({
      x: 20 - PAD,
      y: 40 - PAD,
      w: 160 + CARD_W - 20 + 2 * PAD,
      h: 180 + CARD_H + CHIP_H - 40 + 2 * PAD,
    });
    expect(mapBounds([])).toEqual({ x: 0, y: 0, w: 0, h: 0 });
  });

  test('fit is the tighter axis, capped at the app’s 2×', () => {
    const b = { x: 0, y: 0, w: 400, h: 200 };
    expect(fitZoom(b, 800, 200)).toBe(1);
    expect(fitZoom(b, 200, 400)).toBe(0.5);
    expect(fitZoom(b, 4000, 4000)).toBe(2);
  });

  test('zoom stays within the app’s 0.5–2, or down to a smaller fit', () => {
    expect(clampZoom(0.3, 1)).toBe(0.5);
    expect(clampZoom(0.3, 0.2)).toBe(0.3);
    expect(clampZoom(0.1, 0.2)).toBe(0.2);
    expect(clampZoom(3, 1)).toBe(2);
  });

  test('zooming keeps the anchored canvas point under the pointer', () => {
    // Wall 1000 px wide from x = 100, view 500 px; point x = 600 under view x = 250.
    const scroll = scrollFor(600, 250, 2, 100, 500, 1000);
    expect(scroll + 250).toBe((600 - 100) * 2);
    // A wall narrower than the view is centred by its margins.
    expect(stageOffset(500, 1000 * 0.4)).toBe(50);
  });
});

describe('map selection', () => {
  const shown = [at('n1', 0, 0), at('n2', 140, 0), at('n3', 0, 140), at('n4', 140, 140)];
  // Covers the right column: n2, and n4, which is offline.
  const right = rectFrom(300, -10, 130, 400);

  test('a plain marquee replaces the selection, skipping the unselectable', () => {
    expect([...marqueeSelection(right, shown, new Set(['n1']), 'replace')]).toEqual(['n2']);
  });

  test('with a modifier it toggles against the selection it started from', () => {
    const r = rectFrom(-10, -10, 300, 60); // n1 and n2
    expect([...marqueeSelection(r, shown, new Set(['n1', 'n3']), 'toggle')].sort()).toEqual([
      'n2',
      'n3',
    ]);
  });

  test('on touch it only adds', () => {
    const r = rectFrom(-10, -10, 300, 60);
    expect([...marqueeSelection(r, shown, new Set(['n1', 'n3']), 'add')].sort()).toEqual([
      'n1',
      'n2',
      'n3',
    ]);
  });

  test('touching edges don’t count, like Flutter’s Rect.overlaps', () => {
    expect(marqueeSelection(rectFrom(120, 0, 140, 50), shown, new Set(), 'replace').size).toBe(0);
  });

  test('tiles the filter dims stay out of a marquee', () => {
    expect(marqueeSelection(right, [shown[0] as Projector], new Set(), 'replace').size).toBe(0);
  });

  test('a plain click selects only that tile; a toggle click adds or removes', () => {
    const n2 = byId('n2');
    expect([...tileSelection(n2, new Set(['n1']), false)]).toEqual(['n2']);
    expect([...tileSelection(n2, new Set(['n1']), true)]).toEqual(['n1', 'n2']);
    expect([...tileSelection(n2, new Set(['n1', 'n2']), true)]).toEqual(['n1']);
    expect([...tileSelection(byId('n4'), new Set(['n1']), false)]).toEqual(['n1']);
  });
});

describe('map tile', () => {
  const show = (over: Partial<ComponentProps<typeof MapTile>> = {}) =>
    render(MapTile, {
      p: byId('n2'),
      group: groups[0],
      origin: { x: 0, y: 0 },
      patternLabel: () => 'Cross Hatch',
      operator: true,
      selected: false,
      dim: false,
      compact: false,
      ...over,
    });

  test('shows the name, IP, test pattern and group chip, like the app card', () => {
    show({ p: { ...byId('n2'), testPattern: 'OTS:07', shutter: 'closed' } });
    expect(screen.getByText(byId('n2').ip)).toBeTruthy();
    expect(screen.getByRole('img', { name: 'Test pattern: Cross Hatch' })).toBeTruthy();
    expect(screen.getByText('Stage')).toBeTruthy();
    expect(screen.getByRole('button', { name: byId('n2').name, pressed: false })).toBeTruthy();
  });

  test('compact keeps only the dot and name', () => {
    show({ compact: true, p: { ...byId('n2'), testPattern: 'OTS:07' } });
    expect(screen.queryByText(byId('n2').ip)).toBeNull();
    expect(screen.queryByRole('img')).toBeNull();
  });

  test('group chip text reads on its colour', () => {
    expect(chipText('#FFEB3B')).toBe('#15171b');
    expect(chipText('#9334E6')).toBe('#fff');
  });
});

test('the Map is offered on tablets and desktops, not on phones', () => {
  const on = (over: Partial<Screen>): Screen => ({
    phone: false,
    short: false,
    touch: false,
    wide: false,
    ...over,
  });
  expect(mapAllowed(on({ phone: true, touch: true }))).toBe(false);
  expect(mapAllowed(on({ short: true, touch: true }))).toBe(false);
  expect(mapAllowed(on({ touch: true }))).toBe(true);
  expect(mapAllowed(on({ touch: true, wide: true }))).toBe(true);
  expect(mapAllowed(on({}))).toBe(true);
});
