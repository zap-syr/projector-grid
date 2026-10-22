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
      <!-- The app's ConfirmDialog: round mark, the question as the title, no title bar. -->
      <div class="top">
        <span class="ic" class:danger={p.confirmation.danger}>
          <Icon name={p.confirmation.danger ? 'error' : 'check'} size={20} />
        </span>
        <div class="txt">
          <h4 id="confirm-title">{p.confirmation.question}</h4>
          <p>{p.confirmation.title}</p>
        </div>
      </div>
      {#if p.confirmation.hidden.length > 0}
        {@const n = p.confirmation.hidden.length}
        <div class="hidden">
          <span>{n === 1 ? '1 of them is' : `${n} of them are`} hidden by the filter</span>
          <span class="ips">{p.confirmation.hidden.join(', ')}</span>
        </div>
      {/if}
      <div class="row">
        <button class="btn text" onclick={() => control.cancel()}>Cancel</button>
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
    max-width: 440px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 22px 22px 16px;
    background: var(--bar);
    border: 1px solid var(--line-strong);
    border-radius: 20px;
    box-shadow: var(--sh-3);
  }

  .top {
    display: flex;
    align-items: flex-start;
    gap: 14px;
  }

  .ic {
    width: 40px;
    height: 40px;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    background: var(--pc);
    color: var(--on-pc);
  }

  .ic.danger {
    background: var(--err-soft);
    color: var(--err);
  }

  .txt {
    display: flex;
    flex-direction: column;
    gap: 3px;
    min-width: 0;
    padding-top: 2px;
  }

  h4 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    line-height: 1.3;
  }

  p {
    margin: 0;
    color: var(--muted);
    font-size: 12.5px;
  }

  .row {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 4px;
  }

  .btn {
    height: 40px;
    padding: 0 20px;
    border: 0;
    border-radius: 999px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }

  .btn.text {
    background: none;
    color: var(--accent);
  }

  .btn.text:hover {
    background: var(--accent-soft);
  }

  .btn.primary {
    background: var(--accent);
    color: var(--on-accent);
  }

  /* Destructive: filled in the error colour, as the app's confirm. */
  .btn.primary.danger {
    background: var(--err);
    color: var(--on-err);
  }

  .hidden {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px 12px;
    border: 1px solid var(--line);
    border-radius: 12px;
    background: var(--surface-2);
    color: var(--muted);
    font-size: 12.5px;
  }

  .ips {
    color: var(--text);
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 12px;
    word-break: break-word;
  }
</style>
