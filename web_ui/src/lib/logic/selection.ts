import type { Group, Projector } from '../api/types';

/** Only projectors that can take a command: offline / auth-error rows can't be selected. */
export function isSelectable(p: Projector): boolean {
  return p.connection === 'connected' || p.connection === 'unprotected';
}

export type TriState = 'none' | 'some' | 'all';

/** Checkbox state of a set of rows (select-all, a group header). */
export function triState(rows: readonly Projector[], selected: ReadonlySet<string>): TriState {
  const selectable = rows.filter(isSelectable);
  const n = selectable.filter((p) => selected.has(p.id)).length;
  if (n === 0) return 'none';
  return n === selectable.length ? 'all' : 'some';
}

/**
 * Clicking a tri-state box (PatternFly's bulk selector, Gmail): none selected
 * → select them all; some or all → clear them. So the box is also the one-tap
 * way to drop a selection on a touch screen, where there's no Esc.
 */
export function toggledAll(rows: readonly Projector[], selected: ReadonlySet<string>): Set<string> {
  const next = new Set(selected);
  const ids = rows.filter(isSelectable).map((p) => p.id);
  if (triState(rows, selected) === 'none') ids.forEach((id) => next.add(id));
  else ids.forEach((id) => next.delete(id));
  return next;
}

/**
 * Shift-click: adds every selectable row between [anchor] and [id] in
 * display [order]; a plain toggle when the anchor isn't shown any more.
 */
export function selectedRange(
  order: readonly Projector[],
  anchor: string | null,
  id: string,
  selected: ReadonlySet<string>,
): Set<string> {
  const next = new Set(selected);
  const from = order.findIndex((p) => p.id === anchor);
  const to = order.findIndex((p) => p.id === id);
  if (from < 0 || to < 0) {
    if (next.has(id)) next.delete(id);
    else next.add(id);
    return next;
  }
  for (const p of order.slice(Math.min(from, to), Math.max(from, to) + 1)) {
    if (isSelectable(p)) next.add(p.id);
  }
  return next;
}

/**
 * Press on a row and drag across others: every selectable row between the
 * pressed row [from] and the one under the pointer [to] (display [order]) is
 * selected — or, when the drag began on an already selected row, deselected.
 * Recomputed from [base] (the selection at the press) on every move, so
 * dragging back shrinks the sweep again.
 */
export function draggedSelection(
  order: readonly Projector[],
  base: ReadonlySet<string>,
  from: string,
  to: string,
): Set<string> {
  const next = new Set(base);
  const a = order.findIndex((p) => p.id === from);
  const b = order.findIndex((p) => p.id === to);
  if (a < 0 || b < 0) return next;
  const add = !base.has(from);
  for (const p of order.slice(Math.min(a, b), Math.max(a, b) + 1)) {
    if (!isSelectable(p)) continue;
    if (add) next.add(p.id);
    else next.delete(p.id);
  }
  return next;
}

/** The toolbar's Select ▾ menu (the app's own group entries follow the fixed ones). */
export type SelectPreset =
  { kind: 'all' } | { kind: 'warnings' } | { kind: 'invert' } | { kind: 'group'; group: Group };

export function presetSelection(
  preset: SelectPreset,
  projectors: readonly Projector[],
  selected: ReadonlySet<string>,
): Set<string> {
  const pick = (test: (p: Projector) => boolean) =>
    new Set(projectors.filter((p) => isSelectable(p) && test(p)).map((p) => p.id));
  switch (preset.kind) {
    case 'all':
      return pick(() => true);
    case 'warnings':
      return pick((p) => p.errors !== 'NO ERRORS' && p.errors !== '-');
    case 'invert':
      return pick((p) => !selected.has(p.id));
    case 'group':
      return pick((p) => p.groupId === preset.group.id);
  }
}
