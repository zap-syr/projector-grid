<!--
  One projector card: a fixed summary (power, shutter, signal, temps, errors);
  the chevron opens the rest in a strip under the card's row (CardDetails).
  The operator taps the card to select it, the viewer to open the details.
-->
<script lang="ts">
  import type { AlignmentRole, Config, DataColumn, Group, Projector } from '../../api/types';
  import { cellText } from '../../logic/cells';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import { isSelectable } from '../../logic/selection';
  import Cell from '../table/Cell.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    operator,
    selected,
    expanded,
    onselect,
    onexpand,
    role = null,
    outside = false,
    onfocus,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    operator: boolean;
    selected: boolean;
    expanded: boolean;
    onselect: () => void;
    onexpand: () => void;
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
  const hasErrors = $derived(p.errors !== '-' && p.errors !== 'NO ERRORS' && p.errors !== '');
  const cell = (column: DataColumn) => cellText(column, p, groups, patternLabel);
  // Shown behind a closed shutter too (owner, 2026-09-30; the app card follows).
  const showPattern = $derived(online && isPatternActive(p.testPattern));

  function primary() {
    if (!operator) onexpand();
    else if (aligning) {
      if (role) onfocus?.();
    } else if (selectable) onselect();
  }
</script>

{#snippet value(column: DataColumn)}
  <Cell {column} {p} {groups} thresholds={config.thresholds} {patternLabel} />
{/snippet}

<article
  class="card {role ?? ''}"
  class:sel={operator && selected && !aligning}
  class:open={expanded}
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
      aria-pressed={operator ? (aligning ? role === 'focused' : selected) : undefined}
      aria-expanded={operator ? undefined : expanded}
      onclick={primary}
    >
      <span class="title">
        <span class="dot" class:ok={online} class:warn={p.connection === 'unauthorized'}></span>
        <b>{p.name}</b>
        {#if p.connection === 'unauthorized'}
          <span class="warn"><Icon name="lock" size={13} /></span>
        {/if}
        {#if hasErrors}
          <span class="warn" title={p.errors}><Icon name="warn" size={15} /></span>
        {/if}
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
            <span class="sig" title={cell('signal')}>{cell('signal')}</span>
            <span class="temps">
              {@render value('intake')}<span class="sep">/</span>{@render value('exhaust')}
            </span>
          </span>
        </span>
        {#if hasErrors}
          <span class="errline">{@render value('errors')}</span>
        {/if}
      {:else}
        <span class="sum">
          <span class="state" class:warn={p.connection === 'unauthorized'}
            >{cell('connection')}</span
          >
        </span>
      {/if}
    </button>
    <button
      class="chev"
      class:open={expanded}
      aria-expanded={expanded}
      aria-label="{expanded ? 'Hide' : 'Show'} details of {p.name}"
      onclick={onexpand}
    >
      <Icon name="chevron" size={16} />
    </button>
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

  /* Ties the card to its details strip; selection still wins. */
  .card.open {
    border-color: var(--accent-line);
  }

  .card.sel {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 10%, var(--surface));
    box-shadow: 0 0 0 1px var(--accent);
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
  .head {
    position: relative;
    display: flex;
    align-items: flex-start;
  }

  .cb {
    display: flex;
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
    /* The chevron's icon, not its whole 44 px hit area. */
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
    font-size: 13px;
  }

  .chev {
    position: absolute;
    top: 1px;
    right: 1px;
    width: 44px;
    height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: var(--r);
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .chev :global(svg) {
    transition: transform 0.15s;
  }

  .chev.open :global(svg) {
    transform: rotate(180deg);
  }
</style>
