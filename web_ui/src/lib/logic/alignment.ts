import type { Alignment, AlignmentRole, Config, Projector } from '../api/types';

/** The mode's projectors in layout order (the API sends projectors that way). */
export function scopeOrder(projectors: readonly Projector[], a: Alignment | null): Projector[] {
  if (!a?.active) return [];
  return projectors.filter((p) => a.roles[p.id] !== undefined);
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
