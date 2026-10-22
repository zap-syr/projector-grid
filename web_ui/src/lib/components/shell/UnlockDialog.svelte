<!--
  Unlock control, in the app's dialog frame (shell canvas, *Sign in…*): a
  title bar with the tile and ✕, the Operator PIN field with its help line,
  then Cancel / Unlock. On the PIN pad the pad's OK sends it.
-->
<script lang="ts">
  import { device } from '../../state/device.svelte';
  import { session } from '../../state/session.svelte';
  import Icon from '../Icon.svelte';
  import PinEntry from './PinEntry.svelte';

  let { onclose }: { onclose: () => void } = $props();

  async function submit(pin: string) {
    const error = await session.unlock(pin);
    if (!error) onclose();
    return error;
  }
</script>

<svelte:window
  onkeydowncapture={(e) => {
    // Handled here first, so the toolbar doesn't also clear the selection.
    if (e.key === 'Escape') {
      e.preventDefault();
      onclose();
    }
  }}
/>

<div class="overlay">
  <div class="dialog" role="dialog" aria-modal="true" aria-labelledby="unlock-title">
    <div class="tbar">
      <span class="tile"><Icon name="unlock" size={18} /></span>
      <div class="tt">
        <b id="unlock-title">Unlock control</b>
        {#if device.pinPad}<small>Operator PIN</small>{/if}
      </div>
      <button class="x" aria-label="Close" onclick={onclose}>
        <Icon name="close" size={20} />
      </button>
    </div>
    <div class="body" class:pad={device.pinPad}>
      <PinEntry
        label="Unlock"
        fieldLabel="Operator PIN"
        help="Lets this browser send commands until you lock it"
        autofocus
        oncancel={onclose}
        {submit}
      />
    </div>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 40;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
    background: var(--scrim);
  }

  .dialog {
    width: 100%;
    max-width: 420px;
    overflow: hidden;
    border: 1px solid var(--line-strong);
    border-radius: 20px;
    background: var(--surface);
    box-shadow: var(--sh-3);
  }

  .tbar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 8px 10px 20px;
    border-bottom: 1px solid var(--line);
    background: var(--card);
  }

  .tile {
    width: 30px;
    height: 30px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border-radius: 9px;
    background: var(--pc);
    color: var(--on-pc);
  }

  .tt {
    flex: 1;
    min-width: 0;
  }

  .tt b {
    display: block;
    font-size: 16px;
    font-weight: 600;
  }

  .tt small {
    display: block;
    color: var(--muted);
    font-size: 12.5px;
  }

  .x {
    width: 40px;
    height: 40px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  @media (hover: hover) {
    .x:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  .body {
    padding: 20px 24px 16px;
  }

  .body.pad {
    display: flex;
    justify-content: center;
    padding: 22px 0 14px;
  }
</style>
