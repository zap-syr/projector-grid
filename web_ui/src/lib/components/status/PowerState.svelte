<!-- Power as icon + word in the canvas card's colours: green on, amber in transition, red standby. -->
<script lang="ts">
  import type { Projector } from '../../api/types';
  import { powerLabel } from '../../logic/labels';
  import Icon from '../Icon.svelte';

  let { power }: { power: Projector['power'] } = $props();

  const tone = $derived(power === 'on' ? 'ok' : power === 'standby' ? 'err' : 'warn');
</script>

<span class="st" style:--c="var(--{tone})"><Icon name="power" size={16} />{powerLabel(power)}</span>

<style>
  .st {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    color: var(--c);
    white-space: nowrap;
  }
</style>
