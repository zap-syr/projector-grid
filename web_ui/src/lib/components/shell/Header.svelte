<script lang="ts">
  import { statusSummary } from '../../logic/status';
  import { alignment } from '../../state/alignment.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import { device } from '../../state/device.svelte';
  import { view } from '../../state/view.svelte';
  import { alerts } from '../../state/alerts.svelte';
  import AlertBell from '../alerts/AlertBell.svelte';
  import AlertIcon, { severityIcon } from '../alerts/AlertIcon.svelte';
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
  ] as const;

  // The app's status-bar Alerts button: per severity the unacknowledged count
  // with a filled icon, or once all are acknowledged the active total outlined.
  const ac = $derived(alerts.counts);
  const none = $derived(ac.criticalTotal + ac.warningTotal + ac.recovered === 0);
  /** Touch layouts open the alerts from the header; others have the rail. */
  const bell = $derived(device.control !== 'side');
  const iconSize = $derived(compact && !device.phone && !device.short ? 18 : 16);
</script>

{#snippet severityCount(severity: 'critical' | 'warning', open: number, total: number)}
  {#if total > 0}
    <span class="sc" class:fresh={open > 0}
      ><span class={severity === 'critical' ? 'crit' : 'warn'}
        ><AlertIcon name={severityIcon(severity, open > 0)} size={iconSize} /></span
      >{open > 0 ? open : total}</span
    >
  {/if}
{/snippet}

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
  <div class="filters" role="group" aria-label="Filter">
    {#each filters as f (f.id)}
      <button
        class="flt {f.tone}"
        aria-pressed={view.filter === f.id}
        onclick={() => view.toggleFilter(f.id)}>{f.label} <b>{counts[f.count]}</b></button
      >
    {/each}
    <button
      class="flt alerts"
      aria-pressed={view.filter === 'alerts'}
      aria-label="Alerts: {ac.critical} critical, {ac.warning} warning new"
      onclick={() => view.toggleFilter('alerts')}
    >
      <span class="al">Alerts</span>
      {#if none}
        <span class="sc"
          ><span class="ok"><AlertIcon name="checkCircleOutline" size={iconSize} /></span>0</span
        >
      {:else}
        {@render severityCount('critical', ac.critical, ac.criticalTotal)}
        {@render severityCount('warning', ac.warning, ac.warningTotal)}
        {#if ac.recovered > 0}
          <span class="sc fresh"
            ><span class="ok"><AlertIcon name="checkCircle" size={iconSize} /></span
            >{ac.recovered}</span
          >
        {/if}
      {/if}
    </button>
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

  /* Phone: project, live, bell, role and sign-out in one row; the filters below. */
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

  .phone .filters {
    order: 1;
    flex-basis: 100%;
    flex-wrap: nowrap;
    overflow-x: auto;
    margin: 0 -4px;
    scrollbar-width: none;
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

  .flt.alerts {
    gap: 9px;
  }

  .sc {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    color: var(--muted);
    font-weight: 450;
    font-variant-numeric: tabular-nums;
  }

  .sc.fresh {
    color: var(--text);
    font-weight: 650;
  }

  .crit,
  .warn,
  .ok {
    display: inline-flex;
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

  /* Touch: filters a finger-sized 40 px, as in the approved touch layout. */
  .touch .flt {
    height: 40px;
    padding: 0 12px;
    border-radius: 10px;
    font-size: 14px;
  }

  /* A phone, either way up, fits all four filters in one row: tighter, and
     the Alerts filter is its icons and counts (the bell beside it says "alerts"). */
  .hdr.phone,
  .hdr.short {
    gap: 6px;
  }

  .short .filters {
    flex-wrap: nowrap;
  }

  .phone .flt,
  .short .flt {
    gap: 5px;
    padding: 0 8px;
    font-size: 13.5px;
  }

  .phone .flt.alerts,
  .short .flt.alerts {
    gap: 7px;
  }

  .phone .al,
  .short .al {
    display: none;
  }

  /* Below 1280 px (where the toolbar drops its labels too) the header keeps
     one row: the Alerts filter is its icons and counts. */
  @media (max-width: 1279px) {
    .hdr:not(.compact) {
      column-gap: 10px;
    }

    .hdr:not(.compact) .al {
      display: none;
    }

    .hdr:not(.compact) .flt.alerts {
      gap: 7px;
    }

    /* A sideways tablet: still 40 px tall, a little narrower. */
    .touch:not(.compact) .flt {
      padding: 0 9px;
    }
  }

  /* An upright tablet: the phone's two rows, the filters on their own row
     at full size, so nothing wraps inside the header. */
  .hdr.compact:not(.phone):not(.short) {
    flex-wrap: wrap;
  }

  .compact:not(.phone):not(.short) .proj {
    flex: 1;
  }

  .compact:not(.phone):not(.short) .filters {
    order: 1;
    flex-basis: 100%;
    flex-wrap: nowrap;
  }

  .compact:not(.phone):not(.short) .grow {
    display: none;
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
