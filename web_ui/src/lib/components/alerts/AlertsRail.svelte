<!--
  The 52 px rail at the far right (desktop, tablet sideways): the bell, then
  one tick per alert in its severity colour, acknowledged ones faint, the
  last batch's pulsing. A click anywhere on it opens the drawer.
-->
<script lang="ts">
  import { isRecovered } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import AlertBell from './AlertBell.svelte';

  let { touch = false }: { touch?: boolean } = $props();

  const toggle = () => alerts.setPref('drawer', !alerts.prefs.drawer);
</script>

<div class="rail" class:touch>
  <AlertBell pressed={alerts.prefs.drawer} {touch} onclick={toggle} />
  <button class="ticks" tabindex="-1" aria-hidden="true" onclick={toggle}>
    {#each alerts.list as a (a.id)}
      <i
        class:ack={a.acknowledged}
        class:pulse={alerts.fresh.has(a.id)}
        class:crit={!isRecovered(a) && a.severity === 'critical'}
        class:warn={!isRecovered(a) && a.severity === 'warning'}
        class:ok={isRecovered(a)}
      ></i>
    {/each}
    <span class="vt">Alerts</span>
  </button>
</div>

<style>
  .rail {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    min-height: 0;
    padding: 10px 0;
    border-left: 1px solid var(--line);
    background: var(--surface);
  }

  .ticks {
    flex: 1;
    min-height: 0;
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 5px;
    padding: 2px 0 0;
    overflow: hidden;
    border: 0;
    background: none;
    cursor: pointer;
  }

  i {
    display: block;
    flex: none;
    width: 22px;
    height: 5px;
    border-radius: 3px;
  }

  .touch i {
    width: 26px;
    height: 6px;
  }

  i.crit {
    background: var(--sev-crit);
  }

  i.warn {
    background: var(--sev-warn);
  }

  i.ok {
    background: var(--sev-ok);
  }

  i.ack {
    opacity: 0.3;
  }

  i.pulse {
    animation: pulse 1s ease-out 3;
  }

  @keyframes pulse {
    50% {
      transform: scaleX(1.5);
    }
  }

  .vt {
    margin-top: 6px;
    writing-mode: vertical-rl;
    transform: rotate(180deg);
    font-size: 11px;
    font-weight: 650;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--faint);
  }
</style>
