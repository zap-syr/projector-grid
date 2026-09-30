import type { ColumnId } from '../api/types';

/**
 * Column list rules, ported from the app's `MonitoringTable` statics and
 * `monitoring_columns.dart`. `saved` is the stored visible order; empty or
 * all-unknown means the default set.
 */
export function resolveColumns(
  saved: readonly string[],
  catalogue: readonly ColumnId[],
  defaults: readonly ColumnId[],
): ColumnId[] {
  const ids = saved.length === 0 ? defaults : saved;
  const known = ids.filter((id): id is ColumnId => catalogue.includes(id as ColumnId));
  return known.length === 0 ? [...defaults] : known;
}

/**
 * Shows or hides [id]. A re-shown column goes back to its canonical slot among
 * the visible ones; null when it would hide the last column (`toggledColumn`).
 */
export function toggledColumn(
  visible: readonly ColumnId[],
  id: ColumnId,
  catalogue: readonly ColumnId[],
): ColumnId[] | null {
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
export function reorderColumn(
  columns: readonly ColumnId[],
  dragged: ColumnId,
  target: ColumnId,
): ColumnId[] {
  const from = columns.indexOf(dragged);
  const to = columns.indexOf(target);
  if (dragged === target || from < 0 || to < 0) return [...columns];
  const next = [...columns];
  next.splice(from, 1);
  next.splice(to, 0, dragged);
  return next;
}

/** What the table renders: Group is redundant under group headers. */
export function renderedColumns(visible: readonly ColumnId[], groupBy: boolean): ColumnId[] {
  if (!groupBy) return [...visible];
  const withoutGroup = visible.filter((c) => c !== 'group');
  return withoutGroup.length === 0 ? [...visible] : withoutGroup;
}
