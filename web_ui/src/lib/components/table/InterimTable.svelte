<!--
  Read-only table in the app's column layout, to see live data end to end.
  Replaced by DataTable (sort, resize, reorder, presets…) in WEB_UI_PLAN step 3.
-->
<script lang="ts">
  import type { ColumnId, Config, Projector } from '../../api/types';
  import { cellText, tempTint, testPatternLabel } from '../../logic/cells';
  import { live } from '../../state/live.svelte';

  let { config }: { config: Config } = $props();

  const labels = $derived(new Map(config.columns.map((c) => [c.id, c.label])));
  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const groups = $derived(new Map(live.groups.map((g) => [g.id, g])));
  const columns = $derived(config.layout.columns);

  function text(col: ColumnId, p: Projector) {
    return cellText(col, p, groups, (code) => testPatternLabel(code, patterns));
  }

  function tone(col: ColumnId, p: Projector): string {
    switch (col) {
      case 'connection':
        return p.connection === 'offline' ? 'err' : p.connection === 'unauthorized' ? 'warn' : 'ok';
      case 'power':
        return p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn';
      case 'shutter':
        return p.shutter === 'open' ? 'ok' : 'err';
      case 'intake':
        return tempTint(p.intakeTemp, config.thresholds.intake) ?? '';
      case 'exhaust':
        return tempTint(p.exhaustTemp, config.thresholds.exhaust) ?? '';
      case 'errors':
        return p.errors === '-' ? '' : p.errors === 'NO ERRORS' ? 'ok' : 'err';
      default:
        return '';
    }
  }
</script>

<div class="wrap">
  <table>
    <thead>
      <tr>
        {#each columns as col (col)}
          <th>{labels.get(col)}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each live.projectors as p (p.id)}
        <tr class:offline={p.connection === 'offline'}>
          {#each columns as col (col)}
            <td class={tone(col, p)}>{text(col, p)}</td>
          {/each}
        </tr>
      {:else}
        <tr>
          <td class="empty" colspan={columns.length}>No projectors in this project</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>

<style>
  .wrap {
    overflow: auto;
    background: var(--surface);
  }

  table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    font-size: 13.5px;
  }

  th {
    position: sticky;
    top: 0;
    background: var(--surface-2);
    height: 36px;
    padding: 0 10px;
    text-align: left;
    font-size: 12.5px;
    font-weight: 600;
    color: var(--muted);
    border-bottom: 1px solid var(--line);
    white-space: nowrap;
  }

  td {
    height: 40px;
    padding: 0 10px;
    border-bottom: 1px solid var(--line);
    white-space: nowrap;
  }

  tr.offline td {
    color: var(--faint);
  }

  td.ok {
    color: var(--ok);
    font-weight: 550;
  }

  td.err {
    color: var(--err);
    font-weight: 550;
  }

  td.warn,
  td.warm {
    color: var(--warn);
    font-weight: 600;
  }

  td.hot {
    color: var(--err);
    font-weight: 700;
  }

  .empty {
    padding: 48px 16px;
    text-align: center;
    color: var(--faint);
  }
</style>
