/**
 * CSS backgrounds for the test-pattern mini swatches, keyed by `OTS:xx`. The
 * web counterpart of the app's `kTestPatternIcons` SVGs.
 */
const hatch = (line: string) =>
  `repeating-linear-gradient(0deg,${line} 0 1px,transparent 1px 5px),` +
  `repeating-linear-gradient(90deg,${line} 0 1px,transparent 1px 5px),#000`;
const bars = (dir: string) =>
  `linear-gradient(${dir},#fff 0 14%,#ff0 14% 28%,#0ff 28% 42%,#0f0 42% 57%,#f0f 57% 71%,#f00 71% 85%,#00f 85%)`;

const SWATCHES: Record<string, string> = {
  'OTS:01': '#fff',
  'OTS:02': '#000',
  'OTS:22': '#e53935',
  'OTS:23': '#43a047',
  'OTS:24': '#1e5bd8',
  'OTS:28': '#26c6da',
  'OTS:29': '#d81b60',
  'OTS:30': '#fdd835',
  'OTS:05': 'linear-gradient(#fff,#fff) center/50% 50% no-repeat,#000',
  'OTS:06': 'linear-gradient(#000,#000) center/50% 50% no-repeat,#fff',
  'OTS:08': bars('90deg'),
  'OTS:51': bars('180deg'),
  'OTS:78': 'repeating-linear-gradient(90deg,#fff 0 1px,#000 1px 2px)',
  'OTS:59': 'linear-gradient(#000,#000) center/80% 70% no-repeat,#fff',
  'OTS:07': hatch('#fff'),
  'OTS:70': hatch('#ff5252'),
  'OTS:71': hatch('#4cd964'),
  'OTS:72': hatch('#5b8cff'),
  'OTS:73': hatch('#26c6da'),
  'OTS:74': hatch('#ec407a'),
  'OTS:75': hatch('#fdd835'),
  'OTS:87': 'radial-gradient(circle,transparent 50%,#fff 51% 57%,transparent 58%),#000',
};

/**
 * The control panel's always-visible swatches (white, black, RGB, cross
 * hatches, colour bars, window, circle); *More patterns* shows the rest of the
 * app's list.
 */
export const MAIN_PATTERNS = [
  'OTS:01',
  'OTS:02',
  'OTS:22',
  'OTS:23',
  'OTS:24',
  'OTS:07',
  'OTS:70',
  'OTS:71',
  'OTS:72',
  'OTS:08',
  'OTS:05',
  'OTS:87',
];

/** Null for codes without a swatch (patterns the app doesn't list). */
export function patternSwatch(code: string): string | null {
  return SWATCHES[code] ?? null;
}

/** `isTestPatternActive` in `test_patterns.dart`. */
export function isPatternActive(code: string | null): code is string {
  return code !== null && code !== 'OTS:00';
}
