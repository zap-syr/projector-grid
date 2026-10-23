import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { describe, expect, test, vi } from 'vitest';

import type { Config, Group, Projector } from '../src/lib/api/types';
import ProjectorDetails from '../src/lib/components/details/ProjectorDetails.svelte';
import ProjectorCard from '../src/lib/components/phone/ProjectorCard.svelte';
import { cardStatus } from '../src/lib/logic/cardStatus';
import type { CardSize } from '../src/lib/state/cardSize.svelte';
import { details } from '../src/lib/state/details.svelte';
import { cardsOnly, controlPlacement, type Screen } from '../src/lib/state/device.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const config = fixture<Config>('config');
const projectors = fixture<Projector[]>('projectors');
const groups = new Map(fixture<Group[]>('groups').map((g) => [g.id, g]));
const byId = (id: string) => projectors.find((p) => p.id === id) as Projector;

function card(id: string, operator: boolean, open = false, size: CardSize = 'extended') {
  const onselect = vi.fn();
  const ondetails = vi.fn();
  render(ProjectorCard, {
    p: byId(id),
    size,
    thresholds: config.thresholds,
    patternLabel: (c: string) => c,
    operator,
    selected: false,
    open,
    onselect,
    ondetails,
  });
  return { onselect, ondetails };
}

describe('layout per screen', () => {
  const on = (over: Partial<Screen>): Screen => ({
    phone: false,
    short: false,
    touch: false,
    wide: false,
    portrait: false,
    ...over,
  });
  const cases: [string, Partial<Screen>, boolean, string][] = [
    ['phone upright', { phone: true, touch: true, portrait: true }, true, 'bottom'],
    ['phone sideways', { short: true, touch: true }, true, 'right'],
    ['tablet upright', { touch: true, portrait: true }, true, 'bottom'],
    ['tablet sideways', { touch: true, wide: true }, false, 'side'],
    // iPad Pro 13" upright: the table, with Control and the details as sheets.
    ['large tablet upright', { touch: true, wide: true, portrait: true }, false, 'bottom'],
    ['desktop', { wide: true }, false, 'side'],
    // A narrow or tall desktop window keeps the chosen view and the side panel.
    ['narrow desktop window', {}, false, 'side'],
    ['upright desktop monitor', { wide: true, portrait: true }, false, 'side'],
  ];

  test.each(cases)('%s', (_, over, cards, placement) => {
    expect(cardsOnly(on(over))).toBe(cards);
    expect(controlPlacement(on(over))).toBe(placement);
  });
});

describe('details state', () => {
  test('a second click on the open projector closes the details; another switches', () => {
    details.toggle('n1', ['n1', 'n2']);
    expect(details.id).toBe('n1');
    expect(details.order).toEqual(['n1', 'n2']);
    details.toggle('n2', ['n2']);
    expect(details.id).toBe('n2');
    details.toggle('n2', ['n2']);
    expect(details.id).toBeNull();
  });
});

describe('projector details', () => {
  const show = (id: string, extra: { onpreview?: () => void; columns?: boolean } = {}) => {
    const onclose = vi.fn();
    render(ProjectorDetails, {
      p: byId(id),
      config,
      groups,
      patternLabel: (c: string) => c,
      placement: 'panel',
      onclose,
      ...extra,
    });
    return { onclose };
  };

  test('the header names the projector by IP, then model and serial', () => {
    show('n2');
    expect(screen.getByText('192.168.0.112')).toBeTruthy();
    expect(screen.getByText('PJ-02, serial SH4213002')).toBeTruthy();
  });

  test('without a serial the model stands alone', () => {
    show('n3');
    expect(screen.getByText('PJ-03')).toBeTruthy();
  });

  test('a warning is Needs attention, with its value and since when', () => {
    show('n2');
    expect(screen.getByRole('heading', { name: 'Needs attention' })).toBeTruthy();
    expect(screen.getByText('Intake temperature')).toBeTruthy();
    expect(screen.getByText('41 °C, limit 40 °C')).toBeTruthy();
    expect(screen.getByText('Since')).toBeTruthy();
  });

  test('an error is an Alert; offline says when it was last seen', () => {
    show('n1');
    expect(screen.getByRole('heading', { name: 'Alert' })).toBeTruthy();
    cleanup();
    show('n4');
    expect(screen.getByRole('heading', { name: 'Offline' })).toBeTruthy();
    expect(screen.getByText('Last seen')).toBeTruthy();
  });

  test('every section, the gauges, and Web UI opening the projector’s own page', () => {
    show('n2');
    for (const h of ['Status', 'Temperature', 'Runtime and power']) {
      expect(screen.getByRole('heading', { name: h })).toBeTruthy();
    }
    for (const label of ['Intake', 'Exhaust', 'Light source', 'AC voltage']) {
      expect(screen.getByText(label)).toBeTruthy();
    }
    expect(screen.getByRole('link', { name: 'Web UI' }).getAttribute('href')).toBe(
      'http://192.168.0.112',
    );
  });

  test('Preview only where it is offered; ✕ and Esc close the panel', async () => {
    const onpreview = vi.fn();
    const { onclose } = show('n2', { onpreview });
    await fireEvent.click(screen.getByRole('button', { name: 'Preview' }));
    expect(onpreview).toHaveBeenCalledOnce();
    await fireEvent.click(screen.getByRole('button', { name: 'Close details' }));
    await fireEvent.keyDown(window, { key: 'Escape' });
    expect(onclose).toHaveBeenCalledTimes(2);
    cleanup();
    show('n2');
    expect(screen.queryByRole('button', { name: 'Preview' })).toBeNull();
  });
});

describe('phone card', () => {
  test('a viewer taps the card to open its details; no info button', async () => {
    const { onselect, ondetails } = card('n2', false);
    await fireEvent.click(screen.getByRole('button', { pressed: false }));
    expect(ondetails).toHaveBeenCalledOnce();
    expect(onselect).not.toHaveBeenCalled();
    expect(screen.queryByRole('button', { name: /^Details/ })).toBeNull();
  });

  test('an operator taps the card to select it; ⓘ opens the details', async () => {
    const { onselect, ondetails } = card('n2', true);
    await fireEvent.click(screen.getByRole('button', { name: /^192\.168\.0\.112/ }));
    expect(onselect).toHaveBeenCalledOnce();
    await fireEvent.click(screen.getByRole('button', { name: 'Details of 192.168.0.112' }));
    expect(ondetails).toHaveBeenCalledOnce();
  });

  test('an offline projector can’t be selected and shows its state', async () => {
    const { onselect } = card('n4', true);
    expect(screen.getByText(/^Offline/)).toBeTruthy();
    expect(screen.getByRole('checkbox')).toHaveProperty('disabled', true);
    await fireEvent.click(screen.getByRole('button', { name: /^192\.168\.0\.131/ }));
    expect(onselect).not.toHaveBeenCalled();
  });

  test('an active test pattern shows on the card, shutter open or closed', () => {
    const show = (testPattern: string, shutter: 'open' | 'closed') =>
      render(ProjectorCard, {
        p: { ...byId('n2'), testPattern, shutter },
        size: 'extended',
        thresholds: config.thresholds,
        patternLabel: () => 'Cross Hatch',
        operator: false,
        selected: false,
        open: false,
        onselect: () => {},
        ondetails: () => {},
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

  test('Extended labels its values; Compact names them in tooltips', () => {
    card('n2', true);
    for (const label of ['Input', 'Signal', 'Intake', 'Exhaust', 'Runtime', 'AC']) {
      expect(screen.getByText(label)).toBeTruthy();
    }
    cleanup();
    card('n2', true, false, 'compact');
    expect(screen.queryByText('Runtime')).toBeNull();
    expect(screen.getByTitle('Intake temperature')).toBeTruthy();
    expect(screen.getByText('In')).toBeTruthy();
  });

  test('a wrong login knows nothing: Unknown in place of the values', () => {
    render(ProjectorCard, {
      p: { ...byId('n2'), connection: 'unauthorized' },
      size: 'extended',
      thresholds: config.thresholds,
      patternLabel: (c: string) => c,
      operator: false,
      selected: false,
      open: false,
      onselect: () => {},
      ondetails: () => {},
    });
    // Power, shutter, input, signal, both temperatures, runtime and AC.
    expect(screen.getAllByText('Unknown')).toHaveLength(8);
  });
});

describe('card status footer', () => {
  const now = new Date();
  const problem = (over: Partial<Projector['status']['problems'][number]>) => ({
    level: 'warning' as const,
    kind: 'temperature' as const,
    badge: 'Exhaust hot',
    title: 'Exhaust temperature',
    value: '52 °C, limit 50 °C',
    flag: '52°C',
    since: null,
    ...over,
  });
  const withProblems = (problems: Projector['status']['problems']): Projector => ({
    ...byId('n2'),
    status: { ...byId('n2').status, problems },
  });

  test('no problem reads No problems', () => {
    expect(cardStatus(withProblems([]), now)).toEqual({
      tone: 'none',
      icon: 'check',
      text: 'No problems',
    });
  });

  test('a temperature names its value; the rest count as +N more', () => {
    expect(cardStatus(withProblems([problem({})]), now).text).toBe('Exhaust hot, 52 °C');
    const s = cardStatus(
      withProblems([
        problem({ level: 'error', kind: 'projectorError', badge: 'Error F305', flag: 'F305' }),
        problem({}),
      ]),
      now,
    );
    expect(s).toEqual({ tone: 'error', icon: 'error', text: 'Error F305, +1 more' });
  });

  test('a lost signal names the input; a wrong login gets the lock', () => {
    const p = { ...withProblems([problem({ level: 'error', kind: 'signal' })]), input: 'SDI 2' };
    expect(cardStatus(p, now).text).toBe('Signal lost on SDI 2');
    const login = cardStatus(
      withProblems([problem({ kind: 'login', badge: 'Wrong login', flag: 'Login' })]),
      now,
    );
    expect(login).toEqual({ tone: 'warning', icon: 'lock', text: 'Wrong login' });
  });

  test('offline says when it last answered', () => {
    const p: Projector = { ...byId('n2'), connection: 'offline', lastSeen: null };
    expect(cardStatus(p, now)).toEqual({ tone: 'offline', icon: 'offline', text: 'Offline' });
    const seen = new Date(now);
    seen.setHours(16, 41);
    expect(cardStatus({ ...p, lastSeen: seen.toISOString() }, now).text).toBe(
      'Offline, last seen 16:41',
    );
  });
});
