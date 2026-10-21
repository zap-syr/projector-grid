<!--
  One cell of the app's two-line Monitoring columns (`monitoringCell`), from
  the shared status pieces, so the table, the details and the cards read the
  same. Phase 3 of the redesign restyles the row around them.
-->
<script lang="ts">
  import type { ColumnId, Group, Projector } from '../../api/types';
  import { cellText, modelLine } from '../../logic/cells';
  import { withUnit } from '../../logic/labels';
  import { alerts } from '../../state/alerts.svelte';
  import { config } from '../../state/config.svelte';
  import ErrorTags from '../alerts/ErrorTags.svelte';
  import ConnectionBadge from '../status/ConnectionBadge.svelte';
  import PowerState from '../status/PowerState.svelte';
  import ShutterState from '../status/ShutterState.svelte';
  import SignalPill from '../status/SignalPill.svelte';
  import TemperatureLine from '../status/TemperatureLine.svelte';
  import TestPatternThumb from '../status/TestPatternThumb.svelte';

  let {
    column,
    p,
    groups,
    patternLabel,
  }: {
    column: ColumnId;
    p: Projector;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
  } = $props();

  const text = $derived(cellText(column, p, groups, patternLabel));
  const group = $derived(p.groupId ? groups.get(p.groupId) : undefined);
  const thresholds = $derived(config.value?.thresholds);
</script>

<span class="cv" title={text}>
  {#if column === 'projector'}
    <span class="two">
      <span class="ipl"><i class="dot {p.connection}"></i><span class="ip">{p.ip}</span></span>
      <small class="ind">{modelLine(p, alerts.now)}</small>
    </span>
  {:else if column === 'group'}
    {#if group}
      <span class="gdot" style:background={group.color}></span>
      <span class="t">{group.name}</span>
    {:else}
      <span class="t quiet">None</span>
    {/if}
  {:else if column === 'power'}
    <PowerState power={p.power} />
  {:else if column === 'shutter'}
    <ShutterState {p} />
  {:else if column === 'inputSignal'}
    <span class="two">
      <span class="t">{p.input}</span>
      <SignalPill {p} />
    </span>
  {:else if column === 'temperature' && thresholds}
    <span class="two">
      <TemperatureLine
        label="In"
        display={p.intakeTemp}
        threshold={thresholds.intake}
        level={p.status.intake ?? null}
      />
      <TemperatureLine
        label="Ex"
        display={p.exhaustTemp}
        threshold={thresholds.exhaust}
        level={p.status.exhaust ?? null}
      />
    </span>
  {:else if column === 'runtimes'}
    <span class="two">
      <span class="t">{withUnit(p.runtime)}</span>
      <small>Light {withUnit(p.lightRuntime)}</small>
    </span>
  {:else if column === 'errors' && p.errorItems.length > 0 && p.connection !== 'offline'}
    <ErrorTags {p} />
  {:else if column === 'errors'}
    <!-- None, or Unknown while offline: its codes are the last it sent. -->
    <span class="t quiet">{text}</span>
  {:else if column === 'connection'}
    <ConnectionBadge connection={p.connection} />
  {:else if column === 'testPattern'}
    <TestPatternThumb code={p.testPattern} label={text} />
  {:else}
    <span class="t">{text}</span>
  {/if}
</span>

<style>
  .cv {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    max-width: 100%;
    overflow: hidden;
    vertical-align: middle;
  }

  .two {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
    min-width: 0;
    line-height: 1.3;
  }

  .ipl {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .ip {
    font-family: var(--mono);
    letter-spacing: 0;
    font-weight: 500;
  }

  small {
    color: var(--muted);
    font-size: 11.5px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
  }

  .ind {
    margin-left: 16px;
  }

  .t {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .quiet {
    color: var(--faint);
  }

  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex: none;
    background: var(--ok);
  }

  .dot.unauthorized {
    background: var(--warn);
  }

  .dot.offline {
    background: var(--faint);
  }

  .gdot {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    flex: none;
  }
</style>
