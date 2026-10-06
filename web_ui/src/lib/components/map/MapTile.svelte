<!--
  One projector on the Map, drawn like the app's canvas card (`projector_card.dart`):
  status bar, name, IP with the test-pattern thumbnail, the group's tint and
  chip. Sized in canvas px; MapView scales the whole wall.
-->
<script lang="ts">
  import type { AlignmentRole, Group, Projector } from '../../api/types';
  import { CARD_H, CARD_W, chipText } from '../../logic/map';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import AlertBadge from '../alerts/AlertBadge.svelte';
  import Icon from '../Icon.svelte';

  let {
    p,
    group,
    origin,
    patternLabel,
    operator,
    selected,
    dim,
    compact,
    role = null,
    outside = false,
  }: {
    p: Projector;
    group: Group | undefined;
    /** The wall's top-left corner in canvas px. */
    origin: { x: number; y: number };
    patternLabel: (code: string) => string;
    operator: boolean;
    selected: boolean;
    /** Left out by the filter or search. */
    dim: boolean;
    /** Zoomed far out: dot and name only. */
    compact: boolean;
    /** Alignment mode: the app card's rings — focused, shown — or the closed scrim. */
    role?: AlignmentRole | null;
    /** Alignment mode is on but this projector isn't in it (offline on entry, or out of scope). */
    outside?: boolean;
  } = $props();

  const aligning = $derived(role !== null || outside);

  const online = $derived(p.connection === 'connected' || p.connection === 'unprotected');
  const power = $derived(p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn');
</script>

<div
  class="tile"
  class:dim
  style:left="{p.x - origin.x}px"
  style:top="{p.y - origin.y}px"
  style:width="{CARD_W}px"
>
  <button
    class="card {role ?? ''}"
    class:sel={operator && selected && !aligning}
    class:outside
    class:compact
    data-id={p.id}
    style:height="{CARD_H}px"
    style:--tint={group?.color}
    aria-label={role ? `${p.name}, ${role}` : p.name}
    aria-pressed={operator ? (aligning ? role === 'focused' : selected) : undefined}
    aria-haspopup={operator ? undefined : 'dialog'}
  >
    {#if compact}
      <span class="cname">
        <span class="dot" class:ok={online} class:warn={p.connection === 'unauthorized'}></span>
        <b>{p.name}</b>
      </span>
    {:else}
      <span class="bar">
        <span class={power}><Icon name="power" size={14} /></span>
        <span class={p.shutter === 'open' ? 'ok' : 'err'}><Icon name="eye" size={14} /></span>
        <AlertBadge id={p.id} size={15} />
        <span class="grow"></span>
        {#if p.connection === 'unauthorized'}
          <span class="warn"><Icon name="lock" size={12} /></span>
        {:else if p.connection === 'unprotected'}
          <span class="acc"><Icon name="unlock" size={12} /></span>
        {/if}
        <span class="dot" class:ok={online} class:warn={p.connection === 'unauthorized'}></span>
      </span>
      <b class="name">{p.name}</b>
      <span class="foot">
        <span class="ip">{p.ip}</span>
        {#if isPatternActive(p.testPattern)}
          <span
            class="tp"
            role="img"
            aria-label="Test pattern: {patternLabel(p.testPattern)}"
            style:background={patternSwatch(p.testPattern) ?? 'var(--hover)'}
          ></span>
        {/if}
      </span>
    {/if}
  </button>
  {#if group}
    <span class="chip" style:background={group.color} style:color={chipText(group.color)}
      >{group.name}</span
    >
  {/if}
</div>

<style>
  /* The chip sits below the widest Alignment ring (3 + 5 px), as in the app,
     so it never covers a ring and doesn't move when the mode starts. */
  .tile {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }

  .tile.dim {
    opacity: 0.3;
  }

  .card {
    position: relative;
    width: 100%;
    display: flex;
    flex-direction: column;
    padding: 0;
    overflow: hidden;
    border: 1px solid var(--line-strong);
    border-radius: 8px;
    /* The app tints a grouped card with 15 % of the group's colour. */
    background: color-mix(in srgb, var(--tint, transparent) 15%, var(--surface));
    box-shadow: 0 2px 4px rgb(0 0 0 / 0.1);
    color: var(--text);
    text-align: left;
    cursor: pointer;
    transition: border-color 0.12s;
  }

  .card:hover {
    border-color: color-mix(in srgb, var(--accent) 85%, transparent);
  }

  /* The app's 2 px selection border: the border plus a 1 px ring inside it,
     on a layer above the status bar so its background can't cover the ring. */
  .card.sel {
    border-color: var(--accent);
  }

  .card.sel::after {
    content: '';
    position: absolute;
    inset: 0;
    border-radius: 7px;
    box-shadow: inset 0 0 0 1px var(--accent);
    pointer-events: none;
  }

  /* Alignment rings, outside the card with a 2 px gap in the surface colour
     (the app's projector_card.dart): focused 3 px + glow, shown 2 px paler. */
  .card.focused {
    box-shadow:
      0 0 0 2px var(--surface),
      0 0 0 5px var(--align),
      0 0 14px 5px color-mix(in srgb, var(--align) 50%, transparent);
  }

  .card.shown {
    box-shadow:
      0 0 0 2px var(--surface),
      0 0 0 4px var(--align-2);
  }

  /* Kept closed by the mode: an opaque scrim, like the dark projectors on the wall. */
  .card.closed::after,
  .card.outside::after {
    content: '';
    position: absolute;
    inset: 0;
    background: color-mix(in srgb, var(--surface) 60%, transparent);
    pointer-events: none;
  }

  .card.outside {
    border-style: dashed;
    cursor: default;
  }

  .bar {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 6px 8px;
    background: var(--hover);
  }

  .grow {
    flex: 1;
  }

  .name {
    margin-top: auto;
    padding: 4px 8px;
    overflow: hidden;
    font-size: 14px;
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .foot {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0 8px 8px;
  }

  .ip {
    flex: 1;
    overflow: hidden;
    font-size: 12px;
    color: var(--muted);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* The app's 16×10 thumbnail, bottom right. */
  .tp {
    width: 16px;
    height: 10px;
    flex: none;
    box-shadow: inset 0 0 0 0.5px var(--line-strong);
  }

  /* Far out the name is all that reads, so it grows to fill the tile. */
  .cname {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 0 10px;
    min-width: 0;
  }

  .cname b {
    overflow: hidden;
    font-size: 24px;
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .compact .dot {
    width: 16px;
    height: 16px;
  }

  .dot {
    width: 8px;
    height: 8px;
    flex: none;
    border-radius: 50%;
    background: var(--err);
  }

  .dot.ok {
    background: var(--ok);
  }

  .dot.warn {
    background: var(--warn);
  }

  .ok {
    display: flex;
    color: var(--ok);
  }

  .err {
    display: flex;
    color: var(--err);
  }

  .warn {
    display: flex;
    color: var(--warn);
  }

  .acc {
    display: flex;
    color: var(--accent);
  }

  .chip {
    max-width: 100%;
    padding: 3px 8px;
    overflow: hidden;
    border-radius: 9px;
    font-size: 9px;
    font-weight: 600;
    line-height: 1;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
