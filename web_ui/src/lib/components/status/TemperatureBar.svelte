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
    height = 4,
    mark = false,
  }: {
    display: string;
    threshold: TempThreshold;
    width?: number;
    /** The track's thickness: 4 in a table cell, 6 in the details' gauges. */
    height?: number;
    mark?: boolean;
  } = $props();

  const fraction = $derived(temperatureFraction(display, threshold));
  const level = $derived(temperatureBarLevel(display, threshold));
</script>

<span
  class="bar"
  class:marked={mark}
  style:width={width === undefined ? '100%' : `${width}px`}
  style:--h="{height}px"
>
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
    height: var(--h);
  }

  /* The mark stands 3 px out of the track on each side. */
  .bar.marked {
    height: calc(var(--h) + 6px);
  }

  .track,
  .fill {
    position: absolute;
    left: 0;
    height: var(--h);
    border-radius: calc(var(--h) / 2);
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
    height: 100%;
    border-radius: 1px;
    background: var(--warn);
  }
</style>
