<script lang="ts">
  import { statusSummary } from '../../logic/status';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import Icon from '../Icon.svelte';
  import UnlockDialog from './UnlockDialog.svelte';

  let unlocking = $state(false);
  import { view } from '../../state/view.svelte';
  import AppLogo from './AppLogo.svelte';

  const counts = $derived(statusSummary(live.projectors));
  const filters = [
    { id: 'all', label: 'All', count: 'total', tone: '' },
    { id: 'online', label: 'Online', count: 'online', tone: 'ok' },
    { id: 'offline', label: 'Offline', count: 'offline', tone: 'err' },
    { id: 'warnings', label: 'Warnings', count: 'warnings', tone: 'warn' },
  ] as const;
</script>

<header class="hdr">
  <AppLogo size={32} />
  <div class="proj">
    <b>{session.projectName}</b>
    <span>Projector Grid</span>
  </div>
  <div class="filters" role="group" aria-label="Filter">
    {#each filters as f (f.id)}
      <button
        class="flt {f.tone}"
        aria-pressed={view.filter === f.id}
        onclick={() => view.toggleFilter(f.id)}>{f.label} <b>{counts[f.count]}</b></button
      >
    {/each}
  </div>
  <div class="grow"></div>
  <span class="live" class:off={live.connection !== 'live'}>
    <span class="dot"></span>
    {live.connection === 'live'
      ? 'Live'
      : live.connection === 'reconnecting'
        ? 'Reconnecting'
        : 'Connecting'}
  </span>
  <div class="who" class:op={session.role === 'operator'}>
    <span class="role">
      <Icon name={session.role === 'operator' ? 'unlock' : 'lock'} size={13} />
      {session.role === 'operator' ? 'Operator' : 'Viewer'}
    </span>
    {#if session.role === 'operator'}
      <button class="small" onclick={() => session.lock()}>Lock</button>
    {:else if session.controlAllowed}
      <button class="small" onclick={() => (unlocking = true)}>Unlock control</button>
    {/if}
  </div>
  <button class="quiet" onclick={() => session.logout()}>Sign out</button>
</header>

{#if unlocking}
  <UnlockDialog onclose={() => (unlocking = false)} />
{/if}

<style>
  .hdr {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px 14px;
    min-height: 60px;
    padding: 10px 16px;
    background: var(--surface);
    border-bottom: 1px solid var(--line);
  }

  .proj {
    display: flex;
    flex-direction: column;
    line-height: 1.2;
  }

  .proj b {
    font-size: 15px;
    font-weight: 650;
    letter-spacing: -0.01em;
  }

  .proj span {
    font-size: 12px;
    color: var(--faint);
  }

  .filters {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .flt {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    height: 32px;
    padding: 0 11px;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--muted);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  .flt:hover {
    background: var(--hover);
    color: var(--text);
  }

  .flt b {
    font-weight: 650;
    color: var(--text);
    font-variant-numeric: tabular-nums;
  }

  .flt.ok b {
    color: var(--ok);
  }

  .flt.err b {
    color: var(--err);
  }

  .flt.warn b {
    color: var(--warn);
  }

  .flt[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  .grow {
    flex: 1;
  }

  .live {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    height: 28px;
    padding: 0 10px;
    border-radius: 999px;
    background: var(--ok-soft);
    color: var(--ok);
    font-size: 12.5px;
    font-weight: 600;
  }

  .live.off {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: currentColor;
  }

  .who {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 34px;
    padding: 0 4px 0 10px;
    border-radius: 9px;
    border: 1px solid var(--line);
  }

  .who.op {
    border-color: var(--accent-line);
    background: var(--accent-soft);
  }

  .role {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-weight: 650;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--muted);
  }

  .who.op .role {
    color: var(--accent);
  }

  .small {
    height: 26px;
    padding: 0 10px;
    border-radius: 6px;
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-size: 12.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .small:hover {
    background: var(--hover);
  }

  .quiet {
    height: 32px;
    padding: 0 10px;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    font-weight: 550;
    cursor: pointer;
  }

  .quiet:hover {
    background: var(--hover);
    color: var(--text);
  }
</style>
