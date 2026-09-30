import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { describe, expect, test, vi } from 'vitest';

import type { Config, Group, Projector } from '../src/lib/api/types';
import CardDetails from '../src/lib/components/phone/CardDetails.svelte';
import ProjectorCard from '../src/lib/components/phone/ProjectorCard.svelte';
import { type Entry, withDetails } from '../src/lib/logic/rows';
import { cardsOnly, controlPlacement, type Screen } from '../src/lib/state/device.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const config = fixture<Config>('config');
const projectors = fixture<Projector[]>('projectors');
const groups = new Map(fixture<Group[]>('groups').map((g) => [g.id, g]));
const byId = (id: string) => projectors.find((p) => p.id === id) as Projector;

function card(id: string, operator: boolean, expanded = false) {
  const onselect = vi.fn();
  const onexpand = vi.fn();
  render(ProjectorCard, {
    p: byId(id),
    config,
    groups,
    patternLabel: (c: string) => c,
    operator,
    selected: false,
    expanded,
    onselect,
    onexpand,
  });
  return { onselect, onexpand };
}

describe('layout per screen', () => {
  const on = (over: Partial<Screen>): Screen => ({
    phone: false,
    short: false,
    touch: false,
    wide: false,
    ...over,
  });
  const cases: [string, Partial<Screen>, boolean, string][] = [
    ['phone upright', { phone: true, touch: true }, true, 'bottom'],
    ['phone sideways', { short: true, touch: true }, true, 'right'],
    ['tablet upright', { touch: true }, true, 'bottom'],
    ['tablet sideways', { touch: true, wide: true }, false, 'side'],
    ['desktop', { wide: true }, false, 'side'],
    // A narrow desktop window keeps the chosen view and the side panel.
    ['narrow desktop window', {}, false, 'side'],
  ];

  test.each(cases)('%s', (_, over, cards, placement) => {
    expect(cardsOnly(on(over))).toBe(cards);
    expect(controlPlacement(on(over))).toBe(placement);
  });
});

describe('card details strip', () => {
  // Two groups: a b c d e | f g
  const header = (key: string): Entry => ({ kind: 'group', key, group: null, members: [] });
  const row = (id: string): Entry => ({
    kind: 'row',
    projector: { ...byId('n1'), id },
    stripe: false,
  });
  const entries: Entry[] = [
    header('g1'),
    ...['a', 'b', 'c', 'd', 'e'].map(row),
    header('g2'),
    ...['f', 'g'].map(row),
  ];
  const at = (openId: string | null, columns: number) =>
    withDetails(entries, openId, columns).map((e) =>
      e.kind === 'group' ? `|` : e.kind === 'details' ? `[${e.column}]` : e.projector.id,
    );

  test('goes after the last card of the open card’s row', () => {
    expect(at('b', 3).join(' ')).toBe('| a b c [1] d e | f g');
    expect(at('d', 3).join(' ')).toBe('| a b c d e [0] | f g');
    expect(at('g', 3).join(' ')).toBe('| a b c d e | f g [1]');
  });

  test('rows restart under a group header; one column puts it right under the card', () => {
    expect(at('f', 2).join(' ')).toBe('| a b c d e | f g [0]');
    expect(at('c', 1).join(' ')).toBe('| a b c [0] d e | f g');
  });

  test('nothing open, or the open card filtered out: no strip', () => {
    expect(at(null, 3)).not.toContain('[0]');
    expect(withDetails(entries, 'zz', 3)).toHaveLength(entries.length);
  });

  test('switching cards within a row keeps the same strip', () => {
    const key = (id: string) => {
      const strip = withDetails(entries, id, 3).find((e) => e.kind === 'details');
      return strip?.kind === 'details' ? strip.key : null;
    };
    expect(key('a')).toBe(key('c'));
    expect(key('a')).not.toBe(key('d'));
  });
});

describe('phone card', () => {
  test('a viewer taps the card to expand it', async () => {
    const { onselect, onexpand } = card('n2', false);
    // The card body comes first; the chevron is the second expand button.
    const [body] = screen.getAllByRole('button', { expanded: false });
    await fireEvent.click(body as HTMLElement);
    expect(onexpand).toHaveBeenCalledOnce();
    expect(onselect).not.toHaveBeenCalled();
  });

  test('an operator taps the card to select it; the chevron still expands', async () => {
    const { onselect, onexpand } = card('n2', true);
    await fireEvent.click(screen.getByRole('button', { pressed: false }));
    expect(onselect).toHaveBeenCalledOnce();
    await fireEvent.click(screen.getByRole('button', { name: /^Show details/ }));
    expect(onexpand).toHaveBeenCalledOnce();
  });

  test('an offline projector can’t be selected and shows its state', async () => {
    const { onselect } = card('n4', true);
    expect(screen.getByText('Offline')).toBeTruthy();
    expect(screen.getByRole('checkbox')).toHaveProperty('disabled', true);
    await fireEvent.click(screen.getByRole('button', { pressed: false }));
    expect(onselect).not.toHaveBeenCalled();
  });

  test('an active test pattern shows on the card, shutter open or closed', () => {
    const show = (testPattern: string, shutter: 'open' | 'closed') =>
      render(ProjectorCard, {
        p: { ...byId('n2'), testPattern, shutter },
        config,
        groups,
        patternLabel: () => 'Cross Hatch',
        operator: false,
        selected: false,
        expanded: false,
        onselect: () => {},
        onexpand: () => {},
      });
    show('OTS:07', 'open');
    expect(screen.getByRole('img', { name: 'Test pattern: Cross Hatch' })).toBeTruthy();
    cleanup();
    show('OTS:07', 'closed');
    expect(screen.getByRole('img', { name: 'Test pattern: Cross Hatch' })).toBeTruthy();
    cleanup();
    show('OTS:00', 'open');
    expect(screen.queryByRole('img')).toBeNull();
  });

  test('the details strip lists every field the summary leaves out', async () => {
    // jsdom has no Web Animations, which the strip's slide-in runs on.
    Element.prototype.animate ??= () =>
      ({ cancel() {}, finished: Promise.resolve(), onfinish: null }) as unknown as Animation;
    const onclose = vi.fn();
    render(CardDetails, {
      p: byId('n2'),
      config,
      groups,
      patternLabel: (c: string) => c,
      column: 1,
      columns: 3,
      onclose,
    });
    for (const label of ['IP Address', 'Serial Number', 'Group', 'Errors']) {
      expect(screen.getByText(label)).toBeTruthy();
    }
    expect(screen.queryByText('Power')).toBeNull();
    await fireEvent.click(screen.getByRole('button', { name: 'Close details' }));
    expect(onclose).toHaveBeenCalledOnce();
  });
});
