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

  #play(url: string): void {
    // Browsers refuse sound until the page was tapped; the Sound switch is that tap.
    new Audio(url).play().catch(() => undefined);
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
    this.setPref('sound', !this.prefs.sound);
    // Plays a sample: proof it works, and the tap that unlocks audio.
    if (this.prefs.sound) this.#play(criticalSound);
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
