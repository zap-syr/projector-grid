<!--
  A card's alert badge, the app card's (`AlertBadge`): the colour of the most
  urgent unacknowledged alert, filled while anything is new, outlined once
  all are acknowledged, a number from two up, a green check while only a
  returned signal waits. Nothing without alerts.
-->
<script lang="ts">
  import { alertBadge } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import AlertIcon, { severityIcon } from './AlertIcon.svelte';

  let { id, size = 16 }: { id: string; size?: number } = $props();

  const badge = $derived(alertBadge(alerts.of(id)));
</script>

{#if badge}
  {@const tone = badge.recovered ? 'ok' : badge.severity === 'critical' ? 'crit' : 'warn'}
  <span
    class="badge {tone}"
    role="img"
    aria-label="{badge.count} {badge.count === 1 ? 'alert' : 'alerts'}"
    title="{badge.count} {badge.count === 1 ? 'alert' : 'alerts'}"
  >
    <AlertIcon
      name={badge.recovered ? 'checkCircle' : severityIcon(badge.severity, !badge.acknowledged)}
      {size}
    />{#if badge.count > 1}<b>{badge.count}</b>{/if}
  </span>
{/if}

<style>
  .badge {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    flex: none;
  }

  .crit {
    color: var(--sev-crit);
  }

  .warn {
    color: var(--sev-warn);
  }

  .ok {
    color: var(--sev-ok);
  }

  b {
    font-size: 0.75em;
    font-weight: 700;
    color: var(--text);
    font-variant-numeric: tabular-nums;
  }
</style>
