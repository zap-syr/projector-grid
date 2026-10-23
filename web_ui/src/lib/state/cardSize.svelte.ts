import { device } from './device.svelte';

export type CardSize = 'compact' | 'extended';

const KEY = 'pg.cardSize.v1';

function read(): CardSize | null {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'compact' || v === 'extended' ? v : null;
  } catch {
    return null;
  }
}

/**
 * Compact or Extended cards (WEB_UI_PLAN step 14), remembered per browser.
 * Until one is picked, phones either way up start Compact, the rest Extended.
 */
class CardSizeState {
  #chosen = $state<CardSize | null>(read());

  readonly value: CardSize = $derived(
    this.#chosen ?? (device.phone || device.short ? 'compact' : 'extended'),
  );

  set(size: CardSize): void {
    this.#chosen = size;
    try {
      localStorage.setItem(KEY, size);
    } catch {
      // No storage: the choice lasts until reload.
    }
  }
}

export const cardSize = new CardSizeState();
