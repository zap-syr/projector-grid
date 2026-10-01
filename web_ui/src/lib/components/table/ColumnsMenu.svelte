<!-- View ▸ Monitoring Table from the app, as a popover. Reordering is done by dragging headers. -->
<script lang="ts">
  import type { Config, Density } from '../../api/types';
  import {
    resolveColumns,
    tableCatalogue,
    tableDefaults,
    toggledColumn,
    withPreview,
  } from '../../logic/columns';
  import { live } from '../../state/live.svelte';
  import { tableLayout, type StoredLayout } from '../../state/tableLayout.svelte';

  let { config, layout }: { config: Config; layout: StoredLayout } = $props();

  const columns = $derived(tableCatalogue(config));
  const catalogue = $derived(columns.map((c) => c.id));
  const visible = $derived(resolveColumns(layout.columns, catalogue, tableDefaults(config)));
  const densities: Density[] = ['compact', 'standard', 'comfortable'];
  const cap = (s: string) => s[0]?.toUpperCase() + s.slice(1);
</script>

<div class="menu" role="dialog" aria-label="Columns">
  <section>
    <h6>Columns</h6>
    <div class="list">
      {#each columns as c (c.id)}
        {@const on = visible.includes(c.id)}
        <label class="item">
          <input
            type="checkbox"
            checked={on}
            disabled={on && visible.length === 1}
            onchange={() => {
              const next = toggledColumn(visible, c.id, catalogue);
              if (next) tableLayout.update({ columns: next });
            }}
          />
          {c.label}
        </label>
      {/each}
    </div>
  </section>

  <section>
    <h6>Presets</h6>
    <div class="presets">
      {#each config.presets as p (p.name)}
        <button
          onclick={() =>
            tableLayout.update({ columns: withPreview(p.columns, visible.includes('preview')) })}
          >{p.name}</button
        >
      {/each}
      <button
        class="quiet"
        title="Back to the app's layout"
        onclick={() => tableLayout.reset(config)}>Reset</button
      >
    </div>
  </section>

  <section>
    <h6>Row density</h6>
    <div class="seg" role="group" aria-label="Row density">
      {#each densities as d (d)}
        <button
          aria-pressed={layout.density === d}
          onclick={() => tableLayout.update({ density: d })}>{cap(d)}</button
        >
      {/each}
    </div>
  </section>

  <section class="opts">
    <label class="opt">
      Fit columns to window
      <input
        type="checkbox"
        role="switch"
        checked={layout.fitToWidth}
        onchange={() => tableLayout.update({ fitToWidth: !layout.fitToWidth })}
      />
    </label>
    <label class="opt" class:dis={live.groups.length === 0}>
      Merge into groups
      <input
        type="checkbox"
        role="switch"
        checked={layout.groupBy && live.groups.length > 0}
        disabled={live.groups.length === 0}
        onchange={() => tableLayout.update({ groupBy: !layout.groupBy })}
      />
    </label>
  </section>
</div>

<style>
  .menu {
    position: absolute;
    top: calc(100% + 6px);
    right: 0;
    z-index: 25;
    width: 300px;
    max-height: calc(100vh - 140px);
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 12px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 12px;
    box-shadow: var(--sh-2);
  }

  section {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  h6 {
    margin: 0;
    font-size: 11.5px;
    font-weight: 650;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--faint);
  }

  .list {
    display: flex;
    flex-direction: column;
    margin: 0 -4px;
  }

  .item,
  .opt {
    display: flex;
    align-items: center;
    gap: 9px;
    min-height: 30px;
    padding: 0 6px;
    border-radius: 7px;
    font-size: 13px;
    cursor: pointer;
  }

  .item:hover,
  .opt:hover {
    background: var(--hover);
  }

  .opt {
    justify-content: space-between;
  }

  .opt.dis {
    color: var(--faint);
    cursor: default;
  }

  input[type='checkbox'] {
    accent-color: var(--accent);
    width: 15px;
    height: 15px;
    margin: 0;
  }

  .presets {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .presets button {
    height: 28px;
    padding: 0 10px;
    border-radius: 7px;
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-size: 12.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .presets button:hover {
    border-color: var(--accent);
    color: var(--accent);
  }

  .presets button.quiet {
    border-color: transparent;
    color: var(--muted);
  }

  .seg {
    display: grid;
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: 2px;
    padding: 3px;
    border-radius: 8px;
    background: var(--hover);
  }

  .seg button {
    height: 28px;
    border: 0;
    border-radius: 6px;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .seg button[aria-pressed='true'] {
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  .opts {
    gap: 2px;
    margin: 0 -4px;
  }
</style>
