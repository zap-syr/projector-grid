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
    if (e.key === 'Escape') {
      // Esc closes an open menu first, then clears the selection.
      if (menu) menu = null;
      else if (operator && !control.pending) selection.clear();
    }
    // Ctrl/Cmd+A: every visible row, like the select-all box.
    if (operator && (e.ctrlKey || e.metaKey) && e.key === 'a' && !inField(e)) {
      e.preventDefault();
      selection.set(toggledAll(shown, new Set()));
    }
  }}
/>

<div class="toolbar">
  {#if operator}
    <div class="selall">
      <Checkbox
        state={triState(shown, selection.ids)}
        label="Select all shown"
        disabled={!shown.some(isSelectable)}
        onclick={() => selection.set(toggledAll(shown, selection.ids))}
      />
      <div class="menuwrap" bind:this={selectWrap}>
        <button
          class="btn quiet"
          aria-expanded={menu === 'select'}
          onclick={() => (menu = menu === 'select' ? null : 'select')}
        >
          Select <Icon name="chevron" size={14} />
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
            <hr />
            <button role="menuitem" onclick={() => pick({ kind: 'clear' })}>
              Clear <span class="kbd">Esc</span>
            </button>
          </div>
        {/if}
      </div>
    </div>
    <span class="count"><b>{selection.ids.size}</b> selected</span>
  {/if}
  <label class="search">
    <Icon name="search" size={15} />
    <input
      type="search"
      placeholder="Name, IP or serial"
      aria-label="Search"
      bind:value={view.search}
    />
  </label>
  <span class="count"><b>{shown.length}</b> of {live.projectors.length} shown</span>
  <div class="grow"></div>
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
  {#if operator}
    <button
      class="btn"
      aria-pressed={panel.open}
      title={panel.open ? 'Hide control panel' : 'Show control panel'}
      onclick={() => panel.toggle()}
    >
      <Icon name="panel" size={15} /> Control
    </button>
  {/if}
</div>

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
    width: 260px;
    max-width: 100%;
    padding: 0 10px;
    border-radius: 8px;
    border: 1px solid var(--line);
    background: var(--app);
    color: var(--faint);
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

  .btn.quiet {
    border-color: transparent;
    background: none;
    gap: 4px;
    padding: 0 8px;
    color: var(--muted);
  }

  .btn.quiet:hover,
  .btn.quiet[aria-expanded='true'] {
    background: var(--hover);
    color: var(--text);
  }

  .selall {
    display: flex;
    align-items: center;
    gap: 4px;
    padding-left: 12px;
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

  .kbd {
    margin-left: auto;
    padding: 0 4px;
    border: 1px solid var(--line);
    border-bottom-width: 2px;
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 11px;
    line-height: 16px;
    color: var(--faint);
  }
</style>
