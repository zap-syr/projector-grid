<!--
  The Map: every projector where it sits on the app's Controls canvas.
  Mouse: click / Ctrl-click / marquee like the app's canvas, Ctrl + wheel
  zooms. Touch: tap toggles, one finger draws a marquee that adds, two
  fingers pan and pinch. Viewers pan with a one-finger or mouse drag.
-->
<script lang="ts">
  import { tick } from 'svelte';

  import type { Config } from '../../api/types';
  import { testPatternLabel } from '../../logic/cells';
  import {
    clampZoom,
    fitZoom,
    mapBounds,
    type MarqueeMode,
    marqueeSelection,
    type Rect,
    rectFrom,
    scrollFor,
    stageOffset,
    tileSelection,
    ZOOM_STEP,
  } from '../../logic/map';
  import { matchesFilter, matchesSearch } from '../../logic/rows';
  import { live } from '../../state/live.svelte';
  import { alignment } from '../../state/alignment.svelte';
  import { selection } from '../../state/selection.svelte';
  import { view } from '../../state/view.svelte';
  import Icon from '../Icon.svelte';
  import MapDetails from './MapDetails.svelte';
  import MapTile from './MapTile.svelte';

  let { config, operator }: { config: Config; operator: boolean } = $props();

  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const patternLabel = (code: string) => testPatternLabel(code, patterns);
  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));
  const shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search)),
  );
  const shownIds = $derived(new Set(shown.map((p) => p.id)));

  /** Below this the tile text is too small to read, so tiles go compact. */
  const COMPACT_BELOW = 0.6;
  /** Movement that turns a press into a drag, px. */
  const SLOP = 6;
  const LONG_PRESS_MS = 500;

  let scroller = $state<HTMLElement>();
  let viewW = $state(0);
  let viewH = $state(0);
  const bounds = $derived(mapBounds(live.projectors));
  const fit = $derived(fitZoom(bounds, viewW, viewH));
  /** Null while fitted: the wall then refits when the area or layout changes. */
  let manual = $state<number | null>(null);
  const zoom = $derived(manual === null ? fit : clampZoom(manual, fit));

  function trackSize(el: HTMLElement) {
    const ro = new ResizeObserver(() => {
      viewW = el.clientWidth;
      viewH = el.clientHeight;
    });
    ro.observe(el);
    return () => ro.disconnect();
  }

  /** A point on screen → canvas px. */
  function toCanvas(clientX: number, clientY: number) {
    const el = scroller as HTMLElement;
    const r = el.getBoundingClientRect();
    const ox = stageOffset(el.clientWidth, bounds.w * zoom);
    const oy = stageOffset(el.clientHeight, bounds.h * zoom);
    return {
      x: bounds.x + (el.scrollLeft + clientX - r.left - ox) / zoom,
      y: bounds.y + (el.scrollTop + clientY - r.top - oy) / zoom,
    };
  }

  /** Zooms so canvas point `c` stays under screen point (`sx`, `sy`). */
  async function zoomAt(z: number, c: { x: number; y: number }, sx: number, sy: number) {
    const el = scroller as HTMLElement;
    const r = el.getBoundingClientRect();
    manual = z;
    await tick();
    el.scrollLeft = scrollFor(c.x, sx - r.left, z, bounds.x, el.clientWidth, bounds.w);
    el.scrollTop = scrollFor(c.y, sy - r.top, z, bounds.y, el.clientHeight, bounds.h);
  }

  function zoomBy(factor: number) {
    const r = (scroller as HTMLElement).getBoundingClientRect();
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    void zoomAt(clampZoom(zoom * factor, fit), toCanvas(cx, cy), cx, cy);
  }

  // Ctrl + wheel zooms at the pointer (a trackpad pinch arrives the same way);
  // needs a non-passive listener to keep the browser from zooming the page.
  function wheelZoom(el: HTMLElement) {
    const onWheel = (e: WheelEvent) => {
      if (!e.ctrlKey && !e.metaKey) return;
      e.preventDefault();
      const factor = Math.min(1.5, Math.max(1 / 1.5, Math.exp(-e.deltaY * 0.002)));
      void zoomAt(
        clampZoom(zoom * factor, fit),
        toCanvas(e.clientX, e.clientY),
        e.clientX,
        e.clientY,
      );
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }

  // --- Details popover ---
  let openId = $state<string | null>(null);
  let anchor = $state<DOMRect | null>(null);
  const openProjector = $derived(live.projectors.find((p) => p.id === openId));

  function tileEl(id: string) {
    return scroller?.querySelector<HTMLElement>(`[data-id="${CSS.escape(id)}"]`) ?? null;
  }

  function openDetails(id: string) {
    const el = tileEl(id);
    if (!el) return;
    anchor = el.getBoundingClientRect();
    openId = id;
  }

  const closeDetails = () => (openId = null);

  // --- Pointer gestures ---
  type Point = { x: number; y: number };
  type Gesture =
    | { kind: 'press'; start: Point; touch: boolean; toggle: boolean; timer?: number }
    | { kind: 'marquee'; from: Point; mode: MarqueeMode; base: Set<string> }
    | { kind: 'pan'; start: Point; left: number; top: number }
    | { kind: 'pinch'; dist: number; zoom: number; centre: Point }
    | { kind: 'done' };

  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- gesture bookkeeping, never rendered
  const pointers = new Map<number, Point>();
  let gesture: Gesture | null = null;
  /** Set by a drag, pinch or long press so the click that follows does nothing. */
  let swallowClick = false;
  let lastPointer = 'mouse';
  let marquee = $state<Rect | null>(null);

  const tileId = (t: EventTarget | null) =>
    (t as Element | null)?.closest<HTMLElement>('[data-id]')?.dataset.id ?? null;

  function endGesture() {
    if (gesture?.kind === 'press') clearTimeout(gesture.timer);
    gesture = null;
    marquee = null;
  }

  function pinchState(): { dist: number; mid: Point } {
    const [a, b] = [...pointers.values()] as [Point, Point];
    return {
      dist: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)),
      mid: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 },
    };
  }

  function onpointerdown(e: PointerEvent) {
    const el = scroller as HTMLElement;
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    // A press on the scrollbars scrolls, nothing else.
    if (e.target === el && (e.offsetX >= el.clientWidth || e.offsetY >= el.clientHeight)) return;
    lastPointer = e.pointerType;
    const touch = e.pointerType !== 'mouse';
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (touch && pointers.size === 2) {
      // A second finger: drop the one-finger gesture (and a marquee's changes).
      if (gesture?.kind === 'marquee') selection.set(gesture.base);
      endGesture();
      const { dist, mid } = pinchState();
      gesture = { kind: 'pinch', dist, zoom, centre: toCanvas(mid.x, mid.y) };
      swallowClick = true;
      return;
    }
    if (pointers.size > 1) return;

    swallowClick = false;
    const id = tileId(e.target);
    const press: Gesture = {
      kind: 'press',
      start: { x: e.clientX, y: e.clientY },
      touch,
      toggle: e.ctrlKey || e.metaKey || e.shiftKey,
    };
    // The operator's taps select, so a long press opens the details.
    if (touch && operator && id) {
      press.timer = window.setTimeout(() => {
        openDetails(id);
        swallowClick = true;
        gesture = { kind: 'done' };
      }, LONG_PRESS_MS);
    }
    gesture = press;
  }

  function onpointermove(e: PointerEvent) {
    if (!pointers.has(e.pointerId)) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    const el = scroller as HTMLElement;
    const g = gesture;
    if (!g) return;

    if (g.kind === 'pinch') {
      if (pointers.size < 2) return;
      const { dist, mid } = pinchState();
      void zoomAt(clampZoom((g.zoom * dist) / g.dist, fit), g.centre, mid.x, mid.y);
      return;
    }
    if (g.kind === 'press') {
      if (Math.hypot(e.clientX - g.start.x, e.clientY - g.start.y) < SLOP) return;
      clearTimeout(g.timer);
      el.setPointerCapture(e.pointerId);
      swallowClick = true;
      closeDetails();
      // In Alignment mode there's nothing to marquee: the selection is the focus.
      gesture =
        operator && !alignment.active
          ? {
              kind: 'marquee',
              from: toCanvas(g.start.x, g.start.y),
              mode: g.touch ? 'add' : g.toggle ? 'toggle' : 'replace',
              base: new Set(selection.ids),
            }
          : { kind: 'pan', start: g.start, left: el.scrollLeft, top: el.scrollTop };
    }
    const now = gesture;
    if (now?.kind === 'marquee') {
      const to = toCanvas(e.clientX, e.clientY);
      marquee = rectFrom(now.from.x, now.from.y, to.x, to.y);
      selection.set(marqueeSelection(marquee, shown, now.base, now.mode));
    } else if (now?.kind === 'pan') {
      el.scrollLeft = now.left - (e.clientX - now.start.x);
      el.scrollTop = now.top - (e.clientY - now.start.y);
    }
  }

  function onpointerup(e: PointerEvent) {
    if (!pointers.delete(e.pointerId)) return;
    if (gesture?.kind === 'pinch' && pointers.size > 0) {
      // The finger left behind does nothing until it lifts too.
      gesture = { kind: 'done' };
      return;
    }
    if (pointers.size === 0) endGesture();
  }

  function onclick(e: MouseEvent) {
    if (swallowClick) {
      swallowClick = false;
      return;
    }
    // A keyboard press (detail 0) acts like the mouse.
    const touch = e.detail !== 0 && lastPointer !== 'mouse';
    const id = tileId(e.target);
    if (id === null) {
      // Empty space: the app clears the selection; a finger that just missed
      // a tile shouldn't.
      if (operator && !touch && !alignment.active) selection.clear();
      return;
    }
    const p = live.projectors.find((x) => x.id === id);
    if (!p) return;
    if (!operator) {
      if (openId === id) closeDetails();
      else openDetails(id);
      return;
    }
    // Alignment mode: a tile in the mode takes the focus, like a card click in the app.
    if (alignment.active) {
      if (alignment.role(id)) alignment.focus(id);
      return;
    }
    selection.set(tileSelection(p, selection.ids, touch || e.ctrlKey || e.metaKey || e.shiftKey));
  }

  // A mouse press (right-click too) doesn't focus the tile: otherwise the next
  // key, Esc closing the details, makes the browser show its keyboard focus
  // ring on it. Tab still focuses tiles.
  function onmousedown(e: MouseEvent) {
    if (tileId(e.target)) e.preventDefault();
  }

  function oncontextmenu(e: MouseEvent) {
    const id = tileId(e.target);
    if (id === null) return;
    // Right-click, or a long press on Android: the details, not the browser menu.
    e.preventDefault();
    swallowClick = lastPointer !== 'mouse';
    openDetails(id);
  }
</script>

<div class="map">
  {#if live.projectors.length === 0}
    <p class="empty">No projectors in this project</p>
  {:else}
    <!-- Pointer handling lives on the scroller so a drag can start anywhere;
         each tile is a real button, so the keyboard works too. -->
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div
      class="scroller"
      bind:this={scroller}
      {@attach trackSize}
      {@attach wheelZoom}
      {onpointerdown}
      {onpointermove}
      {onpointerup}
      onpointercancel={onpointerup}
      {onclick}
      {onmousedown}
      {oncontextmenu}
      onscroll={closeDetails}
    >
      <div class="stage" style:width="{bounds.w * zoom}px" style:height="{bounds.h * zoom}px">
        <div
          class="plane"
          style:width="{bounds.w}px"
          style:height="{bounds.h}px"
          style:transform="scale({zoom})"
        >
          {#each live.projectors as p (p.id)}
            <MapTile
              {p}
              group={p.groupId ? groupMap.get(p.groupId) : undefined}
              origin={bounds}
              {patternLabel}
              {operator}
              selected={selection.ids.has(p.id)}
              dim={!shownIds.has(p.id)}
              compact={zoom < COMPACT_BELOW}
              role={alignment.role(p.id)}
              outside={alignment.active && !alignment.role(p.id)}
            />
          {/each}
        </div>
        {#if marquee}
          <div
            class="marquee"
            style:left="{(marquee.x - bounds.x) * zoom}px"
            style:top="{(marquee.y - bounds.y) * zoom}px"
            style:width="{marquee.w * zoom}px"
            style:height="{marquee.h * zoom}px"
          ></div>
        {/if}
      </div>
    </div>
    <div class="zoom" role="group" aria-label="Zoom">
      <button aria-label="Zoom out" onclick={() => zoomBy(1 / ZOOM_STEP)}>
        <Icon name="minus" size={16} />
      </button>
      <span class="pct">{Math.round(zoom * 100)}%</span>
      <button aria-label="Zoom in" onclick={() => zoomBy(ZOOM_STEP)}>
        <Icon name="plus" size={16} />
      </button>
      <button class="fit" aria-pressed={manual === null} onclick={() => (manual = null)}>Fit</button
      >
    </div>
  {/if}
  {#if openProjector && anchor}
    <MapDetails
      p={openProjector}
      {config}
      groups={groupMap}
      {patternLabel}
      {anchor}
      onclose={closeDetails}
    />
  {/if}
</div>

<style>
  .map {
    position: relative;
    height: 100%;
  }

  .scroller {
    height: 100%;
    overflow: auto;
    display: grid;
    background:
      radial-gradient(circle, var(--line) 1px, transparent 1.5px) 0 0 / 20px 20px,
      var(--app);
    /* Touch gestures are ours: one finger is the marquee, two pan and zoom. */
    touch-action: none;
    user-select: none;
    -webkit-user-select: none;
    -webkit-touch-callout: none;
    overscroll-behavior: contain;
  }

  /* Auto margins centre a wall smaller than the view and fall to 0 when it's bigger. */
  .stage {
    position: relative;
    margin: auto;
  }

  .plane {
    position: absolute;
    top: 0;
    left: 0;
    transform-origin: 0 0;
  }

  .marquee {
    position: absolute;
    border: 1px solid var(--accent);
    background: color-mix(in srgb, var(--accent) 12%, transparent);
    pointer-events: none;
  }

  .zoom {
    position: absolute;
    right: 16px;
    bottom: 16px;
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 3px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 10px;
    box-shadow: var(--sh-2);
  }

  .zoom button {
    min-width: 34px;
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 7px;
    background: none;
    color: var(--muted);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  .zoom button:hover {
    background: var(--hover);
    color: var(--text);
  }

  .zoom .fit {
    padding: 0 10px;
  }

  .zoom .fit[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  .pct {
    min-width: 5ch;
    font-size: 12.5px;
    font-variant-numeric: tabular-nums;
    text-align: center;
    color: var(--muted);
  }

  @media (pointer: coarse) {
    .zoom button {
      min-width: 44px;
      height: 44px;
    }
  }

  .empty {
    margin: 0;
    padding: 48px 16px;
    text-align: center;
    color: var(--faint);
  }
</style>
