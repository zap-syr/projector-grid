<!-- Result of the last operator command: the Event Log's summary line. -->
<script lang="ts">
  import { control } from '../../state/control.svelte';
  import Icon from '../Icon.svelte';
</script>

{#if control.toast}
  <div class="toast" class:bad={!control.toast.ok} role="status">
    <Icon name={control.toast.ok ? 'check' : 'error'} size={16} />
    <span>{control.toast.text}</span>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    left: 50%;
    bottom: 20px;
    z-index: 50;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 10px;
    max-width: calc(100% - 32px);
    padding: 10px 16px 10px 12px;
    border-radius: 12px;
    background: var(--text);
    color: var(--app);
    font-size: 13.5px;
    font-weight: 550;
    box-shadow: var(--sh-2);
  }

  .toast :global(svg) {
    color: var(--ok);
  }

  .toast.bad :global(svg) {
    color: var(--err);
  }
</style>
