/**
 * The app's alert display rules (`domain/alerts.dart`), ported as pure
 * functions: order, counts, the card badge, grouping and the panel's
 * sections. The page never decides what is an alert; the app sends the list.
 */
import type { Alert, AlertRule, AlertSeverity, Projector } from '../api/types';

export type AlertGrouping = 'projector' | 'alert';

/** A Signal lost whose signal came back: over, waiting to be acknowledged. */
export const isRecovered = (a: Alert): boolean => a.restoredAt !== null;

const sevRank = (s: AlertSeverity) => (s === 'critical' ? 1 : 0);

/** Unacknowledged first, problems before recovered, critical first, newest first (`compareAlerts`). */
export function compareAlerts(a: Alert, b: Alert): number {
  if (a.acknowledged !== b.acknowledged) return a.acknowledged ? 1 : -1;
  if (isRecovered(a) !== isRecovered(b)) return isRecovered(a) ? 1 : -1;
  if (a.severity !== b.severity) return sevRank(b.severity) - sevRank(a.severity);
  return Date.parse(b.since) - Date.parse(a.since);
}

export const sortAlerts = (alerts: readonly Alert[]): Alert[] => [...alerts].sort(compareAlerts);

export interface AlertCounts {
  /** Unacknowledged, still a problem. */
  critical: number;
  warning: number;
  /** Every active one that is still a problem. */
  criticalTotal: number;
  warningTotal: number;
  /** Over, waiting to be acknowledged. */
  recovered: number;
}

/** `countAlerts`: the status bar's counts. */
export function countAlerts(alerts: readonly Alert[]): AlertCounts {
  const c: AlertCounts = {
    critical: 0,
    warning: 0,
    criticalTotal: 0,
    warningTotal: 0,
    recovered: 0,
  };
  for (const a of alerts) {
    if (isRecovered(a)) {
      c.recovered++;
    } else if (a.severity === 'critical') {
      c.criticalTotal++;
      if (!a.acknowledged) c.critical++;
    } else {
      c.warningTotal++;
      if (!a.acknowledged) c.warning++;
    }
  }
  return c;
}

export interface Badge {
  severity: AlertSeverity;
  /** Everything acknowledged: the icon is drawn outlined. */
  acknowledged: boolean;
  /** Only returned signals wait: a green check. */
  recovered: boolean;
  /** What the icon stands for; shown from two up. */
  count: number;
}

/** A card's badge (`alertBadge`); null for no badge. */
export function alertBadge(alerts: readonly Alert[]): Badge | null {
  if (alerts.length === 0) return null;
  const unacked = alerts.filter((a) => !a.acknowledged);
  const open = unacked.filter((a) => !isRecovered(a));
  const pool = open.length > 0 ? open : alerts;
  const severity = pool.some((a) => a.severity === 'critical') ? 'critical' : 'warning';
  const recovered = open.length === 0 && unacked.length > 0;
  return {
    severity,
    acknowledged: unacked.length === 0,
    recovered,
    count: recovered ? unacked.length : pool.filter((a) => a.severity === severity).length,
  };
}

/** Zero-padded dotted quad, so a string compare orders IPs numerically (`ipSortKey`). */
export const ipSortKey = (ip: string): string =>
  ip
    .split('.')
    .map((o) => String(Number.parseInt(o, 10) || 0).padStart(3, '0'))
    .join('.');

export interface AlertGroup {
  /** The projector id or the rule. */
  key: string;
  alerts: Alert[];
}

/**
 * `groupAlerts`: by projector (IP ascending) or by rule (most urgent first,
 * then the bigger group), each group sorted.
 */
export function groupAlerts(alerts: readonly Alert[], by: AlertGrouping): AlertGroup[] {
  const groups = new Map<string, Alert[]>();
  for (const a of alerts) {
    const key = by === 'projector' ? a.projectorId : a.rule;
    groups.set(key, [...(groups.get(key) ?? []), a]);
  }
  const list = [...groups].map(([key, al]) => ({ key, alerts: sortAlerts(al) }));
  if (by === 'projector') {
    const ip = (g: AlertGroup) => ipSortKey(g.alerts[0]?.ip ?? '');
    return list.sort((g, h) => (ip(g) < ip(h) ? -1 : ip(g) > ip(h) ? 1 : 0));
  }
  return list.sort((g, h) => {
    const first = compareAlerts(g.alerts[0] as Alert, h.alerts[0] as Alert);
    return first !== 0 ? first : h.alerts.length - g.alerts.length;
  });
}

export interface ProjectGroupSection<T> {
  /** Null for Ungrouped. */
  groupId: string | null;
  items: T[];
}

/**
 * `sectionByProjectGroup` / `subsectionByProjectGroup`: [items] by their
 * projector's project group, in [order] (the Manage Groups order), then
 * Ungrouped; empty ones left out, a group no longer in [order] counts as none.
 */
export function byProjectGroup<T>(
  items: readonly T[],
  projectorOf: (item: T) => string,
  groupOf: (projectorId: string) => string | null | undefined,
  order: readonly string[],
): ProjectGroupSection<T>[] {
  const known = new Set(order);
  const byGroup = new Map<string | null, T[]>();
  for (const item of items) {
    const id = groupOf(projectorOf(item)) ?? null;
    const key = id !== null && known.has(id) ? id : null;
    byGroup.set(key, [...(byGroup.get(key) ?? []), item]);
  }
  return [...order, null].flatMap((id) => {
    const list = byGroup.get(id);
    return list ? [{ groupId: id, items: list }] : [];
  });
}

/** Projector groups (from [groupAlerts] by projector) in project-group sections. */
export const alertsInSections = (
  groups: readonly AlertGroup[],
  groupOf: (projectorId: string) => string | null | undefined,
  order: readonly string[],
): ProjectGroupSection<AlertGroup>[] => byProjectGroup(groups, (g) => g.key, groupOf, order);

/** `formatAlertDuration`: `< 1 min`, `12 min`, `1 h 05 min`. */
export function formatDuration(ms: number): string {
  const minutes = Math.floor(Math.max(0, ms) / 60000);
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return `${minutes} min`;
  return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')} min`;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** `formatAlertStart`: `14:02` today, `Sep 30 14:02` before that (this browser's local time). */
export function formatStart(since: Date, now: Date): string {
  const hhmm = `${String(since.getHours()).padStart(2, '0')}:${String(since.getMinutes()).padStart(2, '0')}`;
  const sameDay = since.toDateString() === now.toDateString();
  return sameDay ? hhmm : `${MONTHS[since.getMonth()]} ${since.getDate()} ${hhmm}`;
}

/**
 * Alerts in [next] the operator has to notice anew: new ones, ones that came
 * back after being acknowledged (a warning escalating, a new dropout).
 * Returned signals and acknowledged ones don't count.
 */
export function raisedAlerts(prev: readonly Alert[], next: readonly Alert[]): Alert[] {
  const before = new Map(prev.map((a) => [a.id, a]));
  return next.filter((a) => {
    if (a.acknowledged || isRecovered(a)) return false;
    const old = before.get(a.id);
    return !old || old.acknowledged || old.since !== a.since || old.severity !== a.severity;
  });
}

export interface Pill {
  text: string;
  tone: 'crit' | 'warn' | 'ok';
  /** What it counts, for the phone's icon-and-number form. */
  kind: 'critical' | 'warning' | 'recovered' | 'auth';
  count: number;
}

/**
 * A group header's pills (`_GroupHeaderRow`): its unacknowledged alerts by
 * severity and the returned signals; auth errors (not an alert) only when
 * nothing else is wrong.
 */
export function groupPills(members: readonly Projector[], alerts: readonly Alert[]): Pill[] {
  const ids = new Set(members.map((p) => p.id));
  const c = countAlerts(alerts.filter((a) => ids.has(a.projectorId)));
  const auth = members.filter((p) => p.connection === 'unauthorized').length;
  const pills: Pill[] = [];
  if (c.critical > 0) {
    pills.push({
      text: `${c.critical} critical`,
      tone: 'crit',
      kind: 'critical',
      count: c.critical,
    });
  }
  if (c.warning > 0) {
    pills.push({ text: `${c.warning} warning`, tone: 'warn', kind: 'warning', count: c.warning });
  }
  if (c.recovered > 0) {
    pills.push({
      text: `${c.recovered} recovered`,
      tone: 'ok',
      kind: 'recovered',
      count: c.recovered,
    });
  }
  if (c.critical + c.warning === 0 && auth > 0) {
    pills.push({
      text: `${auth} auth error${auth === 1 ? '' : 's'}`,
      tone: 'warn',
      kind: 'auth',
      count: auth,
    });
  }
  return pills;
}

/** The touch pill above the cards; null when nothing waits. */
export function alertPill(
  alerts: readonly Alert[],
): { tone: 'critical' | 'warning' | 'recovered'; text: string; extra: string | null } | null {
  const c = countAlerts(alerts);
  const open = c.critical + c.warning;
  if (open === 0 && c.recovered === 0) return null;
  const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;
  if (open === 0) {
    return {
      tone: 'recovered',
      text: `Signal back on ${plural(c.recovered, 'projector')}`,
      extra: null,
    };
  }
  return {
    tone: c.critical > 0 ? 'critical' : 'warning',
    text: `${open} new ${open === 1 ? 'alert' : 'alerts'}`,
    extra: c.recovered > 0 ? `${c.recovered} signal back` : null,
  };
}

/** Which way a cell is tinted by its projector's active alert (`warm` / `hot` like the thresholds). */
export function alertTint(alerts: readonly Alert[], rule: AlertRule): 'warm' | 'hot' | null {
  const a = alerts.find((x) => x.rule === rule);
  return a ? (a.severity === 'critical' ? 'hot' : 'warm') : null;
}

/** The Signal cell goes red while the signal is really gone (not once it came back). */
export const signalLost = (alerts: readonly Alert[]): boolean =>
  alerts.some((a) => a.rule === 'signal-lost' && !isRecovered(a));
