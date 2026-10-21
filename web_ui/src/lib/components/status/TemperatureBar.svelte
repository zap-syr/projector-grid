<!--
  A thin bar for a temperature reading: green below the warning threshold,
  amber from it, red from the critical one, by the reading alone
  (`TemperatureBar`); `mark` draws the warning threshold across it.
-->
<script lang="ts">
  import {
    temperatureBarLevel,
    temperatureFraction,
    thresholdFraction,
    type TempThreshold,
  } from '../../logic/temperature';

  let {
    display,
    threshold,
    width,
    mark = false,
  }: { display: string; threshold: TempThreshold; width?: number; mark?: boolean } = $props();

  const fraction = $derived(temperatureFraction(display, threshold));
  const level = $derived(temperatureBarLevel(display, threshold));
</script>

<span class="bar" class:marked={mark} style:width={width === undefined ? '100%' : `${width}px`}>
  <span class="track"></span>
  {#if fraction !== null}
    <span
      class="fill"
      style:width="{fraction * 100}%"
      style:background={level === 'critical'
        ? 'var(--err)'
        : level === 'warning'
          ? 'var(--warn)'
          : 'var(--ok)'}
    ></span>
  {/if}
  {#if mark}
    <span class="mark" style:left="calc({thresholdFraction(threshold) * 100}% - 1px)"></span>
  {/if}
</span>

<style>
  .bar {
    position: relative;
    display: inline-block;
    flex: none;
    height: 4px;
  }

  .bar.marked {
    height: 10px;
  }

  .track,
  .fill {
    position: absolute;
    left: 0;
    height: 4px;
    border-radius: 2px;
  }

  .track {
    right: 0;
    background: var(--soft);
  }

  .marked .track,
  .marked .fill {
    top: 3px;
  }

  .mark {
    position: absolute;
    top: 0;
    width: 2px;
    height: 10px;
    border-radius: 1px;
    background: var(--warn);
  }
</style>
