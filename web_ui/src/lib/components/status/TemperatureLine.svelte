<!-- One line of the table's Temperature cell: `In  25 °C  ▬▬▬` (`TemperatureLine`). -->
<script lang="ts">
  import type { AlertSeverity } from '../../api/types';
  import type { TempThreshold } from '../../logic/temperature';
  import TemperatureBar from './TemperatureBar.svelte';
  import TemperatureText from './TemperatureText.svelte';

  let {
    label,
    display,
    threshold,
    level,
    bar = true,
  }: {
    label: string;
    display: string;
    threshold: TempThreshold;
    /** The rule's active alert, which colours the value. */
    level: AlertSeverity | null;
    /** Only the desktop table draws bars; touch shows the coloured value alone. */
    bar?: boolean;
  } = $props();
</script>

<span class="tl">
  <span class="k">{label}</span>
  <span class="v"><TemperatureText {display} {level} /></span>
  {#if bar}<TemperatureBar {display} {threshold} width={40} />{/if}
</span>

<style>
  .tl {
    display: inline-flex;
    align-items: center;
    font-size: 12.5px;
    line-height: 1.5;
  }

  .k {
    width: 20px;
    flex: none;
    color: var(--faint);
    font-size: 11.5px;
    font-weight: 500;
  }

  .v {
    width: 48px;
    margin-right: 6px;
    flex: none;
    overflow: hidden;
  }
</style>
