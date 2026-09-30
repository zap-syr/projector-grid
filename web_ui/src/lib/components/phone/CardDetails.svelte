<!--
  The open card's details: a full-width strip under its row, pointing up at
  the card, with every field the card's summary leaves out.
-->
<script lang="ts">
  import { cubicOut } from 'svelte/easing';
  import { slide } from 'svelte/transition';

  import type { ColumnId, Config, Group, Projector } from '../../api/types';
  import { device } from '../../state/device.svelte';
  import DetailFields from '../DetailFields.svelte';
  import Icon from '../Icon.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    column,
    columns,
    onclose,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    /** The open card's grid column, for the pointer. */
    column: number;
    columns: number;
    onclose: () => void;
  } = $props();

  /** Shown on the card itself (ProjectorCard's summary). */
  const SUMMARY: readonly ColumnId[] = ['model', 'power', 'shutter', 'signal', 'intake', 'exhaust'];

  /** The pointer sits under the middle of the card (grid gap 8 px). */
  const notch = $derived(
    `calc((100% - ${columns - 1} * 8px) / ${columns} * ${column + 0.5} + ${column} * 8px)`,
  );
</script>

<section
  class="details"
  aria-label="Details of {p.name}"
  style:--notch={notch}
  transition:slide={{ duration: device.reduceMotion ? 0 : 240, easing: cubicOut }}
>
  <div class="box">
    <header>
      <b>{p.name}</b>
      <span class="ip">{p.ip}</span>
      <button class="x" aria-label="Close details" onclick={onclose}>
        <Icon name="close" size={16} />
      </button>
    </header>
    <DetailFields {p} {config} {groups} {patternLabel} skip={SUMMARY} />
  </div>
</section>

<style>
  .details {
    grid-column: 1 / -1;
    /* Room for the pointer above the box. */
    padding-top: 9px;
  }

  .box {
    position: relative;
    background: var(--surface-2);
    border: 1px solid var(--accent-line);
    border-radius: var(--r);
    box-shadow: var(--sh-1);
  }

  /* The pointer: a rotated square sharing the box's border. */
  .box::before {
    content: '';
    position: absolute;
    top: -7px;
    left: var(--notch);
    width: 12px;
    height: 12px;
    background: var(--surface-2);
    border-top: 1px solid var(--accent-line);
    border-left: 1px solid var(--accent-line);
    transform: translateX(-50%) rotate(45deg);
    transition: left 0.24s cubic-bezier(0.2, 0.8, 0.2, 1);
  }

  header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 8px 0 16px;
  }

  header b {
    font-size: 14.5px;
    font-weight: 650;
  }

  .ip {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--faint);
  }

  .x {
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-left: auto;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .x:hover {
    background: var(--hover);
    color: var(--text);
  }
</style>
