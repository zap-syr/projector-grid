<!--
  PIN input for sign-in and Unlock control (shell canvas, *Sign in…*): the
  keypad on phones and touch screens, a labelled field elsewhere. Under it
  one line that holds the help, and the error in its place, so nothing moves.
  Sign-in has one full-width button; the dialog a Cancel / Unlock footer.
  `submit` returns the error to show, or null on success.
-->
<script lang="ts">
  import { device } from '../../state/device.svelte';
  import PinPad from './PinPad.svelte';

  let {
    label,
    fieldLabel,
    help,
    notice = null,
    autofocus = false,
    oncancel,
    submit,
  }: {
    /** The send button's word (*Sign in*, *Unlock*). */
    label: string;
    /** The field's label (*PIN*, *Operator PIN*). */
    fieldLabel: string;
    /** The line under the field until an error takes its place. */
    help: string;
    /** Shown until the first attempt (e.g. "Signed out by the app"). */
    notice?: string | null;
    autofocus?: boolean;
    /** The dialog's Cancel; sign-in has none. */
    oncancel?: () => void;
    submit: (pin: string) => Promise<string | null>;
  } = $props();

  let pin = $state('');
  let error = $state<string | null>(null);
  let busy = $state(false);
  let field = $state<HTMLInputElement>();

  // The field is the only thing to do on the sign-in page / unlock dialog.
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

  const line = $derived(error ?? notice);
</script>

<form
  class="entry"
  class:dialog={oncancel !== undefined}
  onsubmit={(e) => {
    e.preventDefault();
    void send();
  }}
>
  {#if device.pinPad}
    <PinPad bind:value={pin} disabled={busy} onsubmit={send} />
    <p class="msg" class:err={line !== null} role="alert">{line ?? ''}</p>
  {:else}
    <div class="fieldwrap">
      <label class="lab" for="pin-field">{fieldLabel}</label>
      <input
        id="pin-field"
        type="password"
        inputmode="numeric"
        autocomplete="current-password"
        maxlength="8"
        aria-invalid={error !== null}
        aria-describedby="pin-help"
        bind:this={field}
        bind:value={pin}
        oninput={() => (pin = pin.replace(/\D/g, ''))}
      />
      <p id="pin-help" class="msg left" class:err={line !== null} role="alert">{line ?? help}</p>
    </div>
    {#if oncancel}
      <div class="foot">
        <button class="text" type="button" onclick={oncancel}>Cancel</button>
        <button class="filled" type="submit" disabled={pin.length < 4 || busy}>{label}</button>
      </div>
    {:else}
      <button class="filled wide" type="submit" disabled={pin.length < 4 || busy}>{label}</button>
    {/if}
  {/if}
</form>

<style>
  .entry {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 20px;
  }

  .entry.dialog {
    gap: 8px;
  }

  .lab {
    display: block;
    margin-bottom: 6px;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  input {
    width: 100%;
    height: 40px;
    padding: 0 12px;
    border: 1px solid var(--line-strong);
    border-radius: 10px;
    background: var(--field);
    color: var(--text);
    font-family: var(--mono);
    font-size: 18px;
    letter-spacing: 4px;
  }

  input:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: inset 0 0 0 1px var(--accent);
  }

  input[aria-invalid='true'] {
    border-color: var(--err);
    box-shadow: inset 0 0 0 1px var(--err);
  }

  /* One line for the help and, in its place, the error: nothing moves. */
  .msg {
    min-height: 18px;
    margin: 6px 0 0;
    color: var(--muted);
    font-size: 12.5px;
    text-align: center;
  }

  .msg.left {
    text-align: left;
  }

  .msg.err {
    color: var(--err);
  }

  .filled {
    height: 40px;
    padding: 0 22px;
    border: 0;
    border-radius: 999px;
    background: var(--primary);
    color: var(--on-primary);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }

  .filled.wide {
    width: 100%;
  }

  .filled:disabled {
    background: color-mix(in srgb, var(--text) 12%, transparent);
    color: var(--disabled);
    cursor: default;
  }

  .foot {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin: 0 -8px;
    padding-top: 12px;
  }

  .text {
    height: 40px;
    padding: 0 16px;
    border: 0;
    border-radius: 999px;
    background: none;
    color: var(--accent);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }

  @media (hover: hover) {
    .text:hover {
      background: var(--accent-soft);
    }
  }
</style>
