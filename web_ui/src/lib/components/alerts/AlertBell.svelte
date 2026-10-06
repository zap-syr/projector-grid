<!--
  The bell: coloured by the most urgent unacknowledged alert, with their
  count (a returned signal alone shows green). The rail's top button on
  desktop, the header's on touch layouts.
-->
<script lang="ts">
  import { alerts } from '../../state/alerts.svelte';
  import AlertIcon from './AlertIcon.svelte';

  let {
    pressed,
    touch = false,
    onclick,
  }: { pressed: boolean; touch?: boolean; onclick: () => void } = $props();

  const c = $derived(alerts.counts);
  const tone = $derived(
    c.critical > 0 ? 'crit' : c.warning > 0 ? 'warn' : c.recovered > 0 ? 'ok' : '',
  );
  const count = $derived(c.critical + c.warning > 0 ? c.critical + c.warning : c.recovered);
  const label = $derived(
    count > 0 ? `Alerts, ${count} ${c.critical + c.warning > 0 ? 'new' : 'signal back'}` : 'Alerts',
  );
</script>

<button
  class="bell {tone}"
  class:touch
  aria-pressed={pressed}
  aria-label={label}
  title={touch ? undefined : 'Alerts'}
  {onclick}
>
  <AlertIcon name="bell" size={touch ? 24 : 20} />
  {#if count > 0}<span class="bdg">{count}</span>{/if}
</button>

<style>
  .bell {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    flex: none;
    padding: 0;
    border: 0;
    border-radius: 9px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .bell:hover,
  .bell[aria-pressed='true'] {
    background: var(--accent-soft);
  }

  .bell.crit {
    color: var(--sev-crit);
  }

  .bell.warn {
    color: var(--sev-warn);
  }

  .bell.ok {
    color: var(--sev-ok);
  }

  .bdg {
    position: absolute;
    top: 1px;
    right: 0;
    min-width: 17px;
    height: 17px;
    padding: 0 4px;
    border: 2px solid var(--surface);
    border-radius: 9px;
    background: var(--muted);
    color: #fff;
    font-size: 10.5px;
    font-weight: 700;
    line-height: 13px;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }

  .crit .bdg {
    background: var(--sev-crit);
  }

  .warn .bdg {
    background: var(--sev-warn);
  }

  .ok .bdg {
    background: var(--sev-ok);
  }

  .touch {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }

  .touch .bdg {
    min-width: 20px;
    height: 20px;
    border-radius: 10px;
    font-size: 11.5px;
    line-height: 16px;
  }
</style>
