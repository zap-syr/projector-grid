<!--
  Remote Preview (ROADMAP §5 *Remote Preview on the web*), as the app's
  dialog (shell canvas, *Remote Preview on the desktop / phone / tablet*):
  the title bar with model + IP, group and power; the image in the frame the
  app draws, green / red by shutter; the *Pre-show mode* card for an
  operator; ◀ ▶ to the neighbouring projector and the frame's legend in the
  footer. A phone gets the whole screen, with big ◀ ▶ under the image.
-->
<script lang="ts">
  import type { Projector } from '../../api/types';
  import { powerLabel } from '../../logic/labels';
  import {
    cornerTag,
    FRAME,
    frameColor,
    noticeText,
    preShowNote,
    preShowReady,
    projectorLabel,
  } from '../../logic/preview';
  import { control } from '../../state/control.svelte';
  import { device } from '../../state/device.svelte';
  import { live } from '../../state/live.svelte';
  import { preview } from '../../state/preview.svelte';
  import ConnectionBadge from '../status/ConnectionBadge.svelte';
  import GroupPill from '../status/GroupPill.svelte';
  import StatusPill from '../status/StatusPill.svelte';
  import Icon from '../Icon.svelte';

  let { operator }: { operator: boolean } = $props();

  const p = $derived(preview.projector);
  const s = $derived(preview.status);
  const full = $derived(device.phone || device.short);
  const many = $derived(preview.order.length > 1);
  const group = $derived(p?.groupId ? live.groups.find((g) => g.id === p.groupId) : undefined);

  const tag = $derived(s ? cornerTag(s) : null);
  const ready = $derived(preShowReady(p, s));
  const note = $derived(preShowNote(p, s));

  const inField = (e: KeyboardEvent) =>
    e.target instanceof HTMLInputElement ||
    e.target instanceof HTMLTextAreaElement ||
    e.target instanceof HTMLSelectElement;

  /** Pre-show stays on in the projector after the window goes, as the app says. */
  function close() {
    if (preview.status?.preShow) {
      control.notify({ text: 'Pre-show stays active on the projector', ok: true });
    }
    preview.close();
  }

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
      close();
    } else if ((e.key === 'ArrowLeft' || e.key === 'ArrowRight') && !inField(e)) {
      e.preventDefault();
      preview.step(e.key === 'ArrowLeft' ? -1 : 1);
    }
  }}
/>

{#snippet state(p: Projector)}
  <!-- Power: the frame's colour already says the shutter. A projector out of
       reach says so instead, its power is stale. -->
  {#if p.connection === 'offline' || p.connection === 'unauthorized'}
    <ConnectionBadge connection={p.connection} />
  {:else}
    <StatusPill
      label={powerLabel(p.power)}
      tone={p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn'}
      dot
    />
  {/if}
{/snippet}

{#snippet nav()}
  <div class="nav" role="group" aria-label="Projector">
    <button class="nb" aria-label="Previous projector" onclick={() => preview.step(-1)}>
      <Icon name="left" size={full ? 26 : device.touch ? 22 : 18} />
    </button>
    <span class="pos">{preview.index + 1} of {preview.order.length}</span>
    <button class="nb" aria-label="Next projector" onclick={() => preview.step(1)}>
      <Icon name="right" size={full ? 26 : device.touch ? 22 : 18} />
    </button>
  </div>
{/snippet}

{#snippet legend()}
  <div class="leg">
    <span><i style:border-color={FRAME.open}></i>Shutter open</span>
    <span><i style:border-color={FRAME.closed}></i>Shutter closed</span>
    <span><i style:border-color={FRAME.notOn}></i>Not on</span>
  </div>
{/snippet}

<div class="overlay" class:full class:touch={device.touch}>
  <button class="scrim" aria-label="Close preview" tabindex="-1" onclick={close}></button>
  <div
    class="dialog"
    class:op={operator}
    role="dialog"
    aria-modal="true"
    aria-label="Remote Preview of {p?.ip ?? ''}"
    tabindex="-1"
    {@attach (el) => el.focus()}
  >
    <div class="tbar">
      <span class="tile"><Icon name="monitor" size={18} /></span>
      <div class="tt">
        <b>Remote Preview</b>
        {#if p}<span class="sub">{projectorLabel(p.name, p.ip)}</span>{/if}
      </div>
      {#if p && !full}
        {#if group}<GroupPill {group} />{/if}
        {@render state(p)}
      {/if}
      <button class="x" aria-label="Close preview" onclick={close}>
        <Icon name="close" size={20} />
      </button>
    </div>

    {#if p && full}
      <div class="st">
        {@render state(p)}
        {#if group}<GroupPill {group} />{/if}
      </div>
    {/if}

    <div class="main">
      <div class="plane" style:--frame={frameColor(p)} {@attach swipeable}>
        {#if preview.unavailable || s?.state === 'unavailable'}
          <div class="msg">
            <Icon name="monitorOff" size={full ? 32 : 40} />
            <b>Preview not available</b>
            <span>The projector's web page did not answer.</span>
            <button class="retry" onclick={() => preview.retry()}>
              <Icon name="refresh" size={15} />Retry
            </button>
          </div>
        {:else if !s || s.state === 'connecting'}
          <span class="spin" aria-label="Connecting"></span>
        {:else}
          {#if s.state === 'live' && preview.image}
            <img src={preview.image} alt="Live image of {p?.ip ?? ''}" draggable="false" />
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
        <!-- A phone: under the image, where the thumb is. -->
        {@render nav()}
        <div class="hint">Swipe the image to change the projector</div>
      {/if}

      {#if operator}
        <div class="ps" class:off={!ready}>
          <span class="mini"><Icon name="eye" size={18} /></span>
          <div class="grow">
            <b>Pre-show mode</b>
            <span>{note}</span>
          </div>
          <!-- The slot is held while idle, so the switch doesn't move. -->
          <span class="busy">
            {#if s?.preShowApplying}
              <span class="spin sm" role="status" aria-label="Applying"></span>
            {/if}
          </span>
          <button
            class="sw"
            role="switch"
            aria-checked={s?.preShow === true}
            aria-label="Pre-show"
            disabled={!ready}
            onclick={() => preview.setPreShow(s?.preShow !== true)}><span></span></button
          >
        </div>
      {/if}
    </div>

    {#if full}
      <div class="foot">{@render legend()}</div>
    {:else}
      <div class="foot">
        {#if many}{@render nav()}{/if}
        <span class="sp"></span>
        {@render legend()}
      </div>
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

  /* The app's 720 px (740 on a tablet), smaller when the window is: the
     image keeps 16:9 inside the height left after the bars and the card. */
  .dialog {
    --w: 720px;
    --chrome: 150px;
    position: relative;
    width: min(var(--w), 100%, (100dvh - 32px - var(--chrome)) * 16 / 9 + 50px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    background: var(--win);
    border: 1px solid var(--line-strong);
    border-radius: 20px;
    box-shadow: var(--sh-3);
    outline: none;
  }

  .dialog.op {
    --chrome: 230px;
  }

  .touch .dialog {
    --w: 740px;
  }

  .tbar {
    display: flex;
    flex: none;
    align-items: center;
    gap: 12px;
    padding: 10px 8px 10px 20px;
    border-bottom: 1px solid var(--line);
    background: var(--card);
  }

  .touch .tbar {
    padding-right: 10px;
  }

  .tile {
    width: 30px;
    height: 30px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border-radius: 9px;
    background: var(--pc);
    color: var(--on-pc);
  }

  .tt {
    flex: 1;
    min-width: 0;
  }

  .tt b {
    display: block;
    font-size: 16px;
    font-weight: 600;
  }

  .sub {
    display: block;
    overflow: hidden;
    color: var(--muted);
    font-family: var(--mono);
    font-size: 12px;
    letter-spacing: 0;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .x {
    width: 40px;
    height: 40px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .touch .x {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--soft);
    color: var(--text);
  }

  @media (hover: hover) {
    .x:hover,
    .nb:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  .main {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 20px 24px;
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
    border-radius: 10px;
    touch-action: pan-y;
    user-select: none;
  }

  img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  /* Light on the black plane in both themes. */
  .msg {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 8px;
    color: rgb(255 255 255 / 0.72);
    font-size: 13px;
    text-align: center;
  }

  .msg > :global(svg) {
    color: rgb(255 255 255 / 0.6);
  }

  .msg b {
    color: #fff;
    font-size: 14px;
    font-weight: 600;
  }

  .note {
    padding: 12px;
    color: rgb(255 255 255 / 0.72);
    font-size: 13px;
    text-align: center;
  }

  .retry {
    height: 30px;
    margin-top: 4px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 0 14px;
    border: 1px solid rgb(255 255 255 / 0.28);
    border-radius: 999px;
    background: none;
    color: #fff;
    font-size: 12.5px;
    font-weight: 600;
    cursor: pointer;
  }

  .touch .retry {
    height: 40px;
    padding: 0 18px;
  }

  .tag {
    position: absolute;
    max-width: calc(100% - 16px);
    overflow: hidden;
    padding: 2px 8px;
    border: 1px solid rgb(255 255 255 / 0.2);
    border-radius: 999px;
    background: rgb(0 0 0 / 0.62);
    color: #fff;
    font-size: 11px;
    font-weight: 600;
    line-height: 16px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tag.tl {
    top: 8px;
    left: 8px;
  }

  .tag.br {
    right: 8px;
    bottom: 8px;
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
    display: block;
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

  /* Pre-show mode, the app's card: the switch shows the state, the line
     under the name says why it can or can't be used. */
  .ps {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 11px 16px;
    border: 1px solid var(--line);
    border-radius: 14px;
    background: var(--card);
  }

  .mini {
    width: 34px;
    height: 34px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border-radius: 10px;
    background: var(--soft);
    color: var(--accent);
  }

  .ps.off .mini {
    color: var(--faint);
  }

  /* Two lines held for every note, so the card keeps its height. */
  .grow {
    flex: 1;
    min-width: 0;
    min-height: 55px;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }

  .grow b {
    font-size: 14px;
    font-weight: 600;
  }

  .grow span {
    display: -webkit-box;
    overflow: hidden;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    color: var(--muted);
    font-size: 12.5px;
  }

  .busy {
    width: 16px;
    flex: none;
    margin-right: -6px;
  }

  /* A switch, like the app's. */
  .sw {
    position: relative;
    width: 44px;
    height: 24px;
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
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--faint);
    transition:
      transform 0.15s,
      background 0.15s;
  }

  .sw[aria-checked='true'] {
    background: var(--primary);
  }

  .sw[aria-checked='true'] span {
    background: var(--on-primary);
    transform: translateX(20px);
  }

  .touch .sw {
    width: 52px;
    height: 30px;
  }

  .touch .sw span {
    top: 4px;
    left: 4px;
    width: 22px;
    height: 22px;
  }

  .touch .sw[aria-checked='true'] span {
    transform: translateX(22px);
  }

  .sw:disabled {
    cursor: default;
    opacity: 0.6;
  }

  .foot {
    display: flex;
    flex: none;
    align-items: center;
    gap: 8px;
    min-height: 59px;
    padding: 10px 20px 12px 16px;
    border-top: 1px solid var(--line);
    background: var(--card);
  }

  .touch .foot {
    min-height: 75px;
  }

  .sp {
    flex: 1;
  }

  .nav {
    display: flex;
    flex: none;
    align-items: center;
    gap: 2px;
  }

  .nb {
    width: 36px;
    height: 36px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 50%;
    background: none;
    color: var(--text);
    cursor: pointer;
  }

  .touch .nav {
    gap: 4px;
  }

  .touch .nb {
    width: 48px;
    height: 48px;
    border-radius: 14px;
  }

  .pos {
    min-width: 64px;
    font-size: 13px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    text-align: center;
  }

  .touch .pos {
    min-width: 72px;
    font-size: 14px;
  }

  .leg {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 14px;
    color: var(--muted);
    font-size: 12px;
  }

  .leg span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .leg i {
    width: 14px;
    height: 10px;
    border: 2px solid;
    border-radius: 3px;
  }

  /* A phone: the whole screen; the state under the title bar, the big ◀ ▶
     under the image and the legend at the bottom. */
  .full {
    padding: 0;
  }

  .full .dialog {
    width: 100%;
    height: 100%;
    border: 0;
    border-radius: 0;
  }

  .full .tbar {
    height: calc(64px + env(safe-area-inset-top));
    padding: env(safe-area-inset-top) 8px 0 16px;
    gap: 10px;
  }

  .st {
    display: flex;
    flex: none;
    align-items: center;
    gap: 8px;
    padding: 12px 12px 0;
  }

  .full .main {
    flex: 1;
    min-height: 0;
    padding: 12px;
  }

  /* Landscape: as wide as the height under the bars allows. */
  .full .plane {
    width: min(100%, (100dvh - 260px) * 16 / 9);
    flex: none;
    align-self: center;
  }

  .full .nav {
    justify-content: center;
    gap: 16px;
  }

  .full .nb {
    width: 56px;
    height: 56px;
    border-radius: 16px;
  }

  .full .pos {
    min-width: 84px;
    font-size: 15px;
  }

  .hint {
    margin-top: -4px;
    color: var(--faint);
    font-size: 12px;
    text-align: center;
  }

  .full .ps {
    gap: 12px;
    padding: 12px 14px;
  }

  /* The phone's narrow card: the longest note takes three lines. */
  .full .grow {
    min-height: 72px;
  }

  .full .grow span {
    -webkit-line-clamp: 3;
    line-clamp: 3;
  }

  .full .foot {
    min-height: 0;
    justify-content: center;
    padding: 12px 12px max(26px, env(safe-area-inset-bottom));
    background: none;
  }

  .full .leg {
    justify-content: center;
  }
</style>
