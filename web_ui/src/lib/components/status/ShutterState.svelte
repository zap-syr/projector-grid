<!--
  Shutter as icon + word: green open, red closed with its own crossed eye,
  grey in standby, where it shows nothing either way (`ShutterState`).
-->
<script lang="ts">
  import type { Projector } from '../../api/types';
  import { shutterLabel } from '../../logic/labels';
  import Icon from '../Icon.svelte';

  let { p }: { p: Projector } = $props();

  const open = $derived(p.shutter === 'open');
  const tone = $derived(p.power === 'standby' ? 'faint' : open ? 'ok' : 'err');
</script>

<span class="st" style:--c="var(--{tone})"
  ><Icon name={open ? 'eye' : 'eyeOff'} size={16} />{shutterLabel(p.shutter)}</span
>

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
