import { isSelectable } from '../logic/selection';
import { live } from './live.svelte';

/**
 * The operator's target set, like the app's selection. Stored ids that went
 * offline or disappeared stay out of `ids` until they're selectable again.
 */
class SelectionState {
  #raw = $state<Set<string>>(new Set());
  /** Last plain click, for Shift-click ranges. */
  anchor = $state<string | null>(null);

  readonly ids = $derived(
    new Set(live.projectors.filter((p) => isSelectable(p) && this.#raw.has(p.id)).map((p) => p.id)),
  );
  readonly projectors = $derived(live.projectors.filter((p) => this.ids.has(p.id)));

  set(ids: Set<string>): void {
    this.#raw = ids;
  }

  toggle(id: string): void {
    const ids = [...this.ids];
    this.#raw = new Set(this.ids.has(id) ? ids.filter((x) => x !== id) : [...ids, id]);
    this.anchor = id;
  }

  clear(): void {
    this.#raw = new Set();
    this.anchor = null;
  }
}

export const selection = new SelectionState();
