import type { PreviewStatus, Projector } from '../api/types';

/**
 * The frame round the image, as the projector's own web preview draws it:
 * green with the shutter open, red closed, neutral while not on.
 */
export function frameColor(p: Projector | undefined): string {
  if (!p || p.power !== 'on') return FRAME.notOn;
  return p.shutter === 'open' ? FRAME.open : FRAME.closed;
}

/** The frame's colours, also the footer's legend (`PreviewViewport.frame*`). */
export const FRAME = { open: '#6cff6c', closed: '#ff5f56', notOn: 'var(--t3)' } as const;

/** `RZ34K (192.168.0.41)`: how a dialog names one projector (`projectorLabel`). */
export const projectorLabel = (model: string, ip: string): string =>
  model === '' || model === ip ? ip : `${model} (${ip})`;

/**
 * Under *Pre-show mode*: why the switch can or can't be used, as the app's
 * card says it.
 */
export function preShowNote(p: Projector | undefined, s: PreviewStatus | null): string {
  if (p?.power === 'on') return 'Only in Standby: this projector is on';
  if (preShowReady(p, s)) {
    return 'Keeps the input alive for preview, the projector stays off. Stays on after you close this window.';
  }
  return s?.state === 'connecting'
    ? 'Connecting to the live feed'
    : 'Needs the live feed and Standby';
}

const NOTICES: Record<NonNullable<PreviewStatus['notice']>, string> = {
  noSignal: 'No signal',
  hdcp: 'HDCP-protected content',
  startingUp: 'Starting up',
  rotating: 'Image rotating',
  blank: '',
};

/** The text on the black plane instead of an image. */
export const noticeText = (s: PreviewStatus): string => (s.notice ? NOTICES[s.notice] : '');

/** The top-left tag: pre-show wins the slot, as in the app. */
export function cornerTag(s: PreviewStatus): string | null {
  if (s.preShow) return 'PRE-SHOW';
  if (s.state !== 'live') return null;
  return s.overlay === 'testPattern'
    ? 'TEST PATTERN'
    : s.overlay === 'aspectMismatch'
      ? 'ASPECT DIFFERS'
      : null;
}

/** ◀ ▶ through [length] projectors, wrapping at the ends. */
export const stepped = (index: number, length: number, by: 1 | -1): number =>
  length === 0 ? 0 : (index + by + length) % length;

/** Pre-show acts on a projector in Standby whose feed is up — as in the app. */
export const preShowReady = (p: Projector | undefined, s: PreviewStatus | null): boolean =>
  p?.power === 'standby' && (s?.state === 'live' || s?.state === 'notice');
