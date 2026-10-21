<!--
  The test pattern as its 20×12 thumbnail with a hairline frame, and its name
  where the app shows one (`TestPatternThumb`, `TestPatternName`). Off and
  not polled yet are the text alone.
-->
<script lang="ts">
  import { isPatternActive, patternSwatch } from '../../logic/patterns';

  let {
    code,
    label,
  }: {
    code: string | null;
    /** The pattern's name beside the thumbnail; none for the thumbnail alone. */
    label?: string;
  } = $props();
</script>

{#if isPatternActive(code)}
  <span class="tp">
    <i style:background={patternSwatch(code) ?? 'var(--soft)'} title={label ? undefined : code}></i>
    {#if label}<span class="l">{label}</span>{/if}
  </span>
{:else if label}
  <span class="l">{label}</span>
{/if}

<style>
  .tp {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
  }

  i {
    width: 20px;
    height: 12px;
    flex: none;
    border-radius: 2px;
    box-shadow: inset 0 0 0 0.5px var(--faint);
  }

  .l {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
