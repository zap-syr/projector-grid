import type { Alignment, AlignmentRole, AlignmentStepOrder, Config, Projector } from '../api/types';
import { sortByIp } from './sort';

/**
 * The mode's projectors in its step order. The API sends projectors in layout
 * order, and `sortByIp` is stable, so projectors sharing an address keep their
 * layout order, as in the app's `alignmentOrder`.
 */
export function scopeOrder(projectors: readonly Projector[], a: Alignment | null): Projector[] {
  if (!a?.active) return [];
  const scope = projectors.filter((p) => a.roles[p.id] !== undefined);
  return a.stepOrder === 'ip' ? sortByIp(scope) : scope;
}

/** A projector's role while the mode is on; null outside the mode or its scope. */
export function roleOf(a: Alignment | null, id: string): AlignmentRole | null {
  return a?.active ? (a.roles[id] ?? null) : null;
}

/** The patterns the current preset offers, as the app's pickers filter them. */
export function presetPatterns(config: Config, a: Alignment): string[] {
  return config.alignmentPresets.find((p) => p.id === a.preset)?.patterns ?? [];
}

/** "3 / 7" — the focused projector's place in the scope. */
export function position(order: readonly Projector[], focusedId: string | null): string {
  const i = order.findIndex((p) => p.id === focusedId);
  return `${i + 1} / ${order.length}`;
}

/** The step orders, as the app's *Step order* submenu names them. */
export const stepOrders: readonly { id: AlignmentStepOrder; label: string }[] = [
  { id: 'layout', label: 'Layout' },
  { id: 'ip', label: 'IP address' },
];
