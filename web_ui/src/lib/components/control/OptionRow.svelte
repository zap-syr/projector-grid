<!--
  A dropdown + Set, like the control bar's _DropdownRow (input, lens
  calibration, lens type); [showLabel] puts the label above, as the app does
  for the rows that share a block.
-->
<script lang="ts">
  let {
    label,
    showLabel = false,
    options,
    disabled = false,
    action = 'Set',
    onset,
  }: {
    label: string;
    showLabel?: boolean;
    options: readonly { code: string; label: string }[];
    disabled?: boolean;
    /** The send button's word (*Set*, *Show*). */
    action?: string;
    onset: (code: string) => void;
  } = $props();

  // svelte-ignore state_referenced_locally
  let value = $state(options[0]?.code ?? '');
</script>

<label class="wrap">
  {#if showLabel}
    <span class="cap">{label}</span>
  {/if}
  <span class="row">
    <select aria-label={label} bind:value>
      {#each options as o (o.code)}
        <option value={o.code}>{o.label}</option>
      {/each}
    </select>
    <button class="btn" {disabled} onclick={() => onset(value)}>{action}</button>
  </span>
</label>

<style>
  .wrap {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .cap {
    font-size: 12px;
    font-weight: 550;
    color: var(--muted);
  }

  .row {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 8px;
  }

  /* The app's control bar: 36 px, the send button tonal so it stands out. */
  select {
    height: 36px;
    min-width: 0;
    padding: 0 10px;
    border-radius: 10px;
    border: 1px solid var(--line-strong);
    background: var(--field);
    color: var(--text);
    font: inherit;
    font-size: 13.5px;
  }

  .btn {
    height: 36px;
    padding: 0 16px;
    border-radius: 10px;
    border: 0;
    background: var(--pc);
    color: var(--on-pc);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  .btn:hover {
    background: color-mix(in srgb, var(--on-pc) 10%, var(--pc));
  }

  .btn:disabled {
    opacity: 0.45;
    cursor: default;
  }
</style>
