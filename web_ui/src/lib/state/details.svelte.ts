import { live } from './live.svelte';

/**
 * The projector whose details are open (WEB_UI_PLAN step 13, Phase 4): in the
 * Control panel's place on side-panel layouts, a bottom sheet on touch ones.
 * The Map keeps its own popover.
 */
class DetailsState {
  id = $state<string | null>(null);
  /** The view's order when the details opened, for Preview's ◀ ▶. */
  order = $state<string[]>([]);
  readonly projector = $derived(live.projectors.find((p) => p.id === this.id));

  /** A second click on the open projector closes the details. */
  toggle(id: string, order: readonly string[]): void {
    if (this.id === id) {
      this.close();
      return;
    }
    this.id = id;
    this.order = [...order];
  }

  close(): void {
    this.id = null;
  }
}

export const details = new DetailsState();
