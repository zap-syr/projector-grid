import type { Group, Projector } from '../api/types';

export type StatusFilter = 'all' | 'online' | 'offline' | 'warnings';

/** Same buckets as the header counts (`statusSummary`). */
export function matchesFilter(p: Projector, filter: StatusFilter): boolean {
  switch (filter) {
    case 'all':
      return true;
    case 'online':
      return p.connection === 'connected' || p.connection === 'unprotected';
    case 'offline':
      return p.connection === 'offline';
    case 'warnings':
      return p.errors !== 'NO ERRORS' && p.errors !== '-';
  }
}

/** Name, IP or serial contains [query], ignoring case. */
export function matchesSearch(p: Projector, query: string): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  return [p.name, p.ip, p.serial].some((s) => s.toLowerCase().includes(q));
}

export type Entry =
  | { kind: 'group'; key: string; group: Group | null; members: Projector[] }
  | { kind: 'row'; projector: Projector; stripe: boolean };

/**
 * The display list (`_buildEntries`): with [groupBy], each group's rows (in
 * sort order) under a header; groups by name, ungrouped and orphaned last.
 * Stripes restart per group. Rows of a [collapsed] group are left out.
 */
export function buildEntries(
  sorted: readonly Projector[],
  groups: readonly Group[],
  groupBy: boolean,
  collapsed: ReadonlySet<string> = new Set(),
): Entry[] {
  const rows = (members: readonly Projector[]): Entry[] =>
    members.map((p, i) => ({ kind: 'row', projector: p, stripe: i % 2 === 1 }));
  if (!groupBy) return rows(sorted);

  const byGroup = new Map<string | null, Projector[]>();
  for (const p of sorted) {
    const list = byGroup.get(p.groupId) ?? [];
    list.push(p);
    byGroup.set(p.groupId, list);
  }
  const name = (g: Group) => g.name.toLowerCase();
  const named = groups
    .filter((g) => byGroup.has(g.id))
    .sort((a, b) => (name(a) < name(b) ? -1 : name(a) > name(b) ? 1 : 0));

  const entries: Entry[] = [];
  const cluster = (key: string, group: Group | null, members: Projector[]) => {
    entries.push({ kind: 'group', key, group, members });
    if (!collapsed.has(key)) entries.push(...rows(members));
  };
  for (const g of named) cluster(g.id, g, byGroup.get(g.id) ?? []);
  const known = new Set(groups.map((g) => g.id));
  const trailing = [...byGroup.entries()]
    .filter(([id]) => id === null || !known.has(id))
    .sort(([a], [b]) => (a === null ? -1 : b === null ? 1 : 0))
    .flatMap(([, members]) => members);
  if (trailing.length > 0) cluster(UNGROUPED, null, trailing);
  return entries;
}

export type CardEntry =
  Entry | { kind: 'details'; projector: Projector; column: number; key: string };

/**
 * The card grid with the open card's details: a full-width strip after the
 * last card of the open card's row, so no row grows ragged. Rows restart
 * under each group header. [column] is where the strip's pointer goes; the
 * key follows the row, so switching cards within it keeps the same strip.
 */
export function withDetails(
  entries: readonly Entry[],
  openId: string | null,
  columns: number,
): CardEntry[] {
  const open = entries.findIndex((e) => e.kind === 'row' && e.projector.id === openId);
  const card = entries[open];
  if (!card || card.kind !== 'row') return [...entries];

  let start = open;
  while (start > 0 && entries[start - 1]?.kind === 'row') start--;
  let end = open;
  while (entries[end + 1]?.kind === 'row') end++;

  const pos = open - start;
  const rowEnd = Math.min(start + (Math.floor(pos / columns) + 1) * columns - 1, end);
  const last = entries[rowEnd];
  const key = last?.kind === 'row' ? `d:${last.projector.id}` : 'd';
  return [
    ...entries.slice(0, rowEnd + 1),
    { kind: 'details', projector: card.projector, column: pos % columns, key },
    ...entries.slice(rowEnd + 1),
  ];
}

/** Collapse key of the trailing "Ungrouped" section. */
export const UNGROUPED = '__ungrouped__';

export type WorstStatus = { text: string; tone: 'err' | 'warn' } | null;

/** Group header pill: errors beat auth errors beat offline (`_worstStatus`). */
export function worstStatus(members: readonly Projector[]): WorstStatus {
  const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;
  const errors = members.filter(
    (p) => p.errors !== '-' && p.errors !== 'NO ERRORS' && p.errors !== '',
  ).length;
  if (errors > 0) return { text: plural(errors, 'error'), tone: 'err' };
  const auth = members.filter((p) => p.connection === 'unauthorized').length;
  if (auth > 0) return { text: plural(auth, 'auth error'), tone: 'warn' };
  const offline = members.filter((p) => p.connection === 'offline').length;
  if (offline > 0) return { text: `${offline} offline`, tone: 'err' };
  return null;
}
