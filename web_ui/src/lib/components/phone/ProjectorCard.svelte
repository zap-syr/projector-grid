<!--
  One projector card: a fixed summary (power, shutter, signal, temps, errors).
  The operator taps the card to select it and ⓘ to open the details; the
  viewer's tap opens them.
-->
<script lang="ts">
  import type { AlignmentRole, ColumnId, Group, Projector } from '../../api/types';
  import { signalLost } from '../../logic/alerts';
  import { cellText } from '../../logic/cells';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import { isSelectable } from '../../logic/selection';
  import { alerts } from '../../state/alerts.svelte';
  import { device } from '../../state/device.svelte';
  import AlertBadge from '../alerts/AlertBadge.svelte';
  import Cell from '../table/Cell.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';
  import TemperatureText from '../status/TemperatureText.svelte';

  let {
    p,
    groups,
    patternLabel,
    operator,
    selected,
    open,
    onselect,
    ondetails,
    role = null,
    outside = false,
    onfocus,
  }: {
    p: Projector;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    operator: boolean;
    selected: boolean;
    /** Its details are open. */
    open: boolean;
    onselect: () => void;
    ondetails: () => void;
    /** Alignment mode: the card's ring or the closed scrim, as in the app. */
    role?: AlignmentRole | null;
    /** Alignment mode is on but this projector isn't in it. */
    outside?: boolean;
    /** Alignment mode: the operator's tap focuses this projector. */
    onfocus?: () => void;
  } = $props();

  const aligning = $derived(role !== null || outside);
  const selectable = $derived(aligning ? role !== null : isSelectable(p));
  const online = $derived(p.connection === 'connected' || p.connection === 'unprotected');
  const hasErrors = $derived(p.errorItems.length > 0);
  const lost = $derived(signalLost(alerts.of(p.id)));
  const cell = (column: ColumnId) => cellText(column, p, groups, patternLabel);
  // Shown behind a closed shutter too (owner, 2026-09-30; the app card follows).
  const showPattern = $derived(online && isPatternActive(p.testPattern));

  /** No details in Alignment mode: the Control's place belongs to the lens. */
  function primary() {
    if (aligning) {
      if (operator && role) onfocus?.();
    } else if (!operator) ondetails();
    else if (selectable) onselect();
  }
</script>

{#snippet value(column: ColumnId)}
  <Cell {column} {p} {groups} {patternLabel} />
{/snippet}

<article
  class="card {role ?? ''}"
  class:sel={operator && selected && !aligning}
  class:open
  class:hasinfo={operator && !aligning}
  class:outside
  class:offline={p.connection === 'offline'}
>
  <div class="head">
    {#if operator && !aligning}
      <span class="cb">
        <Checkbox
          state={selected}
          label="Select {p.name}"
          disabled={!selectable}
          onclick={onselect}
        />
      </span>
    {/if}
    <button
      class="main"
      disabled={operator && !selectable}
      aria-pressed={operator
        ? aligning
          ? role === 'focused'
          : selected
        : aligning
          ? undefined
          : open}
      onclick={primary}
    >
      <span class="title">
        <span class="dot" class:ok={online} class:warn={p.connection === 'unauthorized'}></span>
        <b>{p.name}</b>
        {#if p.connection === 'unauthorized'}
          <span class="warn"><Icon name="lock" size={13} /></span>
        {/if}
        <AlertBadge id={p.id} size={device.touch ? 20 : 16} />
        <span class="ip">{p.ip}</span>
      </span>
      {#if online}
        <span class="sum">
          <!-- The pattern sits with the shutter, pinned right: the title row
               has no room for it beside a warning and the IP on a narrow card. -->
          <span class="l1"
            >{@render value('power')}{@render value('shutter')}
            {#if showPattern}
              <span
                class="tp"
                role="img"
                aria-label="Test pattern: {cell('testPattern')}"
                title="Test pattern: {cell('testPattern')}"
                style:background={patternSwatch(p.testPattern ?? '') ?? 'var(--hover)'}
              ></span>
            {/if}
          </span>
          <span class="l2">
            <span class="sig" class:lost title={p.signal}>{p.signal}</span>
            <span class="temps">
              <TemperatureText display={p.intakeTemp} level={p.status.intake ?? null} /><span
                class="sep">/</span
              ><TemperatureText display={p.exhaustTemp} level={p.status.exhaust ?? null} />
            </span>
          </span>
        </span>
        <!-- Kept when empty: every card the same height, so no row grows and
             a new error doesn't resize the card. -->
        <span class="errline">
          {#if hasErrors}{@render value('errors')}{/if}
        </span>
      {:else}
        <span class="sum solo">
          <span class="state" class:warn={p.connection === 'unauthorized'}
            >{cell('connection')}</span
          >
        </span>
        <span class="errline"></span>
      {/if}
    </button>
    <!-- The operator's way to the details (a tap selects); a viewer's tap opens them. -->
    {#if operator && !aligning}
      <button
        class="info"
        class:on={open}
        aria-pressed={open}
        aria-label="Details of {p.ip}"
        title={device.touch ? undefined : 'Details'}
        onclick={ondetails}
      >
        <Icon name="info" size={device.touch ? 22 : 18} />
      </button>
    {/if}
  </div>
</article>

<style>
  .card {
    flex: none;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: var(--r);
    box-shadow: var(--sh-1);
  }

  /* Its details are open: a brighter fill; selection's border still shows. */
  .card.open {
    border-color: var(--accent-line);
    background: color-mix(in srgb, var(--accent) 16%, var(--surface));
  }

  .card.sel {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 10%, var(--surface));
    box-shadow: 0 0 0 1px var(--accent);
  }

  .card.sel.open {
    background: color-mix(in srgb, var(--accent) 16%, var(--surface));
  }

  /* Alignment rings with a 2 px gap, like the app's canvas card. */
  .card.focused {
    border-color: var(--align);
    box-shadow:
      0 0 0 2px var(--app),
      0 0 0 5px var(--align),
      0 0 14px 5px color-mix(in srgb, var(--align) 45%, transparent);
  }

  .card.shown {
    box-shadow:
      0 0 0 2px var(--app),
      0 0 0 4px var(--align-2);
  }

  .card.closed,
  .card.outside {
    opacity: 0.5;
  }

  .card.outside {
    border-style: dashed;
  }

  /* The chevron sits in the top-right corner over the title row, so the
     status lines below run the card's full width. */
  /* The card's button fills it, so every part of the card answers a click. */
  .card {
    display: flex;
    flex-direction: column;
  }

  .head {
    position: relative;
    flex: 1;
    display: flex;
    align-items: stretch;
  }

  .cb {
    display: flex;
    align-self: flex-start;
    padding: 15px 0 0 14px;
  }

  .main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 12px;
    border: 0;
    background: none;
    text-align: left;
    cursor: pointer;
  }

  .main:disabled {
    cursor: default;
  }

  /* One line, clear of the chevron. The IP wraps onto a clipped second line
     — i.e. disappears — when a narrow card can't fit it whole beside the
     name and icons; the details strip still has it. */
  .title {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    column-gap: 7px;
    min-width: 0;
    height: 22px;
    overflow: hidden;
  }

  /* Room for the operator's ⓘ (its icon, not its whole hit area); a viewer
     has none, so the IP runs to the card's edge. */
  .card.hasinfo .title {
    padding-right: 30px;
  }

  .title > * {
    line-height: 22px;
  }

  .title b {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 15px;
    font-weight: 650;
  }

  .ip {
    margin-left: auto;
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 12px;
    color: var(--faint);
    white-space: nowrap;
    flex: none;
  }

  /* Test-pattern thumbnail, bordered so white / black fields don't vanish. */
  .tp {
    width: 24px;
    height: 16px;
    flex: none;
    margin-left: auto;
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .offline .title b {
    color: var(--muted);
  }

  .dot {
    width: 9px;
    height: 9px;
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

  .warn {
    display: flex;
    color: var(--warn);
  }

  /* Two lines with a fixed shape whatever the values, so nothing reflows
     when a label or reading changes length (every step in Alignment mode,
     every degree of drift): power · shutter, then the signal with the
     temperatures pinned right. Nothing follows the shutter on its line, so
     OPEN ↔ CLOSED moves nothing; the signal takes whatever is left and
     ellipsizes only when a card is really narrow. */
  .sum {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
    font-size: 13px;
  }

  .l1 {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px 12px;
  }

  .l2 {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: center;
    gap: 12px;
  }

  .state {
    color: var(--err);
    font-weight: 550;
  }

  .state.warn {
    color: var(--warn);
  }

  .sig {
    overflow: hidden;
    color: var(--muted);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sig.lost {
    color: var(--err);
    font-weight: 650;
  }

  .temps {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  .sep {
    color: var(--faint);
  }

  /* A long error code ellipsizes (Cell's own rule) instead of pushing past the card. */
  .errline {
    display: flex;
    min-width: 0;
    /* The error tags' own height (ErrorTags). */
    min-height: 25px;
    font-size: 13px;
  }

  /* An offline card's one state line takes the room of the two status lines. */
  .sum.solo {
    min-height: calc(2 * 1.45em + 4px);
  }

  /* ⓘ in the top-right corner: 32 px with a mouse, 44 px for a finger. */
  .info {
    position: absolute;
    top: 7px;
    right: 7px;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  @media (hover: hover) {
    .info:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  .info.on,
  .info.on:hover {
    background: var(--pc);
    color: var(--on-pc);
  }

  @media (pointer: coarse) {
    .info {
      top: 1px;
      right: 1px;
      width: 44px;
      height: 44px;
      border-radius: 10px;
    }
  }
</style>
