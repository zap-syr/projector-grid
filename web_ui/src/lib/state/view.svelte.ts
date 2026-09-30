import type { StatusFilter } from '../logic/rows';

/** Header filter and toolbar search. Not persisted: a reload shows everything. */
class ViewState {
  filter = $state<StatusFilter>('all');
  search = $state('');

  /** Clicking the active filter again goes back to All. */
  toggleFilter(f: StatusFilter): void {
    this.filter = this.filter === f ? 'all' : f;
  }
}

export const view = new ViewState();
