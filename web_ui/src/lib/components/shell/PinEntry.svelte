<!--
  PIN input for sign-in and Unlock control: the keypad on phones, one field
  on desktop. `submit` returns the error to show, or null on success.
-->
<script lang="ts">
  import { device } from '../../state/device.svelte';
  import PinPad from './PinPad.svelte';

  let {
    label,
    notice = null,
    autofocus = false,
    submit,
  }: {
    label: string;
    /** Shown until the first attempt (e.g. "Signed out by the app"). */
    notice?: string | null;
    autofocus?: boolean;
    submit: (pin: string) => Promise<string | null>;
  } = $props();

  let pin = $state('');
  let error = $state<string | null>(null);
  let busy = $state(false);
  let field = $state<HTMLInputElement>();

  // The field is the only thing to do on the login page / unlock dialog.
  $effect(() => {
    if (autofocus) field?.focus();
  });

  async function send() {
    if (pin.length < 4 || busy) return;
    busy = true;
    error = await submit(pin);
    busy = false;
    if (error) pin = '';
  }
</script>

<form
  class="entry"
  onsubmit={(e) => {
    e.preventDefault();
    void send();
  }}
>
  {#if device.pinPad}
    <PinPad bind:value={pin} disabled={busy} onsubmit={send} />
  {:else}
    <input
      type="password"
      inputmode="numeric"
      autocomplete="current-password"
      maxlength="8"
      aria-label="PIN"
      aria-invalid={error !== null}
      bind:this={field}
      bind:value={pin}
      oninput={() => (pin = pin.replace(/\D/g, ''))}
    />
    <button class="btn" type="submit" disabled={pin.length < 4 || busy}>{label}</button>
  {/if}
  <p class="msg" role="alert">{error ?? notice ?? ''}</p>
</form>

<style>
  .entry {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 14px;
  }

  input {
    height: 44px;
    padding: 0 12px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--app);
    font-family: var(--mono);
    font-size: 20px;
    letter-spacing: 0.3em;
    text-align: center;
  }

  input:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }

  input[aria-invalid='true'] {
    border-color: var(--err);
  }

  .btn {
    height: 44px;
    border-radius: var(--r-sm);
    border: 1px solid var(--accent);
    background: var(--accent);
    color: var(--on-accent);
    font-weight: 600;
    font-size: 14.5px;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--accent-hover);
  }

  .btn:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .msg {
    margin: 0;
    min-height: 1.45em;
    text-align: center;
    font-size: 13px;
    color: var(--err);
  }
</style>
