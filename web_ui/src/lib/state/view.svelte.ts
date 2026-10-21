import { matchesFilter, matchesSearch, type StatusFilter } from '../logic/rows';
import { listMode } from './listMode.svelte';
import { live } from './live.svelte';
import { selection } from './selection.svelte';

/** Quick filter and search. Not persisted: a reload shows everything. */
class ViewState {
  filter = $state<StatusFilter>('all');
  search = $state('');

  /** What the table and the cards list (the Map dims the rest instead). */
  readonly shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, this.filter) && matchesSearch(p, this.search)),
  );

  /**
   * Selected projectors the search or a quick filter took out of the table or
   * the cards. They stay selected and get every command (owner, 2026-10-21);
   * tiles the Map dims are still on screen, so they don't count.
   */
  readonly hiddenSelected = $derived.by(() => {
    if (listMode.value === 'map' || selection.ids.size === 0) return [];
    const shown = new Set(this.shown.map((p) => p.id));
    return live.projectors.filter((p) => selection.ids.has(p.id) && !shown.has(p.id));
  });

  /** A filter is picked like a tab; picking it again goes back to All. */
  toggleFilter(f: StatusFilter): void {
    this.filter = this.filter === f ? 'all' : f;
  }

  /** *4 hidden* / *Show all*: the selection stays, the search and filter go. */
  showAll(): void {
    this.filter = 'all';
    this.search = '';
  }
}

export const view = new ViewState();
