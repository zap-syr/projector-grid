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
    disabled,
    onset,
  }: {
    label: string;
    showLabel?: boolean;
    options: readonly { code: string; label: string }[];
    disabled: boolean;
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
    <button class="btn" {disabled} onclick={() => onset(value)}>Set</button>
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

  select {
    height: 34px;
    min-width: 0;
    padding: 0 10px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--surface);
    color: var(--text);
    font: inherit;
    font-size: 13.5px;
  }

  .btn {
    height: 34px;
    padding: 0 14px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-size: 13.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--hover);
  }

  .btn:disabled {
    opacity: 0.45;
    cursor: default;
  }
</style>
