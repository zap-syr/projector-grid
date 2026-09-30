/** Phones and touch tablets get the on-screen PIN pad instead of a text field. */
const PIN_PAD = '(max-width: 600px), (pointer: coarse)';
/** Phone-width screens get the compact controls (see WEB_UI_PLAN step 8). */
const PHONE = '(max-width: 600px)';

function watch(query: string, set: (matches: boolean) => void): void {
  if (typeof matchMedia === 'undefined') return;
  const mq = matchMedia(query);
  set(mq.matches);
  mq.addEventListener('change', (e) => set(e.matches));
}

class DeviceState {
  pinPad = $state(false);
  phone = $state(false);

  constructor() {
    watch(PIN_PAD, (m) => (this.pinPad = m));
    watch(PHONE, (m) => (this.phone = m));
  }
}

export const device = new DeviceState();
