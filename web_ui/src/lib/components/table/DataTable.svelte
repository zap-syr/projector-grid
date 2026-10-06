<!--
  The app's Monitoring table (monitoring_table.dart) on the web: click a header
  to sort, drag it to reorder, drag its right edge to resize, double-click the
  edge to auto-fit; fit-to-width, density and group-by from the Columns menu.
-->
<script lang="ts">
  import type { ColumnId, Config, DataColumn, Density, Projector } from '../../api/types';
  import { cellText, testPatternLabel } from '../../logic/cells';
  import { renderedColumns, reorderColumn, resolveColumns } from '../../logic/columns';
  import { groupPills } from '../../logic/alerts';
  import { buildEntries, matchesFilter, matchesSearch, UNGROUPED } from '../../logic/rows';
  import { sortProjectors } from '../../logic/sort';
  import { alerts } from '../../state/alerts.svelte';
  import { autoFitWidth, layoutWidths, resizeBase, type ResizeStart } from '../../logic/widths';
  import { live } from '../../state/live.svelte';
  import { tableLayout, type StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import {
    draggedSelection,
    isSelectable,
    selectedRange,
    toggledAll,
    triState,
  } from '../../logic/selection';
  import { alignment } from '../../state/alignment.svelte';
  import { preview } from '../../state/preview.svelte';
  import { selection } from '../../state/selection.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';
  import Cell from './Cell.svelte';

  let {
    config,
    layout,
    operator,
  }: {
    config: Config;
    layout: StoredLayout;
    /** Adds the selection column; rows and group headers select on click. */
    operator: boolean;
  } = $props();

  /** The pinned checkbox column in operator mode. */
  const SELECT_W = 44;

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
  // No Remote Preview in Alignment mode.
  const cols = $derived(
    renderedColumns(visible, groupBy).filter(
      (c) => !alignment.active || c !== 'preview' || visible.length === 1,
    ),
  );
  const sortable = (c: ColumnId): c is DataColumn => c !== 'preview';
  // A sort column that's hidden falls back to the first shown, like the app.
  const sortColumn = $derived(
    cols.filter(sortable).find((c) => c === layout.sortColumn) ?? cols.find(sortable),
  );

  const shown = $derived(
    live.projectors.filter(
      (p) => matchesFilter(p, view.filter, alerts.byProjector) && matchesSearch(p, view.search),
    ),
  );
  const sorted = $derived(
    sortColumn
      ? sortProjectors(shown, sortColumn, layout.sortAscending, groupMap, patternText)
      : shown,
  );
  const entries = $derived(buildEntries(sorted, live.groups, groupBy, new Set(layout.collapsed)));

  const metrics = $derived(DENSITY[layout.density]);
  let viewport = $state(0);
  /**
   * The pinned first column: the operator's checkboxes, or in Alignment mode
   * everyone's role markers (focused filled, shown ring, closed faint).
   */
  const lead = $derived(operator || alignment.active);
  /** What the data columns share once the lead column is taken out. */
  const dataViewport = $derived(lead ? viewport - SELECT_W : viewport);

  // ── Selection (operator) ────────────────────────────────────────────────
  const rowOrder = $derived(entries.flatMap((e) => (e.kind === 'row' ? [e.projector] : [])));

  function rowClick(e: MouseEvent, p: Projector) {
    if (!operator || !isSelectable(p)) return;
    if (e.shiftKey) {
      selection.set(selectedRange(rowOrder, selection.anchor, p.id, selection.ids));
    } else {
      selection.toggle(p.id);
    }
  }

  const rowIdAt = (x: number, y: number) =>
    document.elementFromPoint(x, y)?.closest<HTMLElement>('tr[data-id]')?.dataset.id;

  /**
   * Pointer selection on rows — the row's checkbox is the keyboard path, so
   * one delegated listener does. With a mouse the pressed row toggles right
   * away on press, and dragging on sweeps every row passed the same way (in,
   * or out when the pressed row was selected); Shift-click adds a range.
   * Touch toggles on a tap instead, so a swipe still scrolls.
   */
  function rowPointer(tbody: HTMLElement) {
    let sweep: { from: string; base: Set<string>; over: string } | null = null;
    let tap: string | null = null;

    const onMove = (e: PointerEvent) => {
      if (!sweep) return;
      const id = rowIdAt(e.clientX, e.clientY);
      if (!id || id === sweep.over) return;
      sweep.over = id;
      selection.set(draggedSelection(rowOrder, sweep.base, sweep.from, id));
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      sweep = null;
    };

    const onDown = (e: PointerEvent) => {
      if (!operator || e.button !== 0) return;
      // The checkbox handles its own click (and would be toggled twice).
      if ((e.target as Element).closest('button')) return;
      const id = (e.target as Element).closest<HTMLElement>('tr[data-id]')?.dataset.id;
      // Alignment mode: a row in the mode takes the focus, nothing else (on
      // touch at the tap's end, so a swipe still scrolls).
      if (alignment.active) {
        if (!id || !alignment.role(id)) return;
        if (e.pointerType === 'mouse') alignment.focus(id);
        else tap = id;
        return;
      }
      const p = id ? live.projectors.find((x) => x.id === id) : undefined;
      if (!p || !isSelectable(p)) return;
      if (e.pointerType !== 'mouse') {
        tap = p.id;
        return;
      }
      e.preventDefault(); // no text selection while sweeping
      if (e.shiftKey) {
        rowClick(e, p);
        return;
      }
      sweep = { from: p.id, base: new Set(selection.ids), over: p.id };
      // The pressed row changes now, so what the sweep does is visible at once.
      selection.set(draggedSelection(rowOrder, sweep.base, p.id, p.id));
      selection.anchor = p.id;
      window.addEventListener('pointermove', onMove);
      window.addEventListener('pointerup', onUp);
    };
    const onTapUp = (e: PointerEvent) => {
      if (tap && rowIdAt(e.clientX, e.clientY) === tap) {
        if (alignment.active) alignment.focus(tap);
        else selection.toggle(tap);
      }
      tap = null;
    };
    const onTapCancel = () => (tap = null); // the finger scrolled instead

    tbody.addEventListener('pointerdown', onDown);
    tbody.addEventListener('pointerup', onTapUp);
    tbody.addEventListener('pointercancel', onTapCancel);
    return () => {
      onUp();
      tbody.removeEventListener('pointerdown', onDown);
      tbody.removeEventListener('pointerup', onTapUp);
      tbody.removeEventListener('pointercancel', onTapCancel);
    };
  }

  // ── Resize ──────────────────────────────────────────────────────────────
  let resizing = $state<{ col: ColumnId; x0: number; dx: number; start: ResizeStart } | null>(null);
  const baseWidths = $derived(
    cols.map((c) =>
      resizing?.col === c
        ? resizeBase(resizing.start, resizing.dx, config.minColumnWidth)
        : (layout.widths[c] ?? defaultWidths.get(c) ?? 120),
    ),
  );
  const sized = $derived(layoutWidths(baseWidths, dataViewport, layout.fitToWidth));

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
        viewport: dataViewport,
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
    const td = table?.querySelector('tbody td.dc') ?? th;
    // Preview's cells are all one small button; its label decides.
    const cells = sortable(col)
      ? live.projectors.map(
          (p) => textWidth(cellText(col, p, groupMap, patternLabel), td) + (ICON_PAD[col] ?? 0) + 1,
        )
      : [];
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
    if (!suppressClick && sortable(col)) tableLayout.sortBy(col);
  }

  // ── Remote Preview ──────────────────────────────────────────────────────
  /** ◀ ▶ walk the rows as shown: sorted, filtered, collapsed groups left out. */
  const openPreview = (id: string) =>
    preview.open(
      rowOrder.map((p) => p.id),
      id,
    );

  const ariaSort = (col: ColumnId) =>
    col !== sortColumn ? undefined : layout.sortAscending ? 'ascending' : 'descending';
</script>

<div class="scroller" bind:clientWidth={viewport}>
  <table
    bind:this={table}
    class={layout.density}
    class:resizing={resizing !== null}
    class:op={lead}
    style:width="{sized.tableWidth + (lead ? SELECT_W : 0)}px"
    style:--selw="{SELECT_W}px"
    style:--row="{metrics.row}px"
    style:--head="{metrics.header}px"
    style:--hpad="{metrics.hpad}px"
  >
    <colgroup>
      {#if lead}
        <col style:width="{SELECT_W}px" />
      {/if}
      {#each cols as col, i (col)}
        <col style:width="{sized.widths[i]}px" />
      {/each}
    </colgroup>
    <thead>
      <tr>
        {#if lead}
          <th class="selc"><span class="sr">{alignment.active ? 'Role' : 'Select'}</span></th>
        {/if}
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
    <tbody {@attach rowPointer}>
      {#each entries as entry (entry.kind === 'group' ? `g:${entry.key}` : entry.projector.id)}
        {#if entry.kind === 'group'}
          {@const open = !layout.collapsed.includes(entry.key)}
          {@const pills = groupPills(entry.members, alerts.list)}
          <tr class="grp" style:--gcolor={entry.group?.color ?? 'var(--line-strong)'}>
            <td colspan={cols.length + (lead ? 1 : 0)}>
              <div class="grpcell">
                {#if operator && !alignment.active}
                  <Checkbox
                    state={triState(entry.members, selection.ids)}
                    label="Select {entry.group?.name ?? 'Ungrouped'}"
                    disabled={!entry.members.some(isSelectable)}
                    onclick={() => selection.set(toggledAll(entry.members, selection.ids))}
                  />
                {/if}
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
                {#each pills as pill (pill.text)}
                  <span class="pill {pill.tone}">{pill.text}</span>
                {/each}
              </div>
            </td>
          </tr>
        {:else}
          {@const p = entry.projector}
          {@const selected = selection.ids.has(p.id)}
          {@const role = alignment.role(p.id)}
          <tr
            class="row {role ?? ''}"
            class:stripe={entry.stripe}
            class:offline={p.connection === 'offline'}
            class:outside={alignment.active && !role}
            class:sel={operator && selected && !alignment.active}
            class:pick={operator && (alignment.active ? role !== null : isSelectable(p))}
            data-id={p.id}
          >
            {#if alignment.active}
              <td class="selc">
                <span
                  class="mk {role ?? 'none'}"
                  role="img"
                  aria-label={role
                    ? `${role[0]?.toUpperCase()}${role.slice(1)}`
                    : 'Not in the mode'}
                ></span>
              </td>
            {:else if operator}
              <td class="selc">
                <Checkbox
                  state={selected}
                  label="Select {p.name}"
                  disabled={!isSelectable(p)}
                  onclick={(e) => rowClick(e, p)}
                />
              </td>
            {/if}
            {#each cols as col (col)}
              {#if sortable(col)}
                <td class="dc">
                  <Cell column={col} {p} groups={groupMap} {patternLabel} />
                </td>
              {:else}
                <td class="pvc">
                  {#if !alignment.active}
                    <button
                      class="pvb"
                      aria-label="Preview {p.name}"
                      title="Remote Preview"
                      onclick={() => openPreview(p.id)}
                    >
                      <Icon name="preview" size={17} />
                    </button>
                  {/if}
                </td>
              {/if}
            {/each}
          </tr>
        {/if}
      {:else}
        <tr>
          <td class="empty" colspan={cols.length + (lead ? 1 : 0)}>
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

  /* Operator mode: the checkbox column and the first data column stay pinned. */
  .op th:nth-child(2),
  .op tr.row td:nth-child(2) {
    position: sticky;
    left: var(--selw);
  }

  .op th:nth-child(2) {
    z-index: 3;
  }

  .op tr.row td:nth-child(2) {
    z-index: 1;
    background: var(--row-bg);
  }

  .selc {
    padding: 0;
    text-align: center;
  }

  .sr {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip-path: inset(50%);
  }

  tr.row.pick {
    cursor: pointer;
  }

  tr.row.sel td.selc {
    box-shadow: inset 3px 0 0 var(--accent);
  }

  /* Pinned cells paint the row's colour themselves: it must be opaque, or
     cells scrolled underneath show through. */
  tr.row td:first-child {
    z-index: 1;
    background: var(--row-bg);
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

  /* Every row colour is opaque (see the pinned cells above). Selection comes
     last so it wins over the stripe on every row. */
  tr.row {
    --row-bg: var(--surface);
    background: var(--row-bg);
  }

  tr.row.stripe {
    --row-bg: var(--surface-2);
  }

  tr.row:hover {
    --row-bg: var(--hover);
  }

  tr.row.sel {
    --row-bg: color-mix(in srgb, var(--accent) 14%, var(--surface));
  }

  tr.row.sel:hover {
    --row-bg: color-mix(in srgb, var(--accent) 20%, var(--surface));
  }

  tr.row.offline td {
    color: var(--faint);
  }

  /* Alignment mode: the focused row tinted, closed and out-of-mode rows dimmed. */
  tr.row.focused {
    --row-bg: color-mix(in srgb, var(--align) 16%, var(--surface));
  }

  tr.row.focused td.selc {
    box-shadow: inset 3px 0 0 var(--align);
  }

  tr.row.closed td.dc,
  tr.row.outside td.dc {
    opacity: 0.45;
  }

  /* Preview: one icon button per row; a finger gets the row's full height. */
  .pvc {
    padding: 0 calc(var(--hpad) - 8px);
  }

  .pvb {
    width: 34px;
    height: min(30px, var(--row) - 4px);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    vertical-align: middle;
    cursor: pointer;
  }

  @media (hover: hover) {
    .pvb:hover {
      background: var(--accent-soft);
      color: var(--accent);
    }
  }

  @media (pointer: coarse) {
    .pvb {
      width: 44px;
      height: min(44px, var(--row) - 4px);
    }
  }

  .mk {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    vertical-align: middle;
  }

  .mk.focused {
    background: var(--align);
  }

  .mk.shown {
    box-shadow: inset 0 0 0 2.5px var(--align-2);
  }

  .mk.closed {
    box-shadow: inset 0 0 0 1.5px var(--line-strong);
  }

  .mk.none {
    width: 10px;
    height: 2px;
    border-radius: 1px;
    background: var(--line-strong);
  }

  tr.grp td {
    /* A clipping cell becomes the sticky group label's scroll box, and the
       label would scroll away with the table instead of staying at the left. */
    overflow: visible;
    height: var(--row);
    padding: 0;
    background: var(--app);
  }

  /* Pinned with the label, the group's colour bar stays at the left edge too. */
  .grpcell {
    position: sticky;
    left: 0;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-height: var(--row);
    padding: 0 var(--hpad) 0 calc(var(--hpad) - 6px);
    box-shadow: inset 3px 0 0 var(--gcolor);
    vertical-align: middle;
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

  .pill.crit {
    background: var(--err-soft);
    color: var(--err);
  }

  .pill.warn {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .pill.ok {
    background: var(--ok-soft);
    color: var(--ok);
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
