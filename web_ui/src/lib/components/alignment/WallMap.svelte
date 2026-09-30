<!--
  The phone's wall mini-map (ROADMAP §5): the Map tiles fitted into the
  width, focused ringed, neighbours outlined, the closed dimmed, projectors
  outside the mode dashed. The operator taps a tile to focus it.
-->
<script lang="ts">
  import { fitZoom, mapBounds } from '../../logic/map';
  import { alignment } from '../../state/alignment.svelte';
  import { live } from '../../state/live.svelte';
  import MapTile from '../map/MapTile.svelte';

  let { operator, patternLabel }: { operator: boolean; patternLabel: (code: string) => string } =
    $props();

  /** Tall walls stop here; the rest of the screen is for the controls. */
  const MAX_H = 260;

  let width = $state(0);
  const bounds = $derived(mapBounds(live.projectors));
  const zoom = $derived(fitZoom(bounds, width, MAX_H));
  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));

  function onclick(e: MouseEvent) {
    const id = (e.target as Element).closest<HTMLElement>('[data-id]')?.dataset.id;
    if (operator && id && alignment.role(id)) alignment.focus(id);
  }
</script>

<!-- Each tile is a button; the click is handled here for all of them. -->
<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="wall"
  class:ro={!operator}
  bind:clientWidth={width}
  style:height="{bounds.h * zoom}px"
  {onclick}
>
  <div
    class="plane"
    style:width="{bounds.w}px"
    style:height="{bounds.h}px"
    style:transform="translateX({(width - bounds.w * zoom) / 2}px) scale({zoom})"
  >
    {#each live.projectors as p (p.id)}
      <MapTile
        {p}
        group={p.groupId ? groupMap.get(p.groupId) : undefined}
        origin={bounds}
        {patternLabel}
        {operator}
        selected={false}
        dim={false}
        compact
        role={alignment.role(p.id)}
        outside={!alignment.role(p.id)}
      />
    {/each}
  </div>
</div>

<style>
  .wall {
    position: relative;
    overflow: hidden;
    border-radius: var(--r);
    background:
      radial-gradient(circle, var(--line) 1px, transparent 1.5px) 0 0 / 14px 14px,
      var(--app);
  }

  .plane {
    position: absolute;
    top: 0;
    left: 0;
    transform-origin: 0 0;
  }

  /* Scaled down to a phone's width the app's 3 px ring would be a hairline:
     the mini-map draws it about three times as thick. */
  .wall :global(.card.focused) {
    box-shadow:
      0 0 0 4px var(--app),
      0 0 0 13px var(--align);
  }

  .wall :global(.card.shown) {
    box-shadow:
      0 0 0 4px var(--app),
      0 0 0 10px var(--align-2);
  }

  /* A viewer's map only shows. */
  .ro :global(.card) {
    cursor: default;
  }
</style>
