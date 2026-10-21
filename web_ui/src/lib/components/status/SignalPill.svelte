<!-- The signal pill: green with the resolution, red No signal only while on, grey otherwise. -->
<script lang="ts">
  import type { Projector } from '../../api/types';
  import { signalState } from '../../logic/signal';
  import StatusPill from './StatusPill.svelte';

  let { p }: { p: Projector } = $props();

  const s = $derived(signalState(p));
</script>

<StatusPill
  label={s.label}
  tone={s.tone === 'good' ? 'ok' : s.tone === 'missing' ? 'err' : 'faint'}
  dot
/>
