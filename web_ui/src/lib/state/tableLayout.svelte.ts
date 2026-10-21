import type { ColumnId, Config, Density } from '../api/types';
import { device } from './device.svelte';

/** Per-browser table layout, so a phone and a booth laptop can differ. */
export interface StoredLayout {
  /** Visible columns in order; Group stays in here while grouping hides it. */
  columns: ColumnId[];
  widths: Partial<Record<ColumnId, number>>;
  sortColumn: ColumnId;
  sortAscending: boolean;
  density: Density;
  fitToWidth: boolean;
  groupBy: boolean;
  /** Collapsed group sections (group ids, or `UNGROUPED`). */
  collapsed: string[];
}

/** v3: the app's two-line columns; v1 and v2 layouts used the old ids and are dropped. */
const KEY = 'pg.table.v3';

function isStoredLayout(v: unknown): v is StoredLayout {
  if (typeof v !== 'object' || v === null) return false;
  const o = v as Record<string, unknown>;
  return (
    Array.isArray(o.columns) &&
    typeof o.widths === 'object' &&
    o.widths !== null &&
    typeof o.sortColumn === 'string' &&
    typeof o.sortAscending === 'boolean' &&
    ['compact', 'standard', 'comfortable'].includes(o.density as string) &&
    typeof o.fitToWidth === 'boolean' &&
    typeof o.groupBy === 'boolean' &&
    Array.isArray(o.collapsed)
  );
}

function readKey(key: string): StoredLayout | null {
  try {
    const raw = localStorage.getItem(key);
    const parsed: unknown = raw === null ? null : JSON.parse(raw);
    return isStoredLayout(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function read(): StoredLayout | null {
  try {
    localStorage.removeItem('pg.table.v1');
    localStorage.removeItem('pg.table.v2');
  } catch {
    // Blocked storage: nothing to clean up either.
  }
  return readKey(KEY);
}

function write(layout: StoredLayout): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(layout));
  } catch {
    // Private mode / blocked storage: the layout just won't survive a reload.
  }
}

/**
 * The app's current Monitoring layout — the first visit's starting point.
 * Touch screens start with comfortable rows, big enough for a finger.
 */
function seed(config: Config): StoredLayout {
  return {
    ...config.layout,
    columns: [...config.layout.columns],
    widths: { ...config.layout.widths },
    density: device.touch ? 'comfortable' : config.layout.density,
    collapsed: [],
  };
}

class TableLayoutState {
  value = $state<StoredLayout | null>(null);

  init(config: Config): void {
    this.value = read() ?? seed(config);
  }

  /** Back to the app's current layout. */
  reset(config: Config): void {
    this.#set(seed(config));
  }

  update(patch: Partial<StoredLayout>): void {
    if (this.value) this.#set({ ...this.value, ...patch });
  }

  /** Header click: sort by [column], or reverse when it already is. */
  sortBy(column: ColumnId): void {
    const v = this.value;
    if (!v) return;
    this.update({
      sortColumn: column,
      sortAscending: v.sortColumn === column ? !v.sortAscending : true,
    });
  }

  setWidth(column: ColumnId, width: number): void {
    if (this.value) this.update({ widths: { ...this.value.widths, [column]: width } });
  }

  toggleCollapsed(key: string): void {
    const v = this.value;
    if (!v) return;
    this.update({
      collapsed: v.collapsed.includes(key)
        ? v.collapsed.filter((k) => k !== key)
        : [...v.collapsed, key],
    });
  }

  #set(layout: StoredLayout): void {
    this.value = layout;
    write(layout);
  }
}

export const tableLayout = new TableLayoutState();
