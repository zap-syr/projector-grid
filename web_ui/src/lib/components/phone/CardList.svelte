<!--
  Projector cards in layout order: one collapsible section per group
  (ungrouped last), or a plain grid when the project has no groups.
-->
<script lang="ts">
  import type { Config } from '../../api/types';
  import { testPatternLabel } from '../../logic/cells';
  import {
    buildEntries,
    type CardEntry,
    matchesFilter,
    matchesSearch,
    UNGROUPED,
    withDetails,
    worstStatus,
  } from '../../logic/rows';
  import { isSelectable, toggledAll, triState } from '../../logic/selection';
  import { alignment } from '../../state/alignment.svelte';
  import { live } from '../../state/live.svelte';
  import { selection } from '../../state/selection.svelte';
  import { tableLayout, type StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';
  import CardDetails from './CardDetails.svelte';
  import ProjectorCard from './ProjectorCard.svelte';

  let { config, layout, operator }: { config: Config; layout: StoredLayout; operator: boolean } =
    $props();

  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const patternLabel = (code: string) => testPatternLabel(code, patterns);
  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));

  // The API sends projectors in layout order, which is the order on the wall.
  const shown = $derived(
    live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search)),
  );
  /** One card's details are open at a time. */
  let openId = $state<string | null>(null);
  const toggleOpen = (id: string) => (openId = openId === id ? null : id);

  /** Grid columns right now — the details strip goes after the open card's row. */
  let columns = $state(1);
  function trackColumns(list: HTMLElement) {
    const measure = () =>
      (columns = Math.max(1, getComputedStyle(list).gridTemplateColumns.split(' ').length));
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(list);
    return () => ro.disconnect();
  }

  const entries = $derived(
    withDetails(
      buildEntries(shown, live.groups, live.groups.length > 0, new Set(layout.collapsed)),
      openId,
      columns,
    ),
  );
  const entryKey = (e: CardEntry) =>
    e.kind === 'group' ? `g:${e.key}` : e.kind === 'details' ? e.key : e.projector.id;
</script>

<div class="list" {@attach trackColumns}>
  {#each entries as entry (entryKey(entry))}
    {#if entry.kind === 'details'}
      <CardDetails
        p={entry.projector}
        {config}
        groups={groupMap}
        {patternLabel}
        column={entry.column}
        {columns}
        onclose={() => (openId = null)}
      />
    {:else if entry.kind === 'group'}
      {@const open = !layout.collapsed.includes(entry.key)}
      {@const worst = worstStatus(entry.members)}
      {@const name = entry.group?.name ?? 'Ungrouped'}
      <div class="grp" style:--gcolor={entry.group?.color ?? 'var(--line-strong)'}>
        {#if operator && !alignment.active}
          <span class="cb">
            <Checkbox
              state={triState(entry.members, selection.ids)}
              label="Select {name}"
              disabled={!entry.members.some(isSelectable)}
              onclick={() => selection.set(toggledAll(entry.members, selection.ids))}
            />
          </span>
        {/if}
        <button
          class="gbtn"
          aria-expanded={open}
          onclick={() => tableLayout.toggleCollapsed(entry.key)}
        >
          <span class="gdot" class:none={entry.key === UNGROUPED}></span>
          <b>{name}</b>
          <span class="cnt">{entry.members.length}</span>
          {#if worst}
            <span class="pill {worst.tone}">{worst.text}</span>
          {/if}
          <span class="chev" class:closed={!open}><Icon name="chevron" size={16} /></span>
        </button>
      </div>
    {:else}
      {@const p = entry.projector}
      <ProjectorCard
        {p}
        {config}
        groups={groupMap}
        {patternLabel}
        {operator}
        selected={selection.ids.has(p.id)}
        expanded={openId === p.id}
        onselect={() => selection.toggle(p.id)}
        onexpand={() => toggleOpen(p.id)}
        role={alignment.role(p.id)}
        outside={alignment.active && !alignment.role(p.id)}
        onfocus={() => alignment.focus(p.id)}
      />
    {/if}
  {:else}
    <p class="empty">
      {live.projectors.length === 0 ? 'No projectors in this project' : 'No projectors match'}
    </p>
  {/each}
</div>

<style>
  /* As many columns as fit at 300 px; touch screens stop at three, so a
     sideways tablet reads like the owner's 3-column layout. Under 280 px
     the longest statuses (STANDBY · CLOSED, the pattern, a warning and the
     IP) no longer fit, so an upright iPad gets two columns, not three. */
  .list {
    --card-min: 300px;
    height: 100%;
    overflow: auto;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(min(100%, var(--card-min)), 1fr));
    align-content: start;
    gap: 8px;
    padding: 10px 12px 16px;
    overscroll-behavior: contain;
  }

  @media (pointer: coarse) {
    .list {
      --card-min: max(280px, (100% - 16px) / 3);
    }
  }

  .grp {
    grid-column: 1 / -1;
    display: flex;
    align-items: center;
    margin-top: 6px;
    border-radius: var(--r-sm);
    box-shadow: inset 3px 0 0 var(--gcolor);
  }

  .grp:first-child {
    margin-top: 0;
  }

  .cb {
    display: flex;
    padding-left: 14px;
  }

  .gbtn {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    gap: 8px;
    height: 40px;
    padding: 0 6px 0 12px;
    border: 0;
    background: none;
    text-align: left;
    cursor: pointer;
  }

  .gbtn b {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-weight: 650;
  }

  .gdot {
    width: 10px;
    height: 10px;
    flex: none;
    border-radius: 50%;
    background: var(--gcolor);
  }

  .gdot.none {
    background: none;
    border: 1.5px solid var(--line-strong);
  }

  .cnt {
    font-size: 12.5px;
    color: var(--faint);
  }

  .pill {
    padding: 1px 8px;
    border-radius: 999px;
    font-size: 11.5px;
    font-weight: 550;
    white-space: nowrap;
  }

  .pill.err {
    background: var(--err-soft);
    color: var(--err);
  }

  .pill.warn {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .chev {
    display: flex;
    margin-left: auto;
    padding: 0 8px;
    color: var(--muted);
  }

  .chev.closed :global(svg) {
    transform: rotate(-90deg);
  }

  .empty {
    grid-column: 1 / -1;
    margin: 0;
    padding: 48px 16px;
    text-align: center;
    color: var(--faint);
  }
</style>
