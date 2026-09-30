<!--
  The app's Monitoring table (monitoring_table.dart) on the web: click a header
  to sort, drag it to reorder, drag its right edge to resize, double-click the
  edge to auto-fit; fit-to-width, density and group-by from the Columns menu.
-->
<script lang="ts">
  import type { ColumnId, Config, Density, Projector } from '../../api/types';
  import { cellText, testPatternLabel } from '../../logic/cells';
  import { renderedColumns, reorderColumn, resolveColumns } from '../../logic/columns';
  import {
    buildEntries,
    matchesFilter,
    matchesSearch,
    UNGROUPED,
    worstStatus,
  } from '../../logic/rows';
  import { sortProjectors } from '../../logic/sort';
  import { autoFitWidth, layoutWidths, resizeBase, type ResizeStart } from '../../logic/widths';
  import { live } from '../../state/live.svelte';
  import { tableLayout, type StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import Icon from '../Icon.svelte';
  import Cell from './Cell.svelte';

  let { config, layout }: { config: Config; layout: StoredLayout } = $props();

  /** Row / header height and cell padding per density (`_densityMetrics`). */
  const DENSITY: Record<Density, { row: number; header: number; hpad: number }> = {
    compact: { row: 32, header: 40, hpad: 10 },
    standard: { row: 40, header: 48, hpad: 16 },
    comfortable: { row: 52, header: 56, hpad: 20 },
  };

  /** Width of what a cell draws before/after its text, for auto-fit (`iconPad`). */
  const ICON_PAD: Partial<Record<ColumnId, number>> = {
    connection: 34,
    power: 21,
    shutter: 21,
    group: 16,
    testPattern: 26,
    errors: 20,
  };

  const catalogue = $derived(config.columns.map((c) => c.id));
  const labels = $derived(new Map(config.columns.map((c) => [c.id, c.label])));
  const defaultWidths = $derived(new Map(config.columns.map((c) => [c.id, c.defaultWidth])));
  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));
  const patternLabel = (code: string) => testPatternLabel(code, patterns);
  const patternText = (p: Projector) =>
    p.testPattern === null ? '-' : patternLabel(p.testPattern);

  const visible = $derived(resolveColumns(layout.columns, catalogue, config.defaultColumns));
  const groupBy = $derived(layout.groupBy && live.groups.length > 0);
  const cols = $derived(renderedColumns(visible, groupBy));
  // A sort column that's hidden falls back to the first shown, like the app.
  const sortColumn = $derived(cols.includes(layout.sortColumn) ? layout.sortColumn : cols[0]);

  const shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search)),
  );
  const sorted = $derived(
    sortColumn
      ? sortProjectors(shown, sortColumn, layout.sortAscending, groupMap, patternText)
      : shown,
  );
  const entries = $derived(buildEntries(sorted, live.groups, groupBy, new Set(layout.collapsed)));

  const metrics = $derived(DENSITY[layout.density]);
  let viewport = $state(0);

  // ── Resize ──────────────────────────────────────────────────────────────
  let resizing = $state<{ col: ColumnId; x0: number; dx: number; start: ResizeStart } | null>(null);
  const baseWidths = $derived(
    cols.map((c) =>
      resizing?.col === c
        ? resizeBase(resizing.start, resizing.dx, config.minColumnWidth)
        : (layout.widths[c] ?? defaultWidths.get(c) ?? 120),
    ),
  );
  const sized = $derived(layoutWidths(baseWidths, viewport, layout.fitToWidth));

  function resizeDown(e: PointerEvent, i: number) {
    if (e.button !== 0) return;
    e.stopPropagation();
    e.preventDefault(); // no text selection while dragging
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    const col = cols[i];
    if (!col) return;
    const total = baseWidths.reduce((a, b) => a + b, 0);
    resizing = {
      col,
      x0: e.clientX,
      dx: 0,
      start: {
        startWidth: sized.widths[i] ?? 0,
        otherBase: total - (baseWidths[i] ?? 0),
        viewport,
        scaling: sized.scaling,
      },
    };
  }

  function resizeMove(e: PointerEvent) {
    if (resizing) resizing.dx = e.clientX - resizing.x0;
  }

  function resizeUp() {
    const r = resizing;
    resizing = null;
    if (r && r.dx !== 0) {
      tableLayout.setWidth(r.col, resizeBase(r.start, r.dx, config.minColumnWidth));
    }
  }

  // ── Auto-fit (double-click the edge) ────────────────────────────────────
  let table = $state<HTMLTableElement>();
  const canvas = typeof document === 'undefined' ? null : document.createElement('canvas');

  function textWidth(text: string, el: Element | null | undefined): number {
    const ctx = canvas?.getContext('2d');
    if (!ctx || !el) return 0;
    ctx.font = getComputedStyle(el).font;
    return ctx.measureText(text).width;
  }

  function autoFit(col: ColumnId) {
    const th = table?.querySelector(`th[data-col="${col}"] .lbl`);
    const td = table?.querySelector('tbody td') ?? th;
    const cells = live.projectors.map(
      (p) => textWidth(cellText(col, p, groupMap, patternLabel), td) + (ICON_PAD[col] ?? 0) + 1,
    );
    tableLayout.setWidth(
      col,
      autoFitWidth(
        textWidth(labels.get(col) ?? col, th) + 18,
        cells,
        metrics.hpad * 2,
        config.minColumnWidth,
      ),
    );
  }

  // ── Reorder (drag a header) ─────────────────────────────────────────────
  let press: { col: ColumnId; x: number; y: number } | null = null;
  let dragging = $state<{ col: ColumnId; x: number; y: number } | null>(null);
  let dropTarget = $state<ColumnId | null>(null);
  let suppressClick = false;

  function headerDown(e: PointerEvent, col: ColumnId) {
    if (e.button !== 0) return;
    e.preventDefault(); // no text selection while dragging
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    press = { col, x: e.clientX, y: e.clientY };
  }

  function headerMove(e: PointerEvent) {
    if (!press) return;
    if (!dragging && Math.hypot(e.clientX - press.x, e.clientY - press.y) < 5) return;
    dragging = { col: press.col, x: e.clientX, y: e.clientY };
    const over = document
      .elementFromPoint(e.clientX, e.clientY)
      ?.closest<HTMLElement>('th[data-col]')?.dataset.col as ColumnId | undefined;
    dropTarget = over && over !== press.col ? over : null;
  }

  function headerUp() {
    if (dragging) {
      // Swallow the click the browser may fire right after this pointerup
      // (it doesn't always), without eating a later real click.
      suppressClick = true;
      setTimeout(() => (suppressClick = false));
      if (dropTarget) {
        tableLayout.update({ columns: reorderColumn(visible, dragging.col, dropTarget) });
      }
    }
    press = null;
    dragging = null;
    dropTarget = null;
  }

  function headerClick(col: ColumnId) {
    if (!suppressClick) tableLayout.sortBy(col);
  }

  const ariaSort = (col: ColumnId) =>
    col !== sortColumn ? undefined : layout.sortAscending ? 'ascending' : 'descending';
</script>

<div class="scroller" bind:clientWidth={viewport}>
  <table
    bind:this={table}
    class={layout.density}
    class:resizing={resizing !== null}
    style:width="{sized.tableWidth}px"
    style:--row="{metrics.row}px"
    style:--head="{metrics.header}px"
    style:--hpad="{metrics.hpad}px"
  >
    <colgroup>
      {#each cols as col, i (col)}
        <col style:width="{sized.widths[i]}px" />
      {/each}
    </colgroup>
    <thead>
      <tr>
        {#each cols as col, i (col)}
          <th
            data-col={col}
            aria-sort={ariaSort(col)}
            class:sorted={col === sortColumn}
            class:dragged={dragging?.col === col}
            class:drop={dropTarget === col}
          >
            <button
              class="thc"
              onpointerdown={(e) => headerDown(e, col)}
              onpointermove={headerMove}
              onpointerup={headerUp}
              onpointercancel={headerUp}
              onclick={() => headerClick(col)}
            >
              <span class="lbl">{labels.get(col)}</span>
              {#if col === sortColumn}
                <span class="si" class:desc={!layout.sortAscending}
                  ><Icon name="arrow" size={13} /></span
                >
              {/if}
            </button>
            <span
              class="rz"
              class:on={resizing?.col === col}
              role="separator"
              aria-orientation="vertical"
              aria-label="Resize {labels.get(col)}"
              onpointerdown={(e) => resizeDown(e, i)}
              onpointermove={resizeMove}
              onpointerup={resizeUp}
              onpointercancel={resizeUp}
              ondblclick={(e) => {
                e.stopPropagation();
                autoFit(col);
              }}
            ></span>
          </th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each entries as entry (entry.kind === 'group' ? `g:${entry.key}` : entry.projector.id)}
        {#if entry.kind === 'group'}
          {@const open = !layout.collapsed.includes(entry.key)}
          {@const worst = worstStatus(entry.members)}
          <tr class="grp" style:--gcolor={entry.group?.color ?? 'var(--line-strong)'}>
            <td colspan={cols.length}>
              <div class="grpcell">
                <button
                  class="chev"
                  class:closed={!open}
                  aria-expanded={open}
                  aria-label="{open ? 'Collapse' : 'Expand'} {entry.group?.name ?? 'Ungrouped'}"
                  onclick={() => tableLayout.toggleCollapsed(entry.key)}
                >
                  <Icon name="chevron" size={15} />
                </button>
                <span class="gdot" class:none={entry.key === UNGROUPED}></span>
                <b>{entry.group?.name ?? 'Ungrouped'}</b>
                <span class="cnt"
                  >{entry.members.length} projector{entry.members.length === 1 ? '' : 's'}</span
                >
                {#if worst}
                  <span class="pill {worst.tone}">{worst.text}</span>
                {/if}
              </div>
            </td>
          </tr>
        {:else}
          {@const p = entry.projector}
          <tr class="row" class:stripe={entry.stripe} class:offline={p.connection === 'offline'}>
            {#each cols as col (col)}
              <td>
                <Cell
                  column={col}
                  {p}
                  groups={groupMap}
                  thresholds={config.thresholds}
                  {patternLabel}
                />
              </td>
            {/each}
          </tr>
        {/if}
      {:else}
        <tr>
          <td class="empty" colspan={cols.length}>
            {live.projectors.length === 0 ? 'No projectors in this project' : 'No projectors match'}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>

{#if dragging}
  <div class="ghost" style:left="{dragging.x + 12}px" style:top="{dragging.y + 10}px">
    {labels.get(dragging.col)}
  </div>
{/if}

<style>
  .scroller {
    height: 100%;
    overflow: auto;
    background: var(--surface);
    scrollbar-gutter: stable;
  }

  table {
    table-layout: fixed;
    border-collapse: separate;
    border-spacing: 0;
    font-size: 13.5px;
  }

  table.compact {
    font-size: 12.5px;
  }

  table.resizing {
    cursor: col-resize;
    user-select: none;
  }

  th {
    position: sticky;
    top: 0;
    z-index: 2;
    height: var(--head);
    padding: 0;
    background: var(--surface-2);
    border-bottom: 1px solid var(--line);
    text-align: left;
    user-select: none;
  }

  th:first-child,
  tr.row td:first-child {
    position: sticky;
    left: 0;
  }

  th:first-child {
    z-index: 3;
  }

  tr.row td:first-child {
    z-index: 1;
    background: inherit;
  }

  .thc {
    display: flex;
    align-items: center;
    gap: 4px;
    width: 100%;
    height: 100%;
    padding: 0 var(--hpad);
    border: 0;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
    text-align: left;
    cursor: pointer;
    touch-action: none;
  }

  .thc:hover {
    color: var(--text);
  }

  .lbl {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  th.sorted .thc {
    color: var(--text);
  }

  .si {
    display: flex;
    color: var(--accent);
    transition: transform 0.12s;
  }

  .si.desc {
    transform: rotate(180deg);
  }

  th.dragged .thc {
    opacity: 0.35;
  }

  th.drop {
    background: var(--accent-soft);
    box-shadow: inset 0 -2px 0 var(--accent);
  }

  .rz {
    position: absolute;
    top: 0;
    right: 0;
    width: 8px;
    height: 100%;
    cursor: col-resize;
    z-index: 4;
    touch-action: none;
  }

  .rz::after {
    content: '';
    position: absolute;
    top: 20%;
    right: 0;
    width: 2px;
    height: 60%;
    border-radius: 1px;
    background: transparent;
  }

  th:hover .rz::after {
    background: var(--line-strong);
  }

  .rz:hover::after,
  .rz.on::after {
    top: 0;
    height: 100%;
    background: var(--accent);
  }

  td {
    height: var(--row);
    padding: 0 var(--hpad);
    border-bottom: 1px solid var(--line);
    white-space: nowrap;
    overflow: hidden;
  }

  tr.row {
    background: var(--surface);
  }

  tr.row.stripe {
    background: var(--surface-2);
  }

  tr.row:hover {
    background: var(--hover);
  }

  tr.row.offline td {
    color: var(--faint);
  }

  tr.grp td {
    padding: 0;
    background: var(--app);
    box-shadow: inset 3px 0 0 var(--gcolor);
  }

  .grpcell {
    position: sticky;
    left: 0;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 0 var(--hpad) 0 calc(var(--hpad) - 6px);
  }

  .grpcell b {
    font-weight: 650;
  }

  .chev {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 6px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .chev:hover {
    background: var(--hover);
  }

  .chev.closed :global(svg) {
    transform: rotate(-90deg);
  }

  .gdot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: var(--gcolor);
  }

  .gdot.none {
    background: none;
    border: 1.5px solid var(--line-strong);
  }

  .cnt {
    font-size: 12px;
    color: var(--faint);
  }

  .pill {
    padding: 1px 8px;
    border-radius: 999px;
    font-size: 11.5px;
    font-weight: 550;
  }

  .pill.err {
    background: var(--err-soft);
    color: var(--err);
  }

  .pill.warn {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .empty {
    height: auto;
    padding: 48px 16px;
    text-align: center;
    color: var(--faint);
  }

  .ghost {
    position: fixed;
    z-index: 50;
    pointer-events: none;
    padding: 5px 10px;
    border-radius: var(--r-sm);
    background: var(--surface);
    border: 1px solid var(--accent);
    color: var(--accent);
    font-size: 12.5px;
    font-weight: 600;
    box-shadow: var(--sh-2);
  }
</style>
