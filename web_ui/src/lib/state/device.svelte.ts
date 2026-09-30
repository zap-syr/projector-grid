/** Phones and touch tablets get the on-screen PIN pad instead of a text field. */
const QUERY = '(max-width: 600px), (pointer: coarse)';

class DeviceState {
  pinPad = $state(false);

  constructor() {
    if (typeof matchMedia === 'undefined') return;
    const mq = matchMedia(QUERY);
    this.pinPad = mq.matches;
    mq.addEventListener('change', (e) => (this.pinPad = e.matches));
  }
}

export const device = new DeviceState();
