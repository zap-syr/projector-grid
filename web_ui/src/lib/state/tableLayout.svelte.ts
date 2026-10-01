import type { ColumnId, Config, Density, TableColumn } from '../api/types';
import { PREVIEW_COLUMN } from '../logic/columns';
import { device } from './device.svelte';

/** Per-browser table layout, so a phone and a booth laptop can differ. */
export interface StoredLayout {
  /** Visible columns in order; Group stays in here while grouping hides it. */
  columns: TableColumn[];
  widths: Partial<Record<TableColumn, number>>;
  sortColumn: ColumnId;
  sortAscending: boolean;
  density: Density;
  fitToWidth: boolean;
  groupBy: boolean;
  /** Collapsed group sections (group ids, or `UNGROUPED`). */
  collapsed: string[];
}

const KEY = 'pg.table.v2';
/** Before the Preview column: read once, Preview added at the end. */
const V1 = 'pg.table.v1';

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
  const current = readKey(KEY);
  if (current) return current;
  const old = readKey(V1);
  return old && { ...old, columns: withPreviewColumn(old.columns) };
}

/** Empty means the default set, which already has Preview. */
const withPreviewColumn = (columns: TableColumn[]): TableColumn[] =>
  columns.length === 0 ? [] : [...columns, PREVIEW_COLUMN.id];

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
    columns: withPreviewColumn(config.layout.columns),
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

  setWidth(column: TableColumn, width: number): void {
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
