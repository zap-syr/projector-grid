<!-- On-screen PIN keypad for phones: dots for the digits typed, 0–9, delete, OK. -->
<script lang="ts">
  let {
    value = $bindable(''),
    disabled = false,
    onsubmit,
  }: { value?: string; disabled?: boolean; onsubmit: () => void } = $props();

  const MAX = 8;
  // At least four dots, so an empty pad still shows what's expected.
  const dots = $derived(Math.max(4, value.length));

  const press = (d: string) => {
    if (value.length < MAX) value += d;
  };
</script>

<div class="pad">
  <div class="dots" aria-label="{value.length} digits entered">
    {#each { length: dots }, i (i)}
      <i class:on={i < value.length}></i>
    {/each}
  </div>
  <div class="keys">
    {#each ['1', '2', '3', '4', '5', '6', '7', '8', '9'] as d (d)}
      <button type="button" class="key" {disabled} onclick={() => press(d)}>{d}</button>
    {/each}
    <button
      type="button"
      class="key ghost"
      disabled={disabled || !value}
      onclick={() => (value = value.slice(0, -1))}>Delete</button
    >
    <button type="button" class="key" {disabled} onclick={() => press('0')}>0</button>
    <button type="button" class="key ok" disabled={disabled || value.length < 4} onclick={onsubmit}
      >OK</button
    >
  </div>
</div>

<style>
  .pad {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 22px;
  }

  .dots {
    display: flex;
    gap: 14px;
    min-height: 13px;
  }

  .dots i {
    width: 13px;
    height: 13px;
    border-radius: 50%;
    border: 1.5px solid var(--line-strong);
  }

  .dots i.on {
    background: var(--text);
    border-color: var(--text);
  }

  .keys {
    display: grid;
    grid-template-columns: repeat(3, 66px);
    gap: 14px 20px;
  }

  .key {
    width: 66px;
    height: 66px;
    border: 0;
    border-radius: 50%;
    background: var(--hover);
    font-size: 25px;
    font-weight: 450;
    cursor: pointer;
    touch-action: manipulation;
  }

  .key:active {
    background: var(--line-strong);
  }

  .key.ghost {
    background: none;
    color: var(--muted);
    font-size: 14px;
  }

  .key.ok {
    background: var(--accent);
    color: var(--on-accent);
    font-size: 16px;
    font-weight: 600;
  }

  .key:disabled {
    opacity: 0.4;
    cursor: default;
  }
</style>
