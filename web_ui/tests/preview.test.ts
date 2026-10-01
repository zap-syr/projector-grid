import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { fireEvent, render, screen } from '@testing-library/svelte';
import { flushSync } from 'svelte';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';

import type { Config, PreviewStatus, Projector } from '../src/lib/api/types';
import PreviewDialog from '../src/lib/components/preview/PreviewDialog.svelte';
import DataTable from '../src/lib/components/table/DataTable.svelte';
import { tableDefaults, withPreview } from '../src/lib/logic/columns';
import { cornerTag, frameColor, preShowReady, stepped } from '../src/lib/logic/preview';
import { live } from '../src/lib/state/live.svelte';
import { preview } from '../src/lib/state/preview.svelte';
import { tableLayout, type StoredLayout } from '../src/lib/state/tableLayout.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

const config = fixture<Config>('config');
const projectors = fixture<Projector[]>('projectors');
const live1 = fixture<PreviewStatus>('preview-status');
const noSignal = fixture<PreviewStatus>('preview-status-notice');
const byId = (id: string) => projectors.find((p) => p.id === id);

/** EventSource stand-in: the test plays the server. */
class FakeSource {
  static last: FakeSource | null = null;
  static opened: string[] = [];
  static readonly CLOSED = 2;
  readyState = 1;
  closed = false;
  onerror: (() => void) | null = null;
  #listeners = new Map<string, (e: MessageEvent<string>) => void>();

  constructor(readonly url: string) {
    FakeSource.last = this;
    FakeSource.opened.push(url);
  }

  addEventListener(name: string, fn: (e: MessageEvent<string>) => void) {
    this.#listeners.set(name, fn);
  }

  emit(name: string, data: unknown) {
    this.#listeners.get(name)?.({ data: JSON.stringify(data) } as MessageEvent<string>);
    flushSync();
  }

  close() {
    this.closed = true;
  }
}

beforeEach(() => {
  FakeSource.last = null;
  FakeSource.opened = [];
  vi.stubGlobal('EventSource', FakeSource);
});

afterEach(() => {
  preview.close();
  live.projectors = [];
  vi.unstubAllGlobals();
});

describe('preview logic', () => {
  test('◀ ▶ wrap at the ends', () => {
    expect(stepped(0, 3, -1)).toBe(2);
    expect(stepped(2, 3, 1)).toBe(0);
    expect(stepped(0, 0, 1)).toBe(0);
  });

  test('the frame follows the shutter while the projector is on', () => {
    expect(frameColor(byId('n2'))).toBe('#6cff6c');
    expect(frameColor({ ...(byId('n2') as Projector), shutter: 'closed' })).toBe('#ff5f56');
    expect(frameColor(byId('n3'))).toBe('var(--line-strong)');
  });

  test('pre-show wins the corner tag', () => {
    expect(cornerTag(live1)).toBe('PRE-SHOW');
    expect(cornerTag({ ...live1, preShow: false })).toBe('TEST PATTERN');
    expect(cornerTag({ ...noSignal, preShow: false })).toBeNull();
  });

  test('pre-show needs Standby and the feed up', () => {
    expect(preShowReady(byId('n3'), noSignal)).toBe(true);
    expect(preShowReady(byId('n2'), live1)).toBe(false);
    expect(preShowReady(byId('n3'), { ...noSignal, state: 'connecting' })).toBe(false);
    expect(preShowReady(byId('n3'), null)).toBe(false);
  });
});

describe('Preview column', () => {
  test('on by default; an app preset keeps it while it is shown', () => {
    expect(tableDefaults(config).at(-1)).toBe('preview');
    expect(withPreview(['model', 'ip'], true)).toEqual(['model', 'ip', 'preview']);
    expect(withPreview(['model', 'ip'], false)).toEqual(['model', 'ip']);
  });

  test('a layout saved before it gains it at the end', () => {
    const old: StoredLayout = {
      ...config.layout,
      columns: ['model', 'ip'],
      widths: {},
      collapsed: [],
    };
    localStorage.removeItem('pg.table.v2');
    localStorage.setItem('pg.table.v1', JSON.stringify(old));
    tableLayout.init(config);
    expect(tableLayout.value?.columns).toEqual(['model', 'ip', 'preview']);
    localStorage.removeItem('pg.table.v1');
  });

  test('its button opens the preview in the rows’ order', async () => {
    // bind:clientWidth needs it; jsdom has none.
    vi.stubGlobal(
      'ResizeObserver',
      class {
        observe() {}
        unobserve() {}
        disconnect() {}
      },
    );
    live.projectors = projectors;
    const layout: StoredLayout = {
      ...config.layout,
      columns: ['model', 'preview'],
      sortColumn: 'model',
      sortAscending: false,
      widths: {},
      groupBy: false,
      collapsed: [],
    };
    render(DataTable, { config, layout, operator: false });
    await fireEvent.click(screen.getByRole('button', { name: 'Preview PJ-02' }));
    expect(preview.order).toEqual(['n4', 'n3', 'n2', 'n1']);
    expect(preview.id).toBe('n2');
  });
});

describe('preview window', () => {
  function open(id = 'n2', operator = true) {
    live.projectors = projectors;
    preview.open(['n1', 'n2', 'n3', 'n4'], id);
    render(PreviewDialog, { config, operator });
  }

  test('status, then the image with its tags', () => {
    open();
    expect(FakeSource.last?.url).toBe('/api/preview/n2');
    expect(screen.getByLabelText('Connecting')).toBeTruthy();
    FakeSource.last?.emit('status', { ...live1, preShow: false });
    FakeSource.last?.emit('frame', { jpeg: '/9j/' });
    expect(screen.getByRole('img').getAttribute('src')).toBe('data:image/jpeg;base64,/9j/');
    expect(screen.getByText('TEST PATTERN')).toBeTruthy();
    expect(screen.getByText(live1.signal ?? '')).toBeTruthy();
    expect(screen.getByText('2 / 4')).toBeTruthy();
  });

  test('◀ ▶ and the arrow keys step to the next stream, wrapping', async () => {
    open('n1');
    await fireEvent.click(screen.getByRole('button', { name: 'Previous projector' }));
    // n4 is offline: not dialled until Retry.
    expect(screen.getByText('4 / 4')).toBeTruthy();
    expect(screen.getByText('Preview not available')).toBeTruthy();
    expect(FakeSource.opened).toEqual(['/api/preview/n1']);

    await fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(FakeSource.opened.at(-1)).toBe('/api/preview/n4');

    const n4 = FakeSource.last;
    await fireEvent.keyDown(window, { key: 'ArrowRight' });
    expect(n4?.closed).toBe(true);
    expect(FakeSource.opened.at(-1)).toBe('/api/preview/n1');
    expect(screen.getByText('1 / 4')).toBeTruthy();
  });

  test('Esc closes and ends the stream', async () => {
    open();
    const source = FakeSource.last;
    await fireEvent.keyDown(window, { key: 'Escape' });
    expect(preview.id).toBeNull();
    expect(source?.closed).toBe(true);
  });

  test('pre-show: an operator only, in Standby with the feed up', () => {
    open('n3');
    const sw = () => screen.getByRole('switch', { name: 'Pre-show' }) as HTMLButtonElement;
    expect(sw().disabled).toBe(true);
    FakeSource.last?.emit('status', noSignal);
    expect(sw().disabled).toBe(false);
    expect(screen.getByText('No signal')).toBeTruthy();
    expect(screen.getByText(/applying/)).toBeTruthy();
  });

  test('a viewer watches without the pre-show switch', () => {
    open('n3', false);
    FakeSource.last?.emit('status', noSignal);
    expect(screen.queryByRole('switch')).toBeNull();
  });
});
