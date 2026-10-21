<script lang="ts">
  import { api, ApiError } from '../../api/client';
  import { control } from '../../state/control.svelte';
  import { alignment } from '../../state/alignment.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import { device } from '../../state/device.svelte';
  import { alerts } from '../../state/alerts.svelte';
  import AlertBell from '../alerts/AlertBell.svelte';
  import Icon from '../Icon.svelte';
  import AppLogo from './AppLogo.svelte';
  import UnlockDialog from './UnlockDialog.svelte';

  let { operator }: { operator: boolean } = $props();

  let unlocking = $state(false);
  /** A refresh request is out: the button spins and ignores more presses. */
  let refreshing = $state(false);
  /** Briefly green after a finished poll, in place of a toast. */
  let refreshed = $state(false);
  let refreshedTimer: ReturnType<typeof setTimeout> | undefined;

  async function refresh() {
    clearTimeout(refreshedTimer);
    refreshed = false;
    refreshing = true;
    try {
      await api.refresh();
      refreshed = true;
      refreshedTimer = setTimeout(() => (refreshed = false), 1500);
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      // 403/404: control was locked or switched off meanwhile.
      control.notify({ text: 'Not refreshed, control is locked', ok: false });
    } finally {
      refreshing = false;
    }
  }
  /** Phones and portrait tablets: short labels, icons for the rest. */
  const compact = $derived(device.cardsOnly);

  const liveText = $derived(
    live.connection === 'live'
      ? 'Live'
      : live.connection === 'reconnecting'
        ? 'Reconnecting'
        : 'Connecting',
  );
  /** Touch layouts open the alerts from the header; others have the rail. */
  const bell = $derived(device.control !== 'side');
</script>

<header
  class="hdr"
  class:phone={device.phone}
  class:short={device.short}
  class:compact
  class:op={operator}
  class:touch={device.touch}
>
  <AppLogo size={32} />
  <div class="proj">
    <b>{session.projectName}</b>
    <span>Projector Grid</span>
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
    <!-- The app's F5: polls every projector now, not just the selection. On
         an upright phone it moves to the end of the filter row. -->
    <button
      class="refresh"
      class:spin={refreshing}
      class:done={refreshed}
      disabled={refreshing}
      aria-label={refreshed ? 'Status refreshed' : 'Refresh status'}
      title={refreshing ? 'Polling projectors…' : 'Refresh status of all projectors'}
      onclick={refresh}
    >
      <Icon name={refreshed ? 'check' : 'refresh'} size={16} />
    </button>
  {/if}
  <span class="live" class:off={live.connection !== 'live'} title={liveText}>
    <span class="dot"></span>
    <span class="lt">{liveText}</span>
  </span>
  {#if bell}
    <AlertBell pressed={alerts.sheet} touch={device.touch} onclick={() => (alerts.sheet = true)} />
  {/if}
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

  /* Phone: project, live, refresh, bell, role and sign-out in one row. */
  .hdr.phone {
    flex-wrap: wrap;
    gap: 8px;
    min-height: 0;
    padding: 8px 12px;
  }

  .phone .proj {
    flex: 1;
    min-width: 0;
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

  .refresh {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 36px;
    height: 34px;
    border: 1px solid var(--line-strong);
    border-radius: 9px;
    background: var(--surface);
    cursor: pointer;
    transition:
      background-color 0.3s,
      border-color 0.3s,
      color 0.3s;
  }

  .refresh:hover:not(:disabled) {
    background: var(--hover);
  }

  .refresh:disabled {
    cursor: progress;
  }

  .refresh.done,
  .refresh.done:hover {
    background: var(--ok-soft);
    border-color: var(--ok);
    color: var(--ok);
  }

  .refresh.spin :global(svg) {
    animation: spin 0.9s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .refresh.spin :global(svg) {
      animation: none;
      opacity: 0.5;
    }
  }

  .phone .refresh {
    width: 40px;
    height: 40px;
    border-radius: 10px;
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

  /* Lock / Unlock already says which role this is; the name gets the room. */
  .phone .who:has(button),
  .short .who:has(button) {
    padding-left: 4px;
  }

  .phone .who:has(button) .role,
  .short .who:has(button) .role {
    display: none;
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
