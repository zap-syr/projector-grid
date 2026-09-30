<script lang="ts">
  import type { Config } from '../../api/types';
  import { matchesFilter, matchesSearch } from '../../logic/rows';
  import { live } from '../../state/live.svelte';
  import type { StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import Icon from '../Icon.svelte';
  import ColumnsMenu from '../table/ColumnsMenu.svelte';

  let { config, layout }: { config: Config; layout: StoredLayout } = $props();

  const shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search))
      .length,
  );

  let menuOpen = $state(false);
  let wrap = $state<HTMLElement>();

  function onWindowPointer(e: PointerEvent) {
    if (menuOpen && wrap && !wrap.contains(e.target as Node)) menuOpen = false;
  }
</script>

<svelte:window
  onpointerdown={onWindowPointer}
  onkeydown={(e) => {
    if (e.key === 'Escape') menuOpen = false;
  }}
/>

<div class="toolbar">
  <label class="search">
    <Icon name="search" size={15} />
    <input
      type="search"
      placeholder="Name, IP or serial"
      aria-label="Search"
      bind:value={view.search}
    />
  </label>
  <span class="count"><b>{shown}</b> of {live.projectors.length} shown</span>
  <div class="grow"></div>
  <div class="menuwrap" bind:this={wrap}>
    <button class="btn" aria-expanded={menuOpen} onclick={() => (menuOpen = !menuOpen)}>
      <Icon name="columns" size={15} /> Columns
    </button>
    {#if menuOpen}
      <ColumnsMenu {config} {layout} />
    {/if}
  </div>
</div>

<style>
  .toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
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
</style>
