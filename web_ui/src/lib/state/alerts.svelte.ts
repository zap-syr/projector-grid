import criticalSound from '../../../../assets/sounds/alert_critical.wav?url';
import warningSound from '../../../../assets/sounds/alert_warning.wav?url';
import { api, ApiError } from '../api/client';
import type { AcknowledgeRequest, Alert, Alerts } from '../api/types';
import { type AlertGrouping, countAlerts, raisedAlerts, sortAlerts } from '../logic/alerts';
import { control } from './control.svelte';

const KEY = 'pg.alerts.v1';

interface Prefs {
  /** The desktop drawer; sheets always start closed. */
  drawer: boolean;
  grouping: AlertGrouping;
  byProjectGroups: boolean;
  sound: boolean;
}

const DEFAULTS: Prefs = {
  drawer: false,
  grouping: 'projector',
  byProjectGroups: true,
  sound: false,
};

function readPrefs(): Prefs {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) ?? '{}') as Partial<Prefs>;
    return {
      drawer: typeof raw.drawer === 'boolean' ? raw.drawer : DEFAULTS.drawer,
      grouping: raw.grouping === 'alert' ? 'alert' : 'projector',
      byProjectGroups:
        typeof raw.byProjectGroups === 'boolean' ? raw.byProjectGroups : DEFAULTS.byProjectGroups,
      sound: typeof raw.sound === 'boolean' ? raw.sound : DEFAULTS.sound,
    };
  } catch {
    return { ...DEFAULTS };
  }
}

/** Alerts raised within this long of the first are one batch: one toast, one sound (as in the app). */
const BATCH_MS = 2000;
const TOAST_MS = 6000;

export interface AlertToast {
  /** The batch's most urgent alert. */
  alert: Alert;
  /** How many more came with it. */
  more: number;
}

/**
 * The app's active alerts, as the `alerts` event last reported them, plus
 * this browser's panel choices. The stream is the only writer of the list.
 */
class AlertsState {
  list = $state<Alert[]>([]);
  /** The app's clock minus this device's, so durations don't depend on the phone's clock. */
  #skew = 0;
  /** Ticks every 30 s so durations move on. */
  now = $state(new Date());
  prefs = $state<Prefs>(readPrefs());
  /** The bottom / right sheet on touch layouts. */
  sheet = $state(false);
  toast = $state<AlertToast | null>(null);
  /** Ids raised in the last batch: their rail ticks pulse. */
  fresh = $state<ReadonlySet<string>>(new Set());
  /**
   * The browser lets this page play sound. False until a tap after load, and
   * again when iOS suspends audio in the background.
   */
  audioReady = $state(false);

  /**
   * One context for every sound: iOS unlocks audio per element, so a fresh
   * `new Audio()` for each alert stayed silent there; a context resumed in a
   * tap stays unlocked.
   */
  #audio: AudioContext | null = null;
  #sounds = new Map<string, Promise<AudioBuffer>>();

  #seen = false;
  #batch: Alert[] = [];
  #batchTimer: ReturnType<typeof setTimeout> | undefined;
  #toastTimer: ReturnType<typeof setTimeout> | undefined;

  readonly byProjector: ReadonlyMap<string, Alert[]> = $derived.by(() => {
    const ids = new Set(this.list.map((a) => a.projectorId));
    return new Map([...ids].map((id) => [id, this.list.filter((a) => a.projectorId === id)]));
  });

  readonly counts = $derived(countAlerts(this.list));
  readonly unacknowledged = $derived(this.list.filter((a) => !a.acknowledged).length);

  constructor() {
    setInterval(() => (this.now = this.#appNow()), 30_000);
    // Browsers only start audio inside a tap or key press. With Sound on, the
    // first one anywhere on the page (after a reload, or after iOS suspended
    // audio) unlocks it.
    const unlock = () => {
      if (this.prefs.sound && !this.audioReady) this.#unlock();
    };
    for (const type of ['pointerdown', 'touchend', 'keydown']) {
      window.addEventListener(type, unlock, { capture: true, passive: true });
    }
    // Back from the background iOS may let the context resume without a tap.
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible' && this.#audio?.state !== 'running') {
        void this.#audio?.resume().catch(() => undefined);
      }
    });
  }

  of(projectorId: string): Alert[] {
    return this.byProjector.get(projectorId) ?? [];
  }

  #appNow(): Date {
    return new Date(Date.now() + this.#skew);
  }

  /** The `alerts` event. The first one after a (re)connect raises no cues. */
  apply(data: Alerts): void {
    this.#skew = Date.parse(data.now) - Date.now();
    this.now = this.#appNow();
    const next = sortAlerts(data.alerts);
    if (this.#seen) this.#collect(raisedAlerts(this.list, next));
    this.#seen = true;
    this.list = next;
  }

  /** The stream dropped: the next snapshot is a fresh start. */
  reset(): void {
    this.#seen = false;
  }

  #collect(raised: Alert[]): void {
    if (raised.length === 0) return;
    const first = this.#batch.length === 0;
    this.#batch.push(...raised);
    if (first) this.#batchTimer = setTimeout(() => this.#flush(), BATCH_MS);
  }

  #flush(): void {
    clearTimeout(this.#batchTimer);
    const batch = sortAlerts(this.#batch);
    this.#batch = [];
    const top = batch[0];
    if (!top) return;
    this.toast = { alert: top, more: batch.length - 1 };
    this.fresh = new Set(batch.map((a) => a.id));
    clearTimeout(this.#toastTimer);
    this.#toastTimer = setTimeout(() => {
      this.toast = null;
      this.fresh = new Set();
    }, TOAST_MS);
    if (this.prefs.sound) this.#play(top.severity === 'critical' ? criticalSound : warningSound);
  }

  /** Must run inside a tap or key press. */
  #unlock(): AudioContext {
    if (!this.#audio) {
      const ctx = new AudioContext();
      ctx.onstatechange = () => (this.audioReady = ctx.state === 'running');
      this.#audio = ctx;
    }
    const ctx = this.#audio;
    // A context made inside a tap can start out running, with no statechange.
    ctx
      .resume()
      .then(() => (this.audioReady = ctx.state === 'running'))
      .catch(() => undefined);
    // A silent sample started in the gesture: older iOS unlocks only on playback.
    const silent = ctx.createBufferSource();
    silent.buffer = ctx.createBuffer(1, 1, 22050);
    silent.connect(ctx.destination);
    silent.start();
    return ctx;
  }

  #load(ctx: AudioContext, url: string): Promise<AudioBuffer> {
    let sound = this.#sounds.get(url);
    if (!sound) {
      sound = fetch(url)
        .then((r) => r.arrayBuffer())
        .then((data) => ctx.decodeAudioData(data));
      // A failed fetch is retried next time instead of being cached.
      sound.catch(() => this.#sounds.delete(url));
      this.#sounds.set(url, sound);
    }
    return sound;
  }

  #play(url: string): void {
    const ctx = this.#audio;
    // Not unlocked yet: the Sound button says so.
    if (!ctx) return;
    this.#load(ctx, url)
      .then((buffer) => {
        const source = ctx.createBufferSource();
        source.buffer = buffer;
        source.connect(ctx.destination);
        source.start();
      })
      .catch(() => undefined);
  }

  dismissToast(): void {
    clearTimeout(this.#toastTimer);
    this.toast = null;
  }

  #save(): void {
    try {
      localStorage.setItem(KEY, JSON.stringify(this.prefs));
    } catch {
      // No storage: the choice lasts until reload.
    }
  }

  setPref<K extends keyof Prefs>(key: K, value: Prefs[K]): void {
    this.prefs[key] = value;
    this.#save();
  }

  toggleSound(): void {
    // On but still locked: the tap enables it rather than switching it off.
    // (`audioReady` only flips after the resume settles, so the page-wide
    // unlock that ran on this same press doesn't count.)
    if (this.prefs.sound && !this.audioReady) {
      this.#unlock();
      this.#play(criticalSound);
      return;
    }
    this.setPref('sound', !this.prefs.sound);
    if (this.prefs.sound) {
      // Plays a sample: proof it works, and the tap that unlocks audio.
      const ctx = this.#unlock();
      this.#play(criticalSound);
      // Decoded now, so the first warning doesn't wait for it.
      this.#load(ctx, warningSound).catch(() => undefined);
    }
  }

  /** Sound is on but the browser hasn't let it play yet. */
  get soundLocked(): boolean {
    return this.prefs.sound && !this.audioReady;
  }

  async acknowledge(req: AcknowledgeRequest): Promise<void> {
    try {
      await api.acknowledge(req);
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      // 403/404: control was locked or switched off meanwhile.
      control.notify({ text: 'Not acknowledged — control is locked', ok: false });
    }
  }
}

export const alerts = new AlertsState();
