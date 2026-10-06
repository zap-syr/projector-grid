<!-- Touch layouts: "4 new alerts, 1 signal back" above the cards; opens the alerts sheet. -->
<script lang="ts">
  import { alertPill } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import AlertIcon, { severityIcon } from './AlertIcon.svelte';

  const pill = $derived(alertPill(alerts.list));
</script>

{#if pill}
  <div class="wrap">
    <button class="pill {pill.tone}" onclick={() => (alerts.sheet = true)}>
      <AlertIcon
        name={pill.tone === 'recovered' ? 'checkCircle' : severityIcon(pill.tone)}
        size={24}
      />
      <span class="t"
        >{pill.text}{#if pill.extra}<small>, {pill.extra}</small>{/if}</span
      >
      <AlertIcon name="chevronRight" size={24} />
    </button>
  </div>
{/if}

<style>
  .wrap {
    padding: 10px 12px 0;
    background: var(--app);
  }

  .pill {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    min-height: 56px;
    padding: 0 16px;
    border: 0;
    border-radius: 14px;
    font-size: 15.5px;
    font-weight: 600;
    text-align: left;
    cursor: pointer;
  }

  .t {
    flex: 1;
    min-width: 0;
  }

  small {
    font-size: inherit;
    font-weight: 500;
    opacity: 0.85;
  }

  .critical {
    background: var(--err-soft);
    color: var(--err);
  }

  .warning {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .recovered {
    background: var(--ok-soft);
    color: var(--ok);
  }
</style>
