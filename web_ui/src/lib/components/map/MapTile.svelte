<!--
  One projector on the Map, drawn like the app's canvas card (`projector_card.dart`):
  a header tinted by its state (`cardHeaderTone`) with power, shutter and the
  alert badge, then the model and the IP with the test-pattern thumbnail, and
  the group as a band inside the tile. Sized in canvas px; MapView scales the
  whole wall.
-->
<script lang="ts">
  import type { AlignmentRole, Group, Projector } from '../../api/types';
  import { CARD_H, CARD_W, groupBand } from '../../logic/map';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import { themeColors } from '../../state/themeColors.svelte';
  import AlertBadge from '../alerts/AlertBadge.svelte';
  import Icon from '../Icon.svelte';
  import StatusDot from '../status/StatusDot.svelte';

  let {
    p,
    group,
    origin,
    patternLabel,
    operator,
    selected,
    dim,
    compact,
    ipChars,
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
    /** The project's longest IP, so every tile's IP is one size. */
    ipChars: number;
    /** Alignment mode: the app card's rings — focused, shown — or the closed scrim. */
    role?: AlignmentRole | null;
    /** Alignment mode is on but this projector isn't in it (offline on entry, or out of scope). */
    outside?: boolean;
  } = $props();

  const aligning = $derived(role !== null || outside);

  /** `cardHeaderTone`: the connection first, then the power. */
  const tone = $derived(
    p.connection === 'offline'
      ? 'offline'
      : p.connection === 'unauthorized'
        ? 'login'
        : p.power === 'on'
          ? 'on'
          : p.power === 'standby'
            ? 'standby'
            : 'transition',
  );
  /** `ProjectorStatusStyle`: green on, amber in transition, red standby. */
  const powerColor = $derived(p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn');
  /** In standby the shutter decides nothing on screen, so it goes grey. */
  const shutterColor = $derived(
    p.power === 'standby' ? 'faint' : p.shutter === 'open' ? 'ok' : 'err',
  );
  const band = $derived(group ? groupBand(group.color, themeColors.card) : null);
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
    aria-label={role ? `${p.ip}, ${p.name}, ${role}` : `${p.ip}, ${p.name}`}
    aria-pressed={operator ? (aligning ? role === 'focused' : selected) : undefined}
    aria-haspopup={operator ? undefined : 'dialog'}
  >
    <!-- Safari doesn't stretch a button's own flex children: the layout lives in .inner. -->
    <span class="inner">
      {#if compact}
        <span class="cname">
          <StatusDot connection={p.connection} />
          <b>{p.name}</b>
        </span>
      {:else}
        <span class="head {tone}">
          {#if tone === 'offline'}
            <span class="lab err"><Icon name="power" size={13} />Offline</span>
          {:else if tone === 'login'}
            <span class="lab warn"><Icon name="lock" size={13} />Login failed</span>
          {:else}
            <span class="ic {powerColor}"><Icon name="power" size={15} /></span>
            <span class="ic {shutterColor}"
              ><Icon name={p.shutter === 'open' ? 'eye' : 'eyeOff'} size={15} /></span
            >
          {/if}
          <span class="grow"></span>
          {#if p.connection === 'unprotected'}
            <span class="ic faint"><Icon name="unlock" size={13} /></span>
          {/if}
          <AlertBadge id={p.id} size={15} />
        </span>
        <span class="body">
          <b class="name">{p.name}</b>
          <span class="ipr">
            <span class="ip" style:--n={ipChars}>{p.ip}</span>
            {#if isPatternActive(p.testPattern)}
              <span
                class="tp"
                role="img"
                aria-label="Test pattern: {patternLabel(p.testPattern)}"
                style:background={patternSwatch(p.testPattern) ?? 'var(--hover)'}
              ></span>
            {/if}
          </span>
        </span>
        {#if group && band}
          <span class="band" style:background={band.fill} style:color={band.text}>{group.name}</span
          >
        {/if}
      {/if}
    </span>
  </button>
</div>

<style>
  .tile {
    position: absolute;
  }

  .tile.dim {
    opacity: 0.3;
  }

  .card {
    position: relative;
    width: 100%;
    display: flex;
    padding: 0;
    overflow: hidden;
    border: 1px solid var(--line-strong);
    border-radius: 10px;
    background: var(--card);
    box-shadow: 0 2px 4px rgb(0 0 0 / 0.25);
    color: var(--text);
    text-align: left;
    cursor: pointer;
    transition: border-color 0.12s;
  }

  .inner {
    flex: 1;
    width: 100%;
    height: 100%;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .card:hover {
    border-color: color-mix(in srgb, var(--accent) 85%, transparent);
  }

  /* The app's 2 px selection border: the border plus a 1 px ring inside it,
     on a layer above the header so its background can't cover the ring. */
  .card.sel {
    border-color: var(--accent);
  }

  .card.sel::after {
    content: '';
    position: absolute;
    inset: 0;
    border-radius: 9px;
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

  /* The header band, tinted by the state so it reads from a distance:
     16 % of the tone, 34 % for offline, its border 28 % / 50 %. */
  .head {
    --tone: var(--ok);
    height: 26px;
    flex: none;
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0 8px;
    background: color-mix(in srgb, var(--tone) 16%, var(--card));
    border-bottom: 1px solid color-mix(in srgb, var(--tone) 28%, var(--card));
  }

  .head.transition,
  .head.login {
    --tone: var(--warn);
  }

  .head.standby,
  .head.offline {
    --tone: var(--err);
  }

  .head.offline {
    background: color-mix(in srgb, var(--tone) 34%, var(--card));
    border-bottom-color: color-mix(in srgb, var(--tone) 50%, var(--card));
  }

  .lab {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-weight: 600;
    white-space: nowrap;
  }

  .ic {
    display: flex;
  }

  .ok {
    color: var(--ok);
  }

  .warn {
    color: var(--warn);
  }

  .err {
    color: var(--err);
  }

  .faint {
    color: var(--faint);
  }

  .grow {
    flex: 1;
  }

  .body {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    /* Model and IP at the card's bottom, as the app's; with no group band
       nothing is kept for one. */
    justify-content: flex-end;
    gap: 1px;
    padding: 0 8px 7px;
  }

  .name {
    overflow: hidden;
    font-size: 14px;
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ipr {
    height: 16px;
    display: flex;
    align-items: center;
    gap: 4px;
    container-type: inline-size;
  }

  /* Scaled down rather than cut, as the app's FittedBox: the IP is what tells
     two cards of the same model apart. One size on every tile (owner,
     2026-10-22): the project's longest IP beside a thumbnail's room (20 px),
     whether or not this tile shows one. A mono glyph is 0.6 em wide. */
  .ip {
    flex: 1;
    overflow: hidden;
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: min(12px, (100cqw - 20px) / (var(--n) * 0.6));
    color: var(--muted);
    white-space: nowrap;
  }

  /* The app's 16×10 thumbnail, bottom right. */
  .tp {
    width: 16px;
    height: 10px;
    flex: none;
    box-shadow: inset 0 0 0 0.5px var(--line-strong);
  }

  /* The group on a band inside the card's bottom (the app's 18 px `_GroupBand`). */
  .band {
    height: 18px;
    flex: none;
    padding: 0 8px;
    overflow: hidden;
    font-size: 10px;
    font-weight: 600;
    line-height: 18px;
    text-overflow: ellipsis;
    white-space: nowrap;
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

  .compact :global(.dot) {
    width: 16px;
    height: 16px;
  }
</style>
