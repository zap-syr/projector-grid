import type { ColumnId, Config, TableColumn } from '../api/types';

/**
 * The page's own column: a button that opens Remote Preview. Not in the app's
 * table, so it's added to the app's catalogue here; hidden and moved like
 * any other.
 */
export const PREVIEW_COLUMN = { id: 'preview', label: 'Preview', defaultWidth: 92 } as const;

export interface ColumnInfo {
  id: TableColumn;
  label: string;
  defaultWidth: number;
}

/** The app's columns, then Preview. */
export const tableCatalogue = (config: Config): ColumnInfo[] => [...config.columns, PREVIEW_COLUMN];

export const tableDefaults = (config: Config): TableColumn[] => [
  ...config.defaultColumns,
  PREVIEW_COLUMN.id,
];

/** An app preset (it has no Preview) keeps Preview at the end while it's shown. */
export const withPreview = (columns: readonly ColumnId[], shown: boolean): TableColumn[] =>
  shown ? [...columns, PREVIEW_COLUMN.id] : [...columns];

/**
 * Column list rules, ported from the app's `MonitoringTable` statics and
 * `monitoring_columns.dart`. `saved` is the stored visible order; empty or
 * all-unknown means the default set.
 */
export function resolveColumns<C extends string>(
  saved: readonly string[],
  catalogue: readonly C[],
  defaults: readonly C[],
): C[] {
  const ids = saved.length === 0 ? defaults : saved;
  const known = ids.filter((id): id is C => catalogue.includes(id as C));
  return known.length === 0 ? [...defaults] : known;
}

/**
 * Shows or hides [id]. A re-shown column goes back to its canonical slot among
 * the visible ones; null when it would hide the last column (`toggledColumn`).
 */
export function toggledColumn<C extends string>(
  visible: readonly C[],
  id: C,
  catalogue: readonly C[],
): C[] | null {
  if (visible.includes(id)) {
    return visible.length === 1 ? null : visible.filter((c) => c !== id);
  }
  const rank = catalogue.indexOf(id);
  const next = [...visible];
  const at = next.findIndex((c) => catalogue.indexOf(c) > rank);
  next.splice(at < 0 ? next.length : at, 0, id);
  return next;
}

/**
 * Drag-reorder, same rule as the app's `_reorderColumn`: the target index is
 * taken before removing the dragged column, so a left→right drop lands after
 * the target and a right→left drop before it. Runs on the full visible list
 * (Group included even while grouping hides it) so Group keeps its place.
 */
export function reorderColumn<C extends string>(columns: readonly C[], dragged: C, target: C): C[] {
  const from = columns.indexOf(dragged);
  const to = columns.indexOf(target);
  if (dragged === target || from < 0 || to < 0) return [...columns];
  const next = [...columns];
  next.splice(from, 1);
  next.splice(to, 0, dragged);
  return next;
}

/** What the table renders: Group is redundant under group headers. */
export function renderedColumns<C extends string>(visible: readonly C[], groupBy: boolean): C[] {
  if (!groupBy) return [...visible];
  const withoutGroup = visible.filter((c) => c !== 'group');
  return withoutGroup.length === 0 ? [...visible] : withoutGroup;
}
