<!-- Online, No login, Wrong login, Offline: the app's `ConnectionStatusBadge`. -->
<script lang="ts">
  import type { Projector } from '../../api/types';
  import { connectionLabel } from '../../logic/labels';
  import StatusPill from './StatusPill.svelte';

  let { connection }: { connection: Projector['connection'] } = $props();

  const label = $derived(connectionLabel(connection));
</script>

{#if connection === 'connected'}
  <StatusPill {label} tone="ok" dot />
{:else if connection === 'unprotected'}
  <StatusPill {label} tone="accent" icon="unlock" />
{:else if connection === 'unauthorized'}
  <StatusPill {label} tone="warn" icon="lock" />
{:else}
  <StatusPill {label} tone="err" dot />
{/if}
