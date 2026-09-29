<script lang="ts">
  import { statusSummary } from '../../logic/status';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import AppLogo from './AppLogo.svelte';

  const counts = $derived(statusSummary(live.projectors));
</script>

<header class="hdr">
  <AppLogo size={32} />
  <div class="proj">
    <b>{session.projectName}</b>
    <span>Projector Grid</span>
  </div>
  <div class="stats" aria-label="Status">
    <span class="stat">All <b>{counts.total}</b></span>
    <span class="stat ok">Online <b>{counts.online}</b></span>
    <span class="stat err">Offline <b>{counts.offline}</b></span>
    <span class="stat warn">Warnings <b>{counts.warnings}</b></span>
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
  <span class="role">{session.role}</span>
  <button class="quiet" onclick={() => session.logout()}>Sign out</button>
</header>

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

  .stats {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 14px;
    font-size: 13px;
    color: var(--muted);
  }

  .stat b {
    font-weight: 650;
    color: var(--text);
    font-variant-numeric: tabular-nums;
  }

  .stat.ok b {
    color: var(--ok);
  }

  .stat.err b {
    color: var(--err);
  }

  .stat.warn b {
    color: var(--warn);
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

  .role {
    font-size: 12px;
    font-weight: 650;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--muted);
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
