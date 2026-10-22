/** Phones and touch tablets get the on-screen PIN pad instead of a text field. */
const PIN_PAD = '(max-width: 600px), (pointer: coarse)';
const PHONE = '(max-width: 600px)';
const TOUCH = '(pointer: coarse)';
/** A phone turned sideways: too short for a bottom sheet. */
const SHORT = '(max-height: 500px) and (pointer: coarse)';
/** A tablet held sideways (or bigger) has room for the table. */
const WIDE = '(min-width: 1024px)';
const PORTRAIT = '(orientation: portrait)';

function watch(query: string, set: (matches: boolean) => void): void {
  if (typeof matchMedia === 'undefined') return;
  const mq = matchMedia(query);
  set(mq.matches);
  mq.addEventListener('change', (e) => set(e.matches));
}

/** Where the operator's Control panel goes (WEB_UI_PLAN step 8). */
export type ControlPlacement = 'side' | 'bottom' | 'right';

export interface Screen {
  phone: boolean;
  short: boolean;
  touch: boolean;
  wide: boolean;
  portrait: boolean;
}

/** Phones and portrait tablets always show cards; the rest can pick. */
export const cardsOnly = (s: Screen): boolean => s.phone || s.short || (s.touch && !s.wide);

/** Map needs a tablet's room; phones, either way up, don't get it. */
export const mapAllowed = (s: Screen): boolean => !s.phone && !s.short;

/**
 * A bottom sheet on phones and portrait tablets, a right-hand sheet on a
 * phone held sideways (too short for a bottom one), the side panel otherwise.
 * An upright touch screen gets the sheet whatever its width: a 13" iPad Pro
 * shows the table, and a 344 px side panel would leave it ~630 px.
 */
export function controlPlacement(s: Screen): ControlPlacement {
  if (s.phone) return 'bottom';
  if (s.short) return 'right';
  return s.touch && (!s.wide || s.portrait) ? 'bottom' : 'side';
}

class DeviceState implements Screen {
  pinPad = $state(false);
  /** Phone portrait width. */
  phone = $state(false);
  /** A touch screen: big lens buttons, larger hit areas. */
  touch = $state(false);
  /** Phone landscape. */
  short = $state(false);
  wide = $state(false);
  portrait = $state(false);
  /** Script-driven transitions skip tokens.css's reduced-motion rule. */
  reduceMotion = $state(false);

  readonly cardsOnly = $derived(cardsOnly(this));
  readonly mapAllowed = $derived(mapAllowed(this));
  readonly control: ControlPlacement = $derived(controlPlacement(this));

  constructor() {
    watch(PIN_PAD, (m) => (this.pinPad = m));
    watch(PHONE, (m) => (this.phone = m));
    watch(TOUCH, (m) => (this.touch = m));
    watch(SHORT, (m) => (this.short = m));
    watch(WIDE, (m) => (this.wide = m));
    watch(PORTRAIT, (m) => (this.portrait = m));
    watch('(prefers-reduced-motion: reduce)', (m) => (this.reduceMotion = m));
  }
}

export const device = new DeviceState();
