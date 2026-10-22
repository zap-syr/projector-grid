<!--
  A group's header line, the same in the table and the cards: the group's box
  (in the checkbox column), the chevron, the colour square, the name and the
  app's summary ("6 projectors, 5 online, 1 error"). The caller's whole row
  folds the group too; the chevron is the keyboard path.
-->
<script lang="ts">
  import type { Group, Projector } from '../../api/types';
  import { groupSummary } from '../../logic/rows';
  import { isSelectable, toggledAll, triState } from '../../logic/selection';
  import { selection } from '../../state/selection.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';

  let {
    group,
    members,
    open,
    select,
    ontoggle,
  }: {
    /** Null for the trailing "Ungrouped" section. */
    group: Group | null;
    members: readonly Projector[];
    open: boolean;
    /** The operator's group box (not in Alignment mode). */
    select: boolean;
    ontoggle: () => void;
  } = $props();

  const name = $derived(group?.name ?? 'Ungrouped');
</script>

<span class="gh" style:--gcolor={group?.color}>
  {#if select}
    <!-- In the rows' checkbox column, right above their boxes. -->
    <span class="gcb"
      ><Checkbox
        state={triState(members, selection.ids)}
        label="Select {name}"
        disabled={!members.some(isSelectable)}
        onclick={() => selection.set(toggledAll(members, selection.ids))}
      /></span
    >
  {/if}
  <button
    class="chev"
    class:closed={!open}
    aria-expanded={open}
    aria-label="{open ? 'Collapse' : 'Expand'} {name}"
    onclick={ontoggle}
  >
    <Icon name="chevron" size={15} />
  </button>
  <span class="gdot" class:none={!group}></span>
  <b>{name}</b>
  <span class="cnt">{groupSummary(members)}</span>
</span>

<style>
  .gh {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
    max-width: 100%;
  }

  .gcb {
    width: var(--selw);
    display: flex;
    flex: none;
    justify-content: center;
    margin-right: -8px;
  }

  b {
    flex: none;
    font-weight: 650;
  }

  .chev {
    width: 24px;
    height: 24px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 6px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  @media (hover: hover) {
    .chev:hover {
      background: var(--hover);
    }
  }

  .chev.closed :global(svg) {
    transform: rotate(-90deg);
  }

  .gdot {
    width: 10px;
    height: 10px;
    flex: none;
    border-radius: 3px;
    background: var(--gcolor);
  }

  .gdot.none {
    background: none;
    border: 1.5px solid var(--line-strong);
  }

  .cnt {
    min-width: 0;
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
