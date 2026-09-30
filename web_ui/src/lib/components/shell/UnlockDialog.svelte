<!-- Unlock control: the Operator PIN upgrades this session to operator. -->
<script lang="ts">
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
  onkeydown={(e) => {
    if (e.key === 'Escape') onclose();
  }}
/>

<div class="overlay">
  <div class="dialog" role="dialog" aria-modal="true" aria-labelledby="unlock-title">
    <div class="head">
      <span class="ic"><Icon name="unlock" size={20} /></span>
      <div>
        <h4 id="unlock-title">Unlock control</h4>
        <p>Operator PIN</p>
      </div>
      <button class="x" aria-label="Cancel" onclick={onclose}>
        <Icon name="close" size={16} />
      </button>
    </div>
    <PinEntry label="Unlock" autofocus {submit} />
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
    max-width: 360px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    padding: 22px 22px 10px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 16px;
    box-shadow: var(--sh-3);
  }

  .head {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .ic {
    width: 40px;
    height: 40px;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 11px;
    background: var(--accent-soft);
    color: var(--accent);
  }

  h4 {
    margin: 0;
    font-size: 17px;
    font-weight: 650;
  }

  p {
    margin: 0;
    font-size: 13px;
    color: var(--muted);
  }

  .x {
    margin-left: auto;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .x:hover {
    background: var(--hover);
    color: var(--text);
  }
</style>
