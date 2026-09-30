import { api, ApiError } from '../api/client';
import type { AlignmentOp, AlignmentPresetId } from '../api/types';
import { roleOf, scopeOrder } from '../logic/alignment';
import { control } from './control.svelte';
import { live } from './live.svelte';
import { selection } from './selection.svelte';

/**
 * The app's Alignment mode as this page sees it (the SSE stream writes it)
 * and the operator's handle on it. The app does all the work; this only
 * sends ops (ROADMAP §5 *Alignment mode on the web*).
 */
class AlignmentState {
  readonly value = $derived(live.alignment);
  readonly active = $derived(this.value?.active ?? false);
  /** Entering or exiting: projectors are being read or restored. */
  readonly busy = $derived(this.value?.busy ?? false);
  readonly order = $derived(scopeOrder(live.projectors, this.value));
  readonly focused = $derived(
    this.active ? (live.projectors.find((p) => p.id === this.value?.focusedId) ?? null) : null,
  );

  role(id: string) {
    return roleOf(this.value, id);
  }

  /** Scope = the page's selection when it has two or more, like the app. */
  enter() {
    void this.#run('enter', { targets: [...selection.ids] });
  }

  exit() {
    void this.#run('exit');
  }

  next() {
    void this.#run('next');
  }

  prev() {
    void this.#run('prev');
  }

  focus(id: string) {
    if (id !== this.value?.focusedId) void this.#run('focus', { id });
  }

  toggle(op: 'neighbours' | 'diagonals' | 'showAll') {
    void this.#run(op);
  }

  setPreset(preset: AlignmentPresetId) {
    void this.#run('preset', { preset });
  }

  setFocusedPattern(code: string) {
    void this.#run('focusedPattern', { code });
  }

  /** null = same as focused. */
  setOthersPattern(code: string | null) {
    void this.#run('othersPattern', { code });
  }

  async #run(op: AlignmentOp, body?: Record<string, unknown>) {
    try {
      // The reply is also broadcast as an `alignment` event, which updates the page.
      await api.alignment(op, body);
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      control.notify({ text: 'Not sent — control is locked', ok: false });
    }
  }
}

export const alignment = new AlignmentState();
