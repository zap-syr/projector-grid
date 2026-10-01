import type { PreviewStatus, Projector } from '../api/types';

/**
 * The frame round the image, as the projector's own web preview draws it:
 * green with the shutter open, red closed, neutral while not on.
 */
export function frameColor(p: Projector | undefined): string {
  if (!p || p.power !== 'on') return 'var(--line-strong)';
  return p.shutter === 'open' ? '#6cff6c' : '#ff5f56';
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
