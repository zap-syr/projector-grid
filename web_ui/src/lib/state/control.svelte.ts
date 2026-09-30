import { api, ApiError } from '../api/client';
import type { Action, DispatchResult } from '../api/types';
import { type Confirmation, confirmationFor, isLensStep } from '../logic/actions';
import { selection } from './selection.svelte';

interface Pending {
  action: Action;
  ids: string[];
  confirmation: Confirmation;
}

export interface Toast {
  text: string;
  ok: boolean;
}

/** Sends operator actions to the selection, via the confirm dialog when the rules ask. */
class ControlState {
  pending = $state<Pending | null>(null);
  toast = $state<Toast | null>(null);
  #toastTimer: ReturnType<typeof setTimeout> | undefined;

  /** [codeLabel] names a pattern / input / lens code in the confirm question. */
  request(action: Action, codeLabel: (code: string) => string): void {
    const ids = selection.projectors.map((p) => p.id);
    if (ids.length === 0) return;
    const confirmation = confirmationFor(action, ids.length, codeLabel);
    if (confirmation) {
      this.pending = { action, ids, confirmation };
    } else {
      void this.#send(action, ids);
    }
  }

  confirm(): void {
    const p = this.pending;
    this.pending = null;
    if (p) void this.#send(p.action, p.ids);
  }

  cancel(): void {
    this.pending = null;
  }

  async #send(action: Action, ids: string[]): Promise<void> {
    let result: DispatchResult;
    try {
      result = await api.act({ targets: ids, action });
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      // 403/404: control was locked or switched off meanwhile; the access
      // event updates the page, this just explains why nothing happened.
      this.notify({ text: 'Not sent — control is locked', ok: false });
      return;
    }
    const allOk = result.failed.length === 0 && result.skipped.length === 0;
    // A held lens button fires every few hundred ms; only a problem is worth a toast.
    if (isLensStep(action) && allOk) return;
    this.notify({ text: result.summary, ok: allOk });
  }

  notify(t: Toast): void {
    this.toast = t;
    clearTimeout(this.#toastTimer);
    this.#toastTimer = setTimeout(() => (this.toast = null), t.ok ? 3500 : 7000);
  }
}

export const control = new ControlState();
