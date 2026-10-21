<!--
  The worst problem as a pill (`Error F305`, amber `Warning H001`, `Offline`),
  then `+2` when there are more; *None* without any (`ProblemBadge`). The
  caller passes the problems it shows: the table's Errors column only the
  projector's own codes.
-->
<script lang="ts" module>
  export interface BadgeProblem {
    level: 'warning' | 'error' | 'offline';
    badge: string;
  }
</script>

<script lang="ts">
  import StatusPill from './StatusPill.svelte';

  let { problems, empty = 'None' }: { problems: readonly BadgeProblem[]; empty?: string } =
    $props();

  const first = $derived(problems[0]);
  const more = $derived(problems.length - 1);
</script>

{#if !first}
  <span class="none">{empty}</span>
{:else}
  <span class="pb" title={more > 0 ? problems.map((x) => x.badge).join(', ') : undefined}>
    {#if first.level === 'error'}
      <StatusPill label={first.badge} tone="err" icon="error" />
    {:else if first.level === 'warning'}
      <StatusPill label={first.badge} tone="warn" icon="warn" />
    {:else}
      <StatusPill label={first.badge} tone="faint" dot />
    {/if}
    {#if more > 0}<span class="more">+{more}</span>{/if}
  </span>
{/if}

<style>
  .none {
    color: var(--faint);
  }

  .pb {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    max-width: 100%;
  }

  .more {
    flex: none;
    color: var(--faint);
    font-size: 11.5px;
    font-weight: 600;
  }
</style>
