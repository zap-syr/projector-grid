import { untrack } from 'svelte';

import { api, ApiError } from '../api/client';
import { connectPreview } from '../api/events';
import type { PreviewStatus } from '../api/types';
import { stepped } from '../logic/preview';
import { control } from './control.svelte';
import { live } from './live.svelte';

/**
 * The Remote Preview window (ROADMAP §5 *Remote Preview on the web*): one
 * projector at a time, ◀ ▶ through the order of the view it was opened from.
 * The app relays the projector's feed; this page only watches it.
 */
class PreviewState {
  /** Frozen when the window opens, so a live sort can't reshuffle ◀ ▶. */
  order = $state<string[]>([]);
  index = $state(0);
  readonly id = $derived(this.order[this.index] ?? null);
  readonly projector = $derived(live.projectors.find((p) => p.id === this.id));
  /** Null until the stream's first status. */
  status = $state<PreviewStatus | null>(null);
  /** The latest image as a data URL. */
  image = $state<string | null>(null);
  /** The stream was refused or the projector is known offline. */
  unavailable = $state(false);
  #close: (() => void) | null = null;

  open(order: readonly string[], id: string): void {
    this.order = order.includes(id) ? [...order] : [id];
    this.index = this.order.indexOf(id);
    this.#watch();
  }

  close(): void {
    this.#stop();
    this.order = [];
    this.index = 0;
  }

  step(by: 1 | -1): void {
    if (this.order.length < 2) return;
    this.index = stepped(this.index, this.order.length, by);
    this.#watch();
  }

  /** The plane's *Retry*: an offline projector is dialled anyway, as in the app. */
  retry(): void {
    const id = this.id;
    if (!id) return;
    if (!this.#close) {
      this.#connect(id);
      return;
    }
    this.status = null;
    api.previewRetry(id).catch(() => this.#connect(id));
  }

  setPreShow(on: boolean): void {
    const id = this.id;
    if (!id) return;
    api.previewPreShow(id, on).catch((e: unknown) => {
      if (!(e instanceof ApiError)) throw e;
      control.notify({
        text:
          e.status === 400
            ? 'Pre-show needs Standby and a live preview'
            : 'Not sent — control is locked',
        ok: false,
      });
    });
  }

  /**
   * A known-offline projector isn't dialled — its socket would only time out
   * — until Retry, like the app's viewport. Decided when it's shown, so a
   * telemetry blip mid-stream doesn't cut a working feed.
   */
  #watch(): void {
    this.#stop();
    const id = this.id;
    if (!id) return;
    const offline = untrack(() => this.projector?.connection === 'offline');
    if (offline) this.unavailable = true;
    else this.#connect(id);
  }

  #connect(id: string): void {
    this.#stop();
    this.#close = connectPreview(id, {
      status: (s) => {
        this.status = s;
        this.unavailable = false;
        if (s.state !== 'live') this.image = null;
      },
      frame: (f) => (this.image = `data:image/jpeg;base64,${f.jpeg}`),
      lost: (refused) => {
        // The browser reconnects on its own (the app restarting, a blip);
        // the next status picks up from there.
        this.status = null;
        this.image = null;
        if (refused) {
          this.#stop();
          this.unavailable = true;
        }
      },
    });
  }

  #stop(): void {
    this.#close?.();
    this.#close = null;
    this.status = null;
    this.image = null;
    this.unavailable = false;
  }
}

export const preview = new PreviewState();
