<!--
  A Map tile's details: a popover beside the tile (left of it when the
  right side has no room). Esc or a press elsewhere closes it.
-->
<script lang="ts">
  import type { Config, Group, Projector } from '../../api/types';
  import DetailFields from '../DetailFields.svelte';
  import Icon from '../Icon.svelte';
  import PreviewButton from '../preview/PreviewButton.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    anchor,
    onclose,
    onpreview,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    /** The tile's box on screen. */
    anchor: DOMRect;
    onclose: () => void;
    /** Opens Remote Preview; none in Alignment mode. */
    onpreview?: () => void;
  } = $props();

  const WIDTH = 340;
  const GAP = 8;
  let height = $state(0);

  let winW = $state(0);
  let winH = $state(0);

  const left = $derived.by(() => {
    const room = winW - GAP;
    if (anchor.right + GAP + WIDTH <= room) return anchor.right + GAP;
    return Math.max(GAP, Math.min(anchor.left - GAP - WIDTH, room - WIDTH));
  });
  const top = $derived(Math.max(GAP, Math.min(anchor.top, winH - GAP - height)));

  let box = $state<HTMLElement>();
</script>

<svelte:window
  bind:innerWidth={winW}
  bind:innerHeight={winH}
  onkeydowncapture={(e) => {
    if (e.key === 'Escape' && !e.defaultPrevented) {
      // Capture phase: this popover opens after the toolbar mounts, and the
      // toolbar's Esc would otherwise clear the selection first.
      e.preventDefault();
      onclose();
    }
  }}
  onpointerdown={(e) => {
    const t = e.target as Element;
    // A press on this tile is the tile's own toggle (MapView).
    if (!box?.contains(t) && !t.closest(`[data-id="${CSS.escape(p.id)}"]`)) onclose();
  }}
/>

<div
  class="pop"
  role="dialog"
  aria-label="Details of {p.name}"
  bind:this={box}
  bind:offsetHeight={height}
  style:left="{left}px"
  style:top="{top}px"
  style:width="{WIDTH}px"
>
  <header>
    <b>{p.name}</b>
    <span class="ip">{p.ip}</span>
    <span class="grow"></span>
    {#if onpreview}
      <PreviewButton onclick={onpreview} />
    {/if}
    <button class="x" aria-label="Close details" onclick={onclose}>
      <Icon name="close" size={16} />
    </button>
  </header>
  <DetailFields {p} {config} {groups} {patternLabel} skip={['model']} min={130} />
</div>

<style>
  .pop {
    position: fixed;
    z-index: 30;
    max-height: calc(100dvh - 16px);
    overflow: auto;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 11px;
    box-shadow: var(--sh-2);
  }

  header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 8px 0 16px;
  }

  header b {
    overflow: hidden;
    font-size: 14.5px;
    font-weight: 650;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ip {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--faint);
  }

  .grow {
    flex: 1;
  }

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

  .x:hover {
    background: var(--hover);
    color: var(--text);
  }
</style>
