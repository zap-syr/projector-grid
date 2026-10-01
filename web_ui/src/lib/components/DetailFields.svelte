<!-- A projector's fields as label / value pairs, for the card and Map details. -->
<script lang="ts">
  import type { ColumnId, Config, DataColumn, Group, Projector } from '../api/types';
  import Cell from './table/Cell.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    skip,
    min = 190,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    /** Fields already shown elsewhere (the card's summary, the popover header). */
    skip: readonly ColumnId[];
    /** Narrowest field column, px. */
    min?: number;
  } = $props();

  // Preview has its own button in the details, not a field.
  const fields = $derived(
    config.columns.filter(
      (c): c is typeof c & { id: DataColumn } => c.id !== 'preview' && !skip.includes(c.id),
    ),
  );
</script>

<dl style:--min="{min}px">
  {#each fields as c (c.id)}
    <div class="f">
      <dt>{c.label}</dt>
      <dd>
        <Cell column={c.id} {p} {groups} thresholds={config.thresholds} {patternLabel} />
      </dd>
    </div>
  {/each}
</dl>

<style>
  dl {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(var(--min), 1fr));
    gap: 10px 20px;
    margin: 0;
    padding: 6px 16px 14px;
    font-size: 13px;
  }

  .f {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
  }

  dt {
    font-size: 11.5px;
    color: var(--faint);
  }

  dd {
    margin: 0;
    min-width: 0;
  }
</style>
