const KEY = 'pg.controlPanel.v1';

/**
 * Whether the operator's Control panel is shown; remembered per browser. On a
 * phone it's a bottom sheet instead, opened from the select bar each time.
 */
class PanelState {
  open = $state(true);
  sheet = $state(false);

  constructor() {
    try {
      this.open = localStorage.getItem(KEY) !== 'hidden';
    } catch {
      // No storage (private mode): the panel just starts open.
    }
  }

  toggle(): void {
    this.open = !this.open;
    try {
      localStorage.setItem(KEY, this.open ? 'shown' : 'hidden');
    } catch {
      // As above: the choice lasts until reload.
    }
  }
}

export const panel = new PanelState();
