<!--
  A new alert (or a batch of them, raised within 2 s): "Signal lost on PJ-08:
  No signal on SDI 2" with Show, which opens the panel wherever this screen
  keeps it. Sits above the command toast's spot.
-->
<script lang="ts">
  import { alerts } from '../../state/alerts.svelte';
  import { device } from '../../state/device.svelte';
  import AlertIcon, { severityIcon } from './AlertIcon.svelte';

  function show() {
    if (device.control === 'side') alerts.setPref('drawer', true);
    else alerts.sheet = true;
    alerts.dismissToast();
  }
</script>

{#if alerts.toast}
  {@const a = alerts.toast.alert}
  <div class="toast" class:touch={device.touch} role="status">
    <span class={a.severity === 'critical' ? 'crit' : 'warn'}
      ><AlertIcon name={severityIcon(a.severity)} size={device.touch ? 22 : 18} /></span
    >
    <span class="t"
      >{a.label} on {a.projector}: {a.value}{#if alerts.toast.more > 0}, and {alerts.toast.more} more{/if}</span
    >
    <button onclick={show}>Show</button>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    left: 50%;
    bottom: 72px;
    z-index: 50;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 10px;
    width: max-content;
    max-width: calc(100% - 32px);
    padding: 8px 8px 8px 12px;
    border-radius: 12px;
    background: var(--text);
    color: var(--app);
    font-size: 13.5px;
    font-weight: 550;
    box-shadow: var(--sh-2);
    animation: rise 0.2s ease-out;
  }

  .t {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .crit {
    display: flex;
    color: var(--sev-crit);
  }

  .warn {
    display: flex;
    color: var(--sev-warn);
  }

  button {
    flex: none;
    height: 28px;
    padding: 0 10px;
    border: 0;
    border-radius: 7px;
    background: color-mix(in srgb, var(--app) 16%, transparent);
    color: inherit;
    font-size: 12.5px;
    font-weight: 600;
    cursor: pointer;
  }

  .touch {
    padding: 8px 8px 8px 14px;
    border-radius: 14px;
    font-size: 14.5px;
  }

  .touch button {
    height: 40px;
    padding: 0 16px;
    border-radius: 10px;
    font-size: 14px;
  }

  @keyframes rise {
    from {
      transform: translate(-50%, 8px);
      opacity: 0;
    }
  }
</style>
