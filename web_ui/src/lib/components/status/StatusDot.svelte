<!-- The connection dot before a projector's IP: green online, amber for a failed login, grey offline (`MonitoringStatusDot`). -->
<script lang="ts">
  import type { Projector } from '../../api/types';

  let { connection }: { connection: Projector['connection'] } = $props();
</script>

<i class="dot {connection}"></i>

<style>
  .dot {
    width: 8px;
    height: 8px;
    flex: none;
    border-radius: 50%;
    background: var(--ok);
  }

  .dot.unauthorized {
    background: var(--warn);
  }

  .dot.offline {
    background: var(--faint);
  }
</style>
