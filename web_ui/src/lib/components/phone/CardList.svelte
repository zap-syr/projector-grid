<!--
  Projector cards sorted by IP: one collapsible section per group
  (ungrouped last), or a plain grid when the project has no groups.
-->
<script lang="ts">
  import type { Config } from '../../api/types';
  import { testPatternLabel } from '../../logic/cells';
  import {
    buildEntries,
    type Entry,
    matchesFilter,
    matchesSearch,
    UNGROUPED,
  } from '../../logic/rows';
  import { sortByIp } from '../../logic/sort';
  import { alignment } from '../../state/alignment.svelte';
  import { cardSize } from '../../state/cardSize.svelte';
  import { details } from '../../state/details.svelte';
  import { live } from '../../state/live.svelte';
  import { selection } from '../../state/selection.svelte';
  import { tableLayout, type StoredLayout } from '../../state/tableLayout.svelte';
  import { view } from '../../state/view.svelte';
  import GroupHeader from '../table/GroupHeader.svelte';
  import ProjectorCard from './ProjectorCard.svelte';

  let { config, layout, operator }: { config: Config; layout: StoredLayout; operator: boolean } =
    $props();

  const patterns = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const patternLabel = (code: string) => testPatternLabel(code, patterns);

  const shown = $derived(
    sortByIp(
      live.projectors.filter((p) => matchesFilter(p, view.filter) && matchesSearch(p, view.search)),
    ),
  );
  const entries = $derived(
    buildEntries(
      shown,
      live.groups,
      layout.groupBy && live.groups.length > 0,
      new Set(layout.collapsed),
    ),
  );
  /** Preview's ◀ ▶ from the details: the cards as shown (filtered, collapsed groups left out). */
  const order = $derived(entries.flatMap((e) => (e.kind === 'row' ? [e.projector.id] : [])));
  const entryKey = (e: Entry) => (e.kind === 'group' ? `g:${e.key}` : e.projector.id);
</script>

<div class="list" class:compact={cardSize.value === 'compact'}>
  {#each entries as entry (entryKey(entry))}
    {#if entry.kind === 'group'}
      <!-- The table's group line; the whole line folds it, the chevron is the keyboard path. -->
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
      <div
        class="grp"
        class:plain={!operator || alignment.active}
        onclick={(e) => {
          if (!(e.target as Element).closest('button')) tableLayout.toggleCollapsed(entry.key);
        }}
      >
        <GroupHeader
          group={entry.key === UNGROUPED ? null : (entry.group ?? null)}
          members={entry.members}
          open={!layout.collapsed.includes(entry.key)}
          select={operator && !alignment.active}
          ontoggle={() => tableLayout.toggleCollapsed(entry.key)}
        />
      </div>
    {:else}
      {@const p = entry.projector}
      <ProjectorCard
        {p}
        size={cardSize.value}
        thresholds={config.thresholds}
        {patternLabel}
        {operator}
        selected={selection.ids.has(p.id)}
        open={details.id === p.id}
        onselect={() => selection.toggle(p.id)}
        ondetails={() => details.toggle(p.id, order)}
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
  /* Cards fill the width from 300 px; the details open over them rather than
     beside them, so the grid never reflows (App). Touch screens stop at three
     columns, never under 280 px, so an upright iPad gets two. */
  .list {
    height: 100%;
    overflow: auto;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr));
    align-content: start;
    gap: 12px;
    padding: 12px 16px 16px;
    overscroll-behavior: contain;
  }

  /* Phones: the boards' tighter list, Compact closest. */
  @media (max-width: 600px) {
    .list {
      gap: 10px;
      padding: 4px 12px 16px;
    }

    .list.compact {
      gap: 8px;
    }
  }

  @media (pointer: coarse) {
    .list {
      grid-template-columns: repeat(
        auto-fill,
        minmax(min(100%, max(280px, (100% - 16px) / 3)), 1fr)
      );
    }
  }

  /* The table's group line: its band, its height, the box above the cards' boxes. */
  .grp {
    --selw: 48px;
    grid-column: 1 / -1;
    display: flex;
    align-items: center;
    height: 40px;
    margin-top: 6px;
    padding-right: 12px;
    border-radius: var(--r-sm);
    background: color-mix(in srgb, var(--text) 4%, var(--app));
    cursor: pointer;
  }

  .grp:first-child {
    margin-top: 0;
  }

  .grp.plain {
    padding-left: 6px;
  }

  @media (pointer: coarse) {
    .grp {
      height: 48px;
    }
  }

  .empty {
    grid-column: 1 / -1;
    margin: 0;
    padding: 48px 16px;
    text-align: center;
    color: var(--faint);
  }
</style>
