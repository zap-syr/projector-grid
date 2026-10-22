import type { Group, Projector } from '../api/types';

/** The quick filters, one at a time like the app's (`MonitoringQuickFilter`). */
export type StatusFilter = 'all' | 'online' | 'attention' | 'offline' | 'standby';

export const QUICK_FILTERS: readonly StatusFilter[] = [
  'all',
  'online',
  'attention',
  'offline',
  'standby',
];

/**
 * `matchesQuickFilter`, from the app's status. They overlap: a projector in
 * standby with a warning is Online, Attention and Standby.
 */
export function matchesFilter(p: Projector, filter: StatusFilter): boolean {
  switch (filter) {
    case 'all':
      return true;
    case 'online':
      return p.status.online;
    case 'attention':
      return p.status.level === 'warning' || p.status.level === 'error';
    case 'offline':
      return p.status.level === 'offline';
    case 'standby':
      return p.status.standby;
  }
}

/** Each quick filter's count (`quickFilterCounts`). */
export function filterCounts(projectors: readonly Projector[]): Record<StatusFilter, number> {
  const counts = { all: 0, online: 0, attention: 0, offline: 0, standby: 0 };
  for (const p of projectors) {
    for (const f of QUICK_FILTERS) if (matchesFilter(p, f)) counts[f]++;
  }
  return counts;
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

/** A group row's summary, the app's `monitoringGroupSummary`: `8 projectors, 7 online, 1 needs attention`. */
export function groupSummary(members: readonly Projector[]): string {
  let online = 0;
  let standby = 0;
  let attention = 0;
  let errors = 0;
  let offline = 0;
  for (const { status: s } of members) {
    if (s.online) online++;
    if (s.standby) standby++;
    if (s.level === 'warning') attention++;
    if (s.level === 'error') errors++;
    if (s.level === 'offline') offline++;
  }
  const n = members.length;
  return [
    `${n} ${n === 1 ? 'projector' : 'projectors'}`,
    `${online} online`,
    ...(errors > 0 ? [`${errors} ${errors === 1 ? 'error' : 'errors'}`] : []),
    ...(attention > 0 ? [`${attention} ${attention === 1 ? 'needs' : 'need'} attention`] : []),
    ...(offline > 0 ? [`${offline} offline`] : []),
    ...(standby > 0 ? [`${standby} in standby`] : []),
  ].join(', ');
}
