<!--
  One projector card: a fixed summary (power, shutter, signal, temps, errors);
  the chevron opens the rest in a strip under the card's row (CardDetails).
  The operator taps the card to select it, the viewer to open the details.
-->
<script lang="ts">
  import type { ColumnId, Config, Group, Projector } from '../../api/types';
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
  } = $props();

  const selectable = $derived(isSelectable(p));
  const online = $derived(p.connection === 'connected' || p.connection === 'unprotected');
  const hasErrors = $derived(p.errors !== '-' && p.errors !== 'NO ERRORS' && p.errors !== '');
  const cell = (column: ColumnId) => cellText(column, p, groups, patternLabel);
  // Shown behind a closed shutter too (owner, 2026-09-30; the app card follows).
  const showPattern = $derived(online && isPatternActive(p.testPattern));

  function primary() {
    if (!operator) onexpand();
    else if (selectable) onselect();
  }
</script>

{#snippet value(column: ColumnId)}
  <Cell {column} {p} {groups} thresholds={config.thresholds} {patternLabel} />
{/snippet}

<article
  class="card"
  class:sel={operator && selected}
  class:open={expanded}
  class:offline={p.connection === 'offline'}
>
  <div class="head">
    {#if operator}
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
      aria-pressed={operator ? selected : undefined}
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
        <span class="ip">
          {#if showPattern}
            <span
              class="tp"
              role="img"
              aria-label="Test pattern: {cell('testPattern')}"
              title="Test pattern: {cell('testPattern')}"
              style:background={patternSwatch(p.testPattern ?? '') ?? 'var(--hover)'}
            ></span>
          {/if}
          {p.ip}
        </span>
      </span>
      {#if online}
        <span class="sum">
          {@render value('power')}
          {@render value('shutter')}
          <span class="sig">{cell('signal')}</span>
          <span class="temps">
            {@render value('intake')}<span class="sep">/</span>{@render value('exhaust')}
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

  .head {
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
    padding: 12px 4px 12px 12px;
    border: 0;
    background: none;
    text-align: left;
    cursor: pointer;
  }

  .main:disabled {
    cursor: default;
  }

  .title {
    display: flex;
    align-items: center;
    gap: 7px;
    min-width: 0;
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
    padding-left: 8px;
    font-family: var(--mono);
    font-size: 12px;
    color: var(--faint);
    white-space: nowrap;
  }

  .ip {
    display: inline-flex;
    align-items: center;
    gap: 7px;
  }

  /* Test-pattern thumbnail, bordered so white / black fields don't vanish. */
  .tp {
    width: 24px;
    height: 16px;
    flex: none;
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

  .sum {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px 12px;
    font-size: 13px;
  }

  .state {
    color: var(--err);
    font-weight: 550;
  }

  .state.warn {
    color: var(--warn);
  }

  .sig {
    color: var(--muted);
  }

  .temps {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  .sep {
    color: var(--faint);
  }

  .errline {
    font-size: 13px;
  }

  .chev {
    width: 44px;
    height: 44px;
    flex: none;
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
