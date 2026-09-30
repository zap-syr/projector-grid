import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, test } from 'vitest';

import type { Alignment, Config, Projector } from '../src/lib/api/types';
import Banner from '../src/lib/components/alignment/Banner.svelte';
import MapTile from '../src/lib/components/map/MapTile.svelte';
import { position, presetPatterns, roleOf, scopeOrder } from '../src/lib/logic/alignment';
import { live } from '../src/lib/state/live.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const config = fixture<Config>('config');
const projectors = fixture<Projector[]>('projectors');
// n2 focused, n1 shown, n4 closed; n3 is outside the mode.
const on = fixture<Alignment>('alignment');
const off = fixture<Alignment>('alignment-off');

describe('alignment logic', () => {
  test('the scope follows the projectors’ layout order', () => {
    expect(scopeOrder(projectors, on).map((p) => p.id)).toEqual(['n1', 'n2', 'n4']);
    expect(scopeOrder(projectors, off)).toEqual([]);
    expect(position(scopeOrder(projectors, on), on.focusedId)).toBe('2 / 3');
  });

  test('roles only while the mode is on', () => {
    expect(roleOf(on, 'n2')).toBe('focused');
    expect(roleOf(on, 'n3')).toBeNull();
    expect(roleOf(off, 'n2')).toBeNull();
    expect(roleOf(null, 'n2')).toBeNull();
  });

  test('pickers offer the preset’s patterns', () => {
    expect(presetPatterns(config, on)).toEqual([
      'OTS:07',
      'OTS:70',
      'OTS:71',
      'OTS:72',
      'OTS:73',
      'OTS:74',
      'OTS:75',
    ]);
    expect(presetPatterns(config, { ...on, preset: 'custom' })).toHaveLength(
      config.testPatterns.length,
    );
  });
});

describe('banner', () => {
  afterEach(() => {
    live.projectors = [];
    live.alignment = null;
  });

  test('the operator steps, toggles, picks and exits', () => {
    live.projectors = projectors;
    live.alignment = on;
    render(Banner, { config, operator: true });
    expect(screen.getByText('2 / 3')).toBeTruthy();
    // The ring on the card names the focused projector; the banner doesn't.
    expect(screen.queryByText('PJ-02')).toBeNull();
    expect(screen.getByRole('button', { name: 'Neighbours' }).getAttribute('aria-pressed')).toBe(
      'true',
    );
    expect(screen.getByRole('button', { name: 'Geometry' }).getAttribute('aria-pressed')).toBe(
      'true',
    );
    expect(screen.getByRole('button', { name: /Focused.*Cross Hatch$/ })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Exit' })).toBeTruthy();
  });

  test('a viewer gets one read-only line', () => {
    live.projectors = projectors;
    live.alignment = on;
    render(Banner, { config, operator: false });
    expect(screen.getByRole('region').textContent?.replace(/\s+/g, ' ')).toMatch(
      /Alignment in progress · PJ-02 focused · 2 of 3 · Geometry — controlled by an operator/,
    );
    expect(screen.queryByRole('button')).toBeNull();
  });

  test('entering or exiting shows the busy line', () => {
    live.alignment = { ...off, busy: true };
    render(Banner, { config, operator: true });
    expect(screen.getByText(/reading \/ restoring projectors/)).toBeTruthy();
  });
});

describe('map tile roles', () => {
  const tile = (over: object) =>
    render(MapTile, {
      p: projectors[1] as Projector,
      group: undefined,
      origin: { x: 0, y: 0 },
      patternLabel: (c: string) => c,
      operator: true,
      selected: true,
      dim: false,
      compact: false,
      ...over,
    });

  test('in the mode the ring replaces the selection border', () => {
    tile({ role: 'focused' });
    const card = screen.getByRole('button');
    expect(card.classList.contains('focused')).toBe(true);
    expect(card.classList.contains('sel')).toBe(false);
    expect(card.getAttribute('aria-pressed')).toBe('true');
  });

  test('outside the mode: dashed and not pressed', () => {
    tile({ outside: true });
    const card = screen.getByRole('button');
    expect(card.classList.contains('outside')).toBe(true);
    expect(card.getAttribute('aria-pressed')).toBe('false');
  });
});
