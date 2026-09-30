<script lang="ts">
  import type { Config } from '../../api/types';
  import { matchesFilter, matchesSearch } from '../../logic/rows';
  import {
    isSelectable,
    presetSelection,
    type SelectPreset,
    toggledAll,
    triState,
  } from '../../logic/selection';
  import { control } from '../../state/control.svelte';
  import { device } from '../../state/device.svelte';
  import { listMode } from '../../state/listMode.svelte';
  import { live } from '../../state/live.svelte';
  import { panel } from '../../state/panel.svelte';
  import { selection } from '../../state/selection.svelte';
  import Checkbox from '../Checkbox.svelte';
  import type { StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import Icon from '../Icon.svelte';
  import ColumnsMenu from '../table/ColumnsMenu.svelte';

  let { config, layout, operator }: { config: Config; layout: StoredLayout; operator: boolean } =
    $props();

  const shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search)),
  );

  let menu = $state<'columns' | 'select' | null>(null);
  let columnsWrap = $state<HTMLElement>();
  let selectWrap = $state<HTMLElement>();

  function onWindowPointer(e: PointerEvent) {
    const wrap = menu === 'columns' ? columnsWrap : selectWrap;
    if (menu && wrap && !wrap.contains(e.target as Node)) menu = null;
  }

  function pick(preset: SelectPreset) {
    selection.set(presetSelection(preset, live.projectors, selection.ids));
    menu = null;
  }

  const inField = (e: KeyboardEvent) =>
    e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement;
</script>

<svelte:window
  onpointerdown={onWindowPointer}
  onkeydown={(e) => {
    if (e.key === 'Escape' && !e.defaultPrevented) {
      // Esc closes an open menu first, then clears the selection.
      if (menu) menu = null;
      else if (operator && !control.pending && !panel.sheet) selection.clear();
    }
    // Ctrl/Cmd+A: every visible row, like the select-all box.
    if (operator && (e.ctrlKey || e.metaKey) && e.key === 'a' && !inField(e)) {
      e.preventDefault();
      selection.set(toggledAll(shown, new Set()));
    }
  }}
/>

<div class="toolbar" class:phone={device.phone}>
  {#if operator}
    <!-- The bulk selector (PatternFly): the box selects all shown, or clears
         any selection with one tap; the count and the Select ▾ presets share
         one fixed-width control, so nothing beside it moves. -->
    {@const tri = triState(shown, selection.ids)}
    {@const count = selection.ids.size}
    <div class="bulk" class:on={count > 0} bind:this={selectWrap}>
      <span class="bcb">
        <Checkbox
          state={tri}
          label={tri === 'none' ? 'Select all shown' : 'Clear selection'}
          disabled={tri === 'none' && !shown.some(isSelectable)}
          onclick={() => selection.set(toggledAll(shown, selection.ids))}
        />
      </span>
      <button
        class="bmenu"
        aria-haspopup="menu"
        aria-expanded={menu === 'select'}
        onclick={() => (menu = menu === 'select' ? null : 'select')}
      >
        <span class="blabel">{count > 0 ? `${count} selected` : 'Select'}</span>
        <Icon name="chevron" size={14} />
      </button>
      {#if menu === 'select'}
        <div class="menu" role="menu">
          <button role="menuitem" onclick={() => pick({ kind: 'all' })}>All projectors</button>
          <button role="menuitem" onclick={() => pick({ kind: 'warnings' })}
            >Only with warnings</button
          >
          <button role="menuitem" onclick={() => pick({ kind: 'invert' })}>Invert</button>
          {#if live.groups.length > 0}
            <hr />
            {#each live.groups as g (g.id)}
              <button role="menuitem" onclick={() => pick({ kind: 'group', group: g })}>
                <span class="gdot" style:background={g.color}></span>{g.name}
              </button>
            {/each}
          {/if}
        </div>
      {/if}
    </div>
  {/if}
  <label class="search">
    <Icon name="search" size={15} />
    <input
      type="search"
      placeholder={device.phone ? 'Search' : 'Name, IP or serial'}
      aria-label="Search"
      bind:value={view.search}
    />
  </label>
  {#if device.phone}
    <span class="count"><b>{shown.length}</b>/{live.projectors.length}</span>
  {:else}
    <span class="count"
      ><b>{shown.length}</b> of {live.projectors.length}<span class="sl"> shown</span></span
    >
    {@render desktopTools()}
  {/if}
</div>

{#snippet desktopTools()}
  <div class="grow"></div>
  <!-- Columns comes and goes on the left, so the switch and Control stay put. -->
  {#if listMode.value === 'table'}
    <div class="menuwrap" bind:this={columnsWrap}>
      <button
        class="btn"
        aria-expanded={menu === 'columns'}
        onclick={() => (menu = menu === 'columns' ? null : 'columns')}
      >
        <Icon name="columns" size={15} /> Columns
      </button>
      {#if menu === 'columns'}
        <ColumnsMenu {config} {layout} />
      {/if}
    </div>
  {/if}
  {#if !device.cardsOnly}
    <div class="seg" role="group" aria-label="View">
      <button
        aria-pressed={listMode.value === 'table'}
        title="Table"
        onclick={() => listMode.set('table')}
        ><Icon name="table" size={15} /><span class="sl">Table</span></button
      >
      <button
        aria-pressed={listMode.value === 'cards'}
        title="Cards"
        onclick={() => listMode.set('cards')}
        ><Icon name="cards" size={15} /><span class="sl">Cards</span></button
      >
    </div>
  {/if}
  {#if operator && device.control === 'side'}
    <button
      class="btn"
      aria-pressed={panel.open}
      title={panel.open ? 'Hide control panel' : 'Show control panel'}
      onclick={() => panel.toggle()}
    >
      <Icon name="panel" size={15} /> Control
    </button>
  {/if}
{/snippet}

<style>
  .toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 12px;
    min-height: 52px;
    padding: 8px 16px;
    background: var(--surface);
    border-bottom: 1px solid var(--line);
  }

  .search {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 32px;
    /* Shrinks to 140 px before the toolbar wraps a line. */
    flex: 1 1 140px;
    min-width: 0; /* or the input's own width stops it shrinking */
    max-width: 260px;
    padding: 0 10px;
    border-radius: 8px;
    border: 1px solid var(--line);
    background: var(--app);
    color: var(--faint);
  }

  .phone {
    flex-wrap: nowrap;
    padding: 8px 12px;
  }

  .phone .search {
    flex: 1;
    width: auto;
    min-width: 0;
    height: 38px;
  }

  .phone .search input {
    font-size: 16px; /* smaller text makes iOS Safari zoom in on focus */
  }

  .search:focus-within {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }

  .search input {
    flex: 1;
    min-width: 0;
    border: 0;
    background: none;
    outline: none;
    color: var(--text);
    font-size: 13px;
  }

  .count {
    font-size: 13px;
    color: var(--muted);
    white-space: nowrap;
  }

  .count b {
    color: var(--text);
    font-weight: 650;
  }

  .grow {
    flex: 1;
  }

  .menuwrap {
    position: relative;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    height: 32px;
    padding: 0 12px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  .btn:hover,
  .btn[aria-expanded='true'] {
    background: var(--hover);
  }

  .btn[aria-pressed='true'] {
    border-color: var(--accent-line);
    background: var(--accent-soft);
    color: var(--accent);
  }

  .seg {
    display: flex;
    gap: 2px;
    padding: 2px;
    border-radius: var(--r-sm);
    background: var(--hover);
  }

  .seg button {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    border: 0;
    border-radius: 5px;
    background: none;
    color: var(--muted);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  /* Beside the Control panel on a sideways tablet the short forms fit one row. */
  @media (max-width: 1279px) {
    .sl {
      display: none;
    }
  }

  .seg button[aria-pressed='true'] {
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  /* Bulk selector: [ box │ count ▾ ] as one bordered control. */
  .bulk {
    position: relative;
    display: flex;
    align-items: stretch;
    height: 32px;
    border: 1px solid var(--line-strong);
    border-radius: var(--r-sm);
    background: var(--surface);
  }

  .bulk.on {
    border-color: var(--accent-line);
    background: var(--accent-soft);
  }

  .bcb {
    display: flex;
    align-items: center;
    padding: 0 10px;
    border-right: 1px solid var(--line-strong);
  }

  .bulk.on .bcb {
    border-right-color: var(--accent-line);
  }

  .bmenu {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0 8px 0 10px;
    border: 0;
    border-radius: 0 var(--r-sm) var(--r-sm) 0;
    background: none;
    color: var(--muted);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  .bmenu:hover,
  .bmenu[aria-expanded='true'] {
    background: var(--hover);
    color: var(--text);
  }

  .bulk.on .bmenu {
    color: var(--accent);
  }

  /* Wide enough for "999 selected", so the count never moves the search. */
  .blabel {
    min-width: 12ch;
    font-variant-numeric: tabular-nums;
    text-align: left;
    white-space: nowrap;
  }

  .phone .bulk {
    height: 38px;
  }

  .phone .blabel {
    min-width: 10ch;
  }

  .menu {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    z-index: 25;
    min-width: 210px;
    display: flex;
    flex-direction: column;
    padding: 5px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 11px;
    box-shadow: var(--sh-2);
  }

  .menu button {
    display: flex;
    align-items: center;
    gap: 9px;
    height: 32px;
    padding: 0 9px;
    border: 0;
    border-radius: 7px;
    background: none;
    font-size: 13px;
    text-align: left;
    cursor: pointer;
  }

  .menu button:hover {
    background: var(--hover);
  }

  .menu hr {
    width: 100%;
    margin: 4px 0;
    border: 0;
    border-top: 1px solid var(--line);
  }

  .gdot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex: none;
  }
</style>
