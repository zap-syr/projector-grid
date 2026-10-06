<!--
  Remote Preview (ROADMAP §5 *Remote Preview on the web*): one projector's
  live image in the frame the app draws — green / red by shutter — with its
  overlays, ◀ ▶ to the neighbouring projector, Retry, and Pre-show for an
  operator. Power sits by the name; the shutter is the frame's colour. A
  dialog on wider screens, the whole screen on a phone.
-->
<script lang="ts">
  import type { Config } from '../../api/types';
  import { testPatternLabel } from '../../logic/cells';
  import { cornerTag, frameColor, noticeText, preShowReady } from '../../logic/preview';
  import { device } from '../../state/device.svelte';
  import { live } from '../../state/live.svelte';
  import { preview } from '../../state/preview.svelte';
  import Cell from '../table/Cell.svelte';
  import Icon from '../Icon.svelte';

  let { config, operator }: { config: Config; operator: boolean } = $props();

  const p = $derived(preview.projector);
  const s = $derived(preview.status);
  const full = $derived(device.phone || device.short);
  const many = $derived(preview.order.length > 1);
  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));
  const group = $derived(p?.groupId ? groupMap.get(p.groupId) : undefined);
  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const patternLabel = (code: string) => testPatternLabel(code, patterns);

  const tag = $derived(s ? cornerTag(s) : null);
  const ready = $derived(preShowReady(p, s));
  const preShowNote = $derived(
    p?.power !== 'standby'
      ? 'Only in Standby'
      : ready
        ? 'Keeps the input alive; projector stays off'
        : 'Waiting for the preview…',
  );

  const inField = (e: KeyboardEvent) =>
    e.target instanceof HTMLInputElement ||
    e.target instanceof HTMLTextAreaElement ||
    e.target instanceof HTMLSelectElement;

  /** A finger swipe across the image steps like ◀ ▶. */
  function swipeable(el: HTMLElement) {
    let start: { x: number; y: number } | null = null;
    const down = (e: PointerEvent) => (start = { x: e.clientX, y: e.clientY });
    const cancel = () => (start = null);
    const up = (e: PointerEvent) => {
      const from = start;
      start = null;
      if (!from || e.pointerType === 'mouse') return;
      const dx = e.clientX - from.x;
      if (Math.abs(dx) > 48 && Math.abs(dx) > Math.abs(e.clientY - from.y) * 1.5) {
        preview.step(dx < 0 ? 1 : -1);
      }
    };
    el.addEventListener('pointerdown', down);
    el.addEventListener('pointerup', up);
    el.addEventListener('pointercancel', cancel);
    return () => {
      el.removeEventListener('pointerdown', down);
      el.removeEventListener('pointerup', up);
      el.removeEventListener('pointercancel', cancel);
    };
  }
</script>

<svelte:window
  onkeydowncapture={(e) => {
    if (e.key === 'Escape') {
      // Capture phase and handled: the toolbar would clear the selection.
      e.preventDefault();
      preview.close();
    } else if ((e.key === 'ArrowLeft' || e.key === 'ArrowRight') && !inField(e)) {
      e.preventDefault();
      preview.step(e.key === 'ArrowLeft' ? -1 : 1);
    }
  }}
/>

<div class="overlay" class:full>
  <button class="scrim" aria-label="Close preview" tabindex="-1" onclick={() => preview.close()}
  ></button>
  {#snippet nav()}
    <div class="nav" role="group" aria-label="Projector">
      <button aria-label="Previous projector" onclick={() => preview.step(-1)}>
        <Icon name="left" size={full ? 22 : 18} />
      </button>
      <span class="pos">{preview.index + 1} / {preview.order.length}</span>
      <button aria-label="Next projector" onclick={() => preview.step(1)}>
        <Icon name="right" size={full ? 22 : 18} />
      </button>
    </div>
  {/snippet}
  <div
    class="dialog"
    role="dialog"
    aria-modal="true"
    aria-label="Remote Preview of {p?.name ?? ''}"
    tabindex="-1"
    {@attach (el) => el.focus()}
  >
    <header>
      <div class="who">
        <b>{p?.name ?? '—'}</b>
        <span class="ip">{p?.ip}</span>
        <!-- Power only: the frame's colour already says the shutter. -->
        {#if p}
          <span class="pw">
            <Cell column="power" {p} groups={groupMap} {patternLabel} />
          </span>
        {/if}
        {#if group}
          <span class="grp" style:--gcolor={group.color}>{group.name}</span>
        {/if}
      </div>
      {#if many && !full}
        {@render nav()}
      {/if}
      <button class="x" aria-label="Close preview" onclick={() => preview.close()}>
        <Icon name="close" size={18} />
      </button>
    </header>

    <div class="plane" style:--frame={frameColor(p)} {@attach swipeable}>
      {#if preview.unavailable || s?.state === 'unavailable'}
        <div class="msg">
          <span>Preview not available</span>
          <button class="retry" onclick={() => preview.retry()}>Retry</button>
        </div>
      {:else if !s || s.state === 'connecting'}
        <span class="spin" aria-label="Connecting"></span>
      {:else}
        {#if s.state === 'live' && preview.image}
          <img src={preview.image} alt="Live image of {p?.name ?? ''}" draggable="false" />
          {#if s.signal}
            <span class="tag br">{s.signal}</span>
          {/if}
        {:else if s.state === 'notice'}
          <span class="note">{noticeText(s)}</span>
        {/if}
        {#if tag}
          <span class="tag tl">{tag}</span>
        {/if}
      {/if}
    </div>

    {#if many && full}
      <!-- A phone: under the image, where the thumb is; the name keeps the header. -->
      <div class="under">{@render nav()}</div>
    {/if}

    {#if operator}
      <footer>
        <div class="ps" class:off={!ready}>
          <span class="psl">
            <b>Pre-show</b>
            <small>{s?.preShowApplying ? `${preShowNote} · applying…` : preShowNote}</small>
          </span>
          {#if s?.preShowApplying}
            <span class="spin sm" aria-hidden="true"></span>
          {/if}
          <button
            class="sw"
            role="switch"
            aria-checked={s?.preShow === true}
            aria-label="Pre-show"
            disabled={!ready}
            onclick={() => preview.setPreShow(s?.preShow !== true)}><span></span></button
          >
        </div>
      </footer>
    {/if}
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 42;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
  }

  .scrim {
    position: absolute;
    inset: 0;
    border: 0;
    background: var(--scrim);
  }

  /* As big as the window allows, 16:9 kept: the image's width is bounded by
     the width and by the height left after the header and footer (~130 px). */
  .dialog {
    --chrome: 132px;
    position: relative;
    width: min(960px, 100%, (100dvh - 32px - var(--chrome)) * 16 / 9 + 32px);
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 12px 16px 14px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 16px;
    box-shadow: var(--sh-3);
    outline: none;
  }

  /* A phone: the whole screen, the image as wide as it fits. */
  .full {
    padding: 0;
  }

  .full .dialog {
    --chrome: 180px;
    width: 100%;
    height: 100%;
    justify-content: center;
    padding: max(8px, env(safe-area-inset-top)) max(12px, env(safe-area-inset-right))
      max(12px, env(safe-area-inset-bottom)) max(12px, env(safe-area-inset-left));
    border: 0;
    border-radius: 0;
  }

  .full .plane {
    width: min(100%, (100dvh - var(--chrome)) * 16 / 9);
    align-self: center;
  }

  header {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 40px;
  }

  .who {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    gap: 10px;
    overflow: hidden;
    white-space: nowrap;
  }

  /* The name gives way last: the IP and group shrink first. */
  .who b {
    flex: 0 1 auto;
    min-width: 6ch;
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 15px;
    font-weight: 650;
  }

  .who > span {
    flex: 0 100 auto;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* The group goes first: the IP says more about which projector it is. */
  .who > .grp {
    flex-shrink: 10000;
  }

  /* Power stays whole; the IP and group give way before it. */
  .who > .pw {
    display: inline-flex;
    flex: none;
    font-size: 13px;
  }

  .under {
    display: flex;
    justify-content: center;
  }

  .under .nav {
    gap: 16px;
  }

  .under .pos {
    font-size: 15px;
    font-weight: 600;
  }

  .under .nav button {
    width: 64px;
    height: 48px;
  }

  .ip {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--faint);
  }

  .grp {
    overflow: hidden;
    padding-left: 8px;
    box-shadow: inset 2px 0 0 var(--gcolor);
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
  }

  .nav {
    display: flex;
    flex: none;
    align-items: center;
    gap: 2px;
  }

  .nav button,
  .x {
    width: 36px;
    height: 36px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .pos {
    min-width: 6ch;
    color: var(--muted);
    font-size: 13px;
    font-variant-numeric: tabular-nums;
    text-align: center;
  }

  @media (hover: hover) {
    .nav button:hover,
    .x:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  /* Finger-sized on touch screens. */
  @media (pointer: coarse) {
    .nav button,
    .x {
      width: 48px;
      height: 44px;
    }

    .nav button {
      background: var(--hover);
    }

    .nav {
      gap: 6px;
    }

    .x {
      margin-left: 6px;
    }
  }

  /* The image area: a black 16:9 plane in a 2 px shutter-coloured frame. */
  .plane {
    position: relative;
    aspect-ratio: 16 / 9;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    background: #000;
    border: 2px solid var(--frame);
    touch-action: pan-y;
    user-select: none;
  }

  img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .msg {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    color: rgb(255 255 255 / 0.7);
    font-size: 13px;
  }

  .note {
    padding: 12px;
    color: rgb(255 255 255 / 0.7);
    font-size: 13px;
    text-align: center;
  }

  .retry {
    height: 34px;
    padding: 0 16px;
    border: 1px solid rgb(255 255 255 / 0.25);
    border-radius: var(--r-sm);
    background: none;
    color: #fff;
    font-weight: 550;
    cursor: pointer;
  }

  .tag {
    position: absolute;
    max-width: calc(100% - 12px);
    overflow: hidden;
    padding: 2px 6px;
    border: 1px solid rgb(255 255 255 / 0.24);
    border-radius: 3px;
    background: rgb(0 0 0 / 0.6);
    color: #fff;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tag.tl {
    top: 6px;
    left: 6px;
  }

  .tag.br {
    right: 6px;
    bottom: 6px;
  }

  .spin {
    width: 22px;
    height: 22px;
    border: 2px solid rgb(255 255 255 / 0.7);
    border-right-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .spin.sm {
    width: 16px;
    height: 16px;
    border-color: var(--accent);
    border-right-color: transparent;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  footer {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px 20px;
    min-height: 40px;
  }

  .ps {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-left: auto;
  }

  .psl {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    line-height: 1.25;
  }

  .psl b {
    font-size: 13.5px;
    font-weight: 600;
  }

  .psl small {
    color: var(--faint);
    font-size: 12px;
  }

  .ps.off b {
    color: var(--muted);
  }

  /* A switch, like the app's. */
  .sw {
    position: relative;
    width: 44px;
    height: 26px;
    flex: none;
    padding: 0;
    border: 0;
    border-radius: 999px;
    background: var(--line-strong);
    cursor: pointer;
    transition: background 0.15s;
  }

  .sw span {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #fff;
    box-shadow: 0 1px 2px rgb(0 0 0 / 0.3);
    transition: transform 0.15s;
  }

  .sw[aria-checked='true'] {
    background: var(--accent);
  }

  .sw[aria-checked='true'] span {
    transform: translateX(18px);
  }

  .sw:disabled {
    cursor: default;
    opacity: 0.45;
  }
</style>
