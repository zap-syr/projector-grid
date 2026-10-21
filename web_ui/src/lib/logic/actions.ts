import type { Action, LensAxis } from '../api/types';

export type LensSpeed = 'slow' | 'normal' | 'fast';

export const act = {
  power: (on: boolean): Action => ({ power: on ? 'on' : 'off' }),
  shutter: (open: boolean): Action => ({ shutter: open ? 'open' : 'close' }),
  testPattern: (code: string): Action => ({ testPattern: code }),
  osd: (on: boolean): Action => ({ osd: on ? 'on' : 'off' }),
  input: (code: string): Action => ({ input: code }),
  lensCalibration: (code: string): Action => ({ lensCalibration: code }),
  lensType: (code: string): Action => ({ lensType: code }),
  lensHome: (): Action => ({ lens: 'home' }),
  /** `plus` = right / up / far / in. */
  lensStep: (axis: LensAxis, plus: boolean, speed: LensSpeed): Action => ({
    lens: axis,
    dir: plus ? '+' : '-',
    speed,
  }),
};

export const isLensStep = (a: Action): boolean => 'dir' in a;

export interface Confirmation {
  title: string;
  /** What the dialog asks, e.g. "Close the shutter on 5 projectors?". */
  question: string;
  confirmLabel: string;
  /** Red confirm button: power off, shutter close. */
  danger: boolean;
  /** IPs of the selected projectors the search or a filter hides; they get it too. */
  hidden: readonly string[];
}

/** "1 projector" / "5 projectors". */
export const projectorCount = (n: number): string => `${n} projector${n === 1 ? '' : 's'}`;

/**
 * Whether [a] needs a confirm dialog for [count] targets (ROADMAP §5):
 * power, lens home, lens calibration and lens type always; shutter, test
 * pattern and input only for more than one projector; OSD and lens steps
 * never (a dialog per nudge would make the lens unusable). While some of the
 * selection is [hidden] by the search or a filter, every one but the lens
 * steps asks first and names them (owner, 2026-10-21). [codeLabel] names a
 * pattern / input / lens code from the config lists.
 */
export function confirmationFor(
  a: Action,
  count: number,
  codeLabel: (code: string) => string,
  hidden: readonly string[] = [],
): Confirmation | null {
  const c = ask(a, count, codeLabel, hidden.length > 0);
  return c && { ...c, hidden };
}

function ask(
  a: Action,
  count: number,
  codeLabel: (code: string) => string,
  always: boolean,
): Omit<Confirmation, 'hidden'> | null {
  const on = projectorCount(count);
  if ('osd' in a) {
    if (!always) return null;
    return {
      title: a.osd === 'on' ? 'OSD on' : 'OSD off',
      question: `Turn the OSD ${a.osd} on ${on}?`,
      confirmLabel: a.osd === 'on' ? 'Turn on' : 'Turn off',
      danger: false,
    };
  }
  if ('input' in a) {
    if (count <= 1 && !always) return null;
    const input = codeLabel(a.input);
    return {
      title: 'Switch input',
      question: `Switch ${on} to ${input}?`,
      confirmLabel: 'Switch',
      danger: false,
    };
  }
  if ('lensCalibration' in a) {
    return {
      title: 'Lens calibration',
      question: `Run lens calibration (${codeLabel(a.lensCalibration)}) on ${on}? The lenses will move.`,
      confirmLabel: 'Calibrate',
      danger: false,
    };
  }
  if ('lensType' in a) {
    return {
      title: 'Lens type',
      question: `Set the lens type to ${codeLabel(a.lensType)} on ${on}?`,
      confirmLabel: 'Set',
      danger: false,
    };
  }
  if ('power' in a) {
    return a.power === 'on'
      ? { title: 'Power on', question: `Power on ${on}?`, confirmLabel: 'Power on', danger: false }
      : {
          title: 'Standby',
          question: `Put ${on} in standby?`,
          confirmLabel: 'Standby',
          danger: true,
        };
  }
  if ('shutter' in a) {
    if (count <= 1 && !always) return null;
    return a.shutter === 'open'
      ? {
          title: 'Open shutter',
          question: `Open the shutter on ${on}?`,
          confirmLabel: 'Open',
          danger: false,
        }
      : {
          title: 'Close shutter',
          question: `Close the shutter on ${on}?`,
          confirmLabel: 'Close',
          danger: true,
        };
  }
  if ('testPattern' in a) {
    if (count <= 1 && !always) return null;
    return a.testPattern === 'OTS:00'
      ? {
          title: 'Test pattern off',
          question: `Turn the test pattern off on ${on}?`,
          confirmLabel: 'Turn off',
          danger: false,
        }
      : {
          title: 'Test pattern',
          question: `Show ${codeLabel(a.testPattern)} on ${on}?`,
          confirmLabel: 'Show',
          danger: false,
        };
  }
  if (!isLensStep(a)) {
    return {
      title: 'Lens home',
      question: `Move the lens to its home position on ${on}?`,
      confirmLabel: 'Move lenses',
      danger: false,
    };
  }
  return null;
}
