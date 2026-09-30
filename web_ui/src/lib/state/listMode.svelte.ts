import { device } from './device.svelte';

export type ListMode = 'table' | 'cards';

const KEY = 'pg.listMode.v1';

function read(): ListMode | null {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'table' || v === 'cards' ? v : null;
  } catch {
    return null;
  }
}

/**
 * Table or cards. Phones and portrait tablets always get cards; elsewhere the
 * choice is remembered per browser — until one is made, touch screens start
 * with cards and mouse screens with the table.
 */
class ListModeState {
  #chosen = $state<ListMode | null>(read());

  readonly value: ListMode = $derived(
    device.cardsOnly ? 'cards' : (this.#chosen ?? (device.touch ? 'cards' : 'table')),
  );

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
