import { device } from './device.svelte';

export type ListMode = 'table' | 'cards' | 'map';

const KEY = 'pg.listMode.v1';

function read(): ListMode | null {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'table' || v === 'cards' || v === 'map' ? v : null;
  } catch {
    return null;
  }
}

/**
 * Table, cards or the Map. The choice is remembered per browser — until one
 * is made, touch screens start with cards and mouse screens with the table.
 * Phones only get cards; portrait tablets get cards or the Map.
 */
class ListModeState {
  #chosen = $state<ListMode | null>(read());

  readonly value: ListMode = $derived.by(() => {
    const chosen = this.#chosen;
    if (chosen === 'map' && device.mapAllowed) return 'map';
    // Where the Map isn't offered the screen is cards-only, so 'map' ends here too.
    if (device.cardsOnly) return 'cards';
    return chosen ?? (device.touch ? 'cards' : 'table');
  });

  set(mode: ListMode): void {
    this.#chosen = mode;
    try {
      localStorage.setItem(KEY, mode);
    } catch {
      // No storage: the choice lasts until reload.
    }
  }
}

export const listMode = new ListModeState();
