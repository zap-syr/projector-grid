<script lang="ts">
  import { statusSummary } from '../../logic/status';
  import { alignment } from '../../state/alignment.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import { device } from '../../state/device.svelte';
  import { view } from '../../state/view.svelte';
  import Icon from '../Icon.svelte';
  import AppLogo from './AppLogo.svelte';
  import UnlockDialog from './UnlockDialog.svelte';

  let { operator }: { operator: boolean } = $props();

  let unlocking = $state(false);
  /** Phones and portrait tablets: short labels, icons for the rest. */
  const compact = $derived(device.cardsOnly);

  const counts = $derived(statusSummary(live.projectors));
  const liveText = $derived(
    live.connection === 'live'
      ? 'Live'
      : live.connection === 'reconnecting'
        ? 'Reconnecting'
        : 'Connecting',
  );
  const filters = [
    { id: 'all', label: 'All', count: 'total', tone: '' },
    { id: 'online', label: 'Online', count: 'online', tone: 'ok' },
    { id: 'offline', label: 'Offline', count: 'offline', tone: 'err' },
    { id: 'warnings', label: 'Warnings', count: 'warnings', tone: 'warn' },
  ] as const;
</script>

<header class="hdr" class:phone={device.phone} class:compact class:op={operator}>
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
  {#if operator}
    <!-- The app's Alignment mode toggle: the same session the app's banner drives. -->
    <button
      class="align"
      aria-pressed={alignment.active}
      disabled={alignment.busy}
      title={alignment.active ? 'Exit Alignment mode' : 'Alignment mode'}
      onclick={() => (alignment.active ? alignment.exit() : alignment.enter())}
    >
      <Icon name="target" size={16} /><span class="at">Alignment</span>
    </button>
  {/if}
  <span class="live" class:off={live.connection !== 'live'} title={liveText}>
    <span class="dot"></span>
    <span class="lt">{liveText}</span>
  </span>
  <div class="who" class:op={session.role === 'operator'}>
    <span class="role" title={session.role === 'operator' ? 'Operator' : 'Viewer'}>
      <Icon name={session.role === 'operator' ? 'unlock' : 'lock'} size={13} />
      <span class="rt">{session.role === 'operator' ? 'Operator' : 'Viewer'}</span>
    </span>
    {#if session.role === 'operator'}
      <button class="small" onclick={() => session.lock()}>Lock</button>
    {:else if session.controlAllowed}
      <button class="small" onclick={() => (unlocking = true)}
        >{compact ? 'Unlock' : 'Unlock control'}</button
      >
    {/if}
  </div>
  <button class="quiet" aria-label="Sign out" title="Sign out" onclick={() => session.logout()}>
    {#if compact}<Icon name="logout" size={18} />{:else}Sign out{/if}
  </button>
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

  /* Phone: project, live, role and sign-out in one row; the filters below. */
  .hdr.phone {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr) auto auto auto;
    gap: 8px;
    min-height: 0;
    padding: 8px 12px;
  }

  /* The operator's Alignment button takes one more column. */
  .hdr.phone.op {
    grid-template-columns: auto minmax(0, 1fr) auto auto auto auto;
  }

  .phone .filters {
    order: 1;
    grid-column: 1 / -1;
    flex-wrap: nowrap;
    overflow-x: auto;
    margin: 0 -4px;
  }

  /* Phone held sideways: everything in one short row. */
  .hdr.compact:not(.phone) {
    flex-wrap: nowrap;
    min-height: 0;
    padding: 6px 12px;
  }

  .compact:not(.phone) .proj {
    min-width: 0;
  }

  .compact .flt {
    flex: none;
  }

  .phone .grow,
  .compact .proj span,
  .compact .lt,
  .compact .rt,
  .compact .at {
    display: none;
  }

  .align {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    height: 34px;
    padding: 0 12px;
    border: 1px solid var(--line-strong);
    border-radius: 9px;
    background: var(--surface);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  .align:hover:not(:disabled) {
    border-color: var(--align);
  }

  .align[aria-pressed='true'] {
    border-color: var(--align);
    background: var(--align);
    color: var(--on-align);
  }

  .align:disabled {
    opacity: 0.6;
    cursor: progress;
  }

  .compact .align {
    width: 36px;
    padding: 0;
    justify-content: center;
  }

  .compact .proj b {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .compact .live {
    padding: 0 9px;
  }

  .compact .who {
    padding-left: 8px;
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
    display: inline-flex;
    align-items: center;
    justify-content: center;
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
