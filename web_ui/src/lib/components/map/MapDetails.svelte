<!--
  A Map tile's details: the shared ProjectorDetails in a popover beside the
  tile (left of it when the right side has no room). Esc or a press
  elsewhere closes it.
-->
<script lang="ts">
  import type { Config, Group, Projector } from '../../api/types';
  import ProjectorDetails from '../details/ProjectorDetails.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    anchor,
    touch,
    onclose,
    onpreview,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    /** The tile's box on screen. */
    anchor: DOMRect;
    touch: boolean;
    onclose: () => void;
    /** Opens Remote Preview; none in Alignment mode. */
    onpreview?: () => void;
  } = $props();

  const WIDTH = 344;
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
  aria-label="Projector {p.ip}"
  bind:this={box}
  bind:offsetHeight={height}
  style:left="{left}px"
  style:top="{top}px"
  style:width="{WIDTH}px"
>
  <ProjectorDetails
    {p}
    {config}
    {groups}
    {patternLabel}
    placement="popover"
    {touch}
    {onclose}
    {onpreview}
  />
</div>

<style>
  .pop {
    position: fixed;
    z-index: 30;
    max-height: calc(100dvh - 16px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border: 1px solid var(--line-strong);
    border-radius: 14px;
    box-shadow: var(--sh-2);
  }
</style>
