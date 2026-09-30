import type { Projector } from '../api/types';
import { isSelectable } from './selection';

/** The app's card size on the Controls canvas (`card_layout.dart`). */
export const CARD_W = 120;
export const CARD_H = 100;
/** Room under a card for its group chip. */
export const CHIP_H = 22;
/** Margin around the wall, in canvas px. */
export const PAD = 20;
/** The app's canvas zooms 0.5–2; fitting a big wall may go below. */
export const MIN_ZOOM = 0.5;
export const MAX_ZOOM = 2;
export const ZOOM_STEP = 1.25;

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** The wall's extent in canvas px, padded; a zero rect without projectors. */
export function mapBounds(projectors: readonly Projector[]): Rect {
  if (projectors.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
  const x0 = Math.min(...projectors.map((p) => p.x));
  const y0 = Math.min(...projectors.map((p) => p.y));
  const x1 = Math.max(...projectors.map((p) => p.x + CARD_W));
  const y1 = Math.max(...projectors.map((p) => p.y + CARD_H + CHIP_H));
  return { x: x0 - PAD, y: y0 - PAD, w: x1 - x0 + 2 * PAD, h: y1 - y0 + 2 * PAD };
}

/** The zoom that shows the whole wall in a view, capped at the app's maximum. */
export function fitZoom(bounds: Rect, viewW: number, viewH: number): number {
  if (bounds.w === 0 || viewW <= 0 || viewH <= 0) return 1;
  return Math.min(viewW / bounds.w, viewH / bounds.h, MAX_ZOOM);
}

/** Zoom limits: never smaller than what fits, unless that's below the app's floor. */
export function clampZoom(zoom: number, fit: number): number {
  return Math.min(MAX_ZOOM, Math.max(Math.min(MIN_ZOOM, fit), zoom));
}

/** The wall is centred while it's smaller than the view (auto margins). */
export const stageOffset = (view: number, content: number): number =>
  Math.max(0, (view - content) / 2);

/**
 * The scroll position that keeps canvas point `c` under view point `v` at
 * `zoom` (for zooming at the pointer or the pinch midpoint).
 */
export function scrollFor(
  c: number,
  v: number,
  zoom: number,
  origin: number,
  view: number,
  size: number,
): number {
  const content = size * zoom;
  return stageOffset(view, content) + (c - origin) * zoom - v;
}

/** Rect from two corners, in either order. */
export function rectFrom(ax: number, ay: number, bx: number, by: number): Rect {
  return { x: Math.min(ax, bx), y: Math.min(ay, by), w: Math.abs(bx - ax), h: Math.abs(by - ay) };
}

/** Flutter's `Rect.overlaps`, which the app's marquee uses: touching edges don't count. */
function overlaps(r: Rect, p: Projector): boolean {
  return r.x < p.x + CARD_W && p.x < r.x + r.w && r.y < p.y + CARD_H && p.y < r.y + r.h;
}

/**
 * How a marquee changes the selection: `replace` (plain mouse drag, like
 * the app), `toggle` (with Ctrl / Cmd / Shift, like the app's append) or
 * `add` (touch, which has no modifier keys). `base` is the selection when
 * the drag started; tiles the filter dims (`shown`) are left out.
 */
export type MarqueeMode = 'replace' | 'toggle' | 'add';

export function marqueeSelection(
  rect: Rect,
  shown: readonly Projector[],
  base: ReadonlySet<string>,
  mode: MarqueeMode,
): Set<string> {
  const hits = shown.filter((p) => isSelectable(p) && overlaps(rect, p)).map((p) => p.id);
  if (mode === 'replace') return new Set(hits);
  const next = new Set(base);
  for (const id of hits) {
    if (mode === 'toggle' && base.has(id)) next.delete(id);
    else next.add(id);
  }
  return next;
}

/**
 * A click or tap on a tile: a plain mouse click selects only that tile
 * (the app's `selectOnly`); a modifier click or a touch tap toggles it.
 */
export function tileSelection(
  p: Projector,
  selected: ReadonlySet<string>,
  toggle: boolean,
): Set<string> {
  if (!isSelectable(p)) return new Set(selected);
  if (!toggle) return new Set([p.id]);
  const next = new Set(selected);
  if (next.has(p.id)) next.delete(p.id);
  else next.add(p.id);
  return next;
}

/** Black or white group-chip text, whichever reads on the colour (`estimateBrightnessForColor`). */
export function chipText(hex: string): string {
  const n = Number.parseInt(hex.slice(1, 7), 16);
  const lin = (c: number) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  const l = 0.2126 * lin((n >> 16) & 255) + 0.7152 * lin((n >> 8) & 255) + 0.0722 * lin(n & 255);
  // Flutter: light when (L + 0.05)^2 > 0.15.
  return (l + 0.05) ** 2 > 0.15 ? '#15171b' : '#fff';
}
