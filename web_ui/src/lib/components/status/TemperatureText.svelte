<!-- A temperature value alone, amber or red while its rule's alert is active, as the app's. -->
<script lang="ts">
  import type { AlertSeverity } from '../../api/types';
  import { withUnit } from '../../logic/labels';

  let { display, level }: { display: string; level: AlertSeverity | null } = $props();
</script>

<span class="tt" class:warm={level === 'warning'} class:hot={level === 'critical'}
  >{withUnit(display)}</span
>

<style>
  .tt {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }

  .warm {
    color: var(--warn);
    font-weight: 600;
  }

  .hot {
    color: var(--err);
    font-weight: 600;
  }
</style>
