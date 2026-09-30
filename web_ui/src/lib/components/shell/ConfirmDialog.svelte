<script lang="ts">
  import { control } from '../../state/control.svelte';
  import Icon from '../Icon.svelte';

  const p = $derived(control.pending);
  let confirmButton = $state<HTMLButtonElement>();

  $effect(() => {
    confirmButton?.focus();
  });
</script>

<svelte:window
  onkeydown={(e) => {
    // Marked handled, so the sheet and the toolbar leave this Esc alone.
    if (e.key === 'Escape' && p) {
      e.preventDefault();
      control.cancel();
    }
  }}
/>

{#if p}
  <div class="overlay">
    <div class="dialog" role="alertdialog" aria-modal="true" aria-labelledby="confirm-title">
      <span class="ic" class:danger={p.confirmation.danger}>
        <Icon name={p.confirmation.danger ? 'error' : 'check'} size={20} />
      </span>
      <h4 id="confirm-title">{p.confirmation.title}</h4>
      <p>{p.confirmation.question}</p>
      <div class="row">
        <button class="btn" onclick={() => control.cancel()}>Cancel</button>
        <button
          class="btn primary"
          class:danger={p.confirmation.danger}
          bind:this={confirmButton}
          onclick={() => control.confirm()}>{p.confirmation.confirmLabel}</button
        >
      </div>
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 45;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
    background: var(--scrim);
  }

  .dialog {
    width: 100%;
    max-width: 400px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 22px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 16px;
    box-shadow: var(--sh-3);
  }

  .ic {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 11px;
    background: var(--accent-soft);
    color: var(--accent);
  }

  .ic.danger {
    background: var(--err-soft);
    color: var(--err);
  }

  h4 {
    margin: 0;
    font-size: 17px;
    font-weight: 650;
  }

  p {
    margin: 0;
    color: var(--muted);
    font-size: 13.5px;
  }

  .row {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 4px;
  }

  .btn {
    height: 36px;
    padding: 0 14px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-weight: 550;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--hover);
  }

  .btn.primary {
    background: var(--accent);
    border-color: var(--accent);
    color: var(--on-accent);
  }

  .btn.primary.danger {
    background: var(--err);
    border-color: var(--err);
    color: #fff;
  }
</style>
