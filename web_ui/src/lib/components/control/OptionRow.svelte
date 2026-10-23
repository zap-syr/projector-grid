<!--
  A dropdown + Set, like the control bar's _DropdownRow (input, lens
  calibration, lens type, test pattern); [showLabel] puts the label above, as
  the app does for the rows that share a block. The list itself is the
  system's; with [swatch] the closed field shows the chosen pattern's
  thumbnail beside its name.
-->
<script lang="ts">
  import Icon from '../Icon.svelte';

  let {
    label,
    showLabel = false,
    options,
    disabled = false,
    action = 'Set',
    swatch,
    touch = false,
    onset,
  }: {
    label: string;
    showLabel?: boolean;
    options: readonly { code: string; label: string }[];
    disabled?: boolean;
    /** The send button's word (*Set*, *Show*). */
    action?: string;
    /** A test pattern's thumbnail colour for the closed field. */
    swatch?: (code: string) => string | null;
    /** 44 px for a finger. */
    touch?: boolean;
    onset: (code: string) => void;
  } = $props();

  // svelte-ignore state_referenced_locally
  let value = $state(options[0]?.code ?? '');
</script>

<label class="wrap" class:touch>
  {#if showLabel}
    <span class="cap">{label}</span>
  {/if}
  <span class="row">
    <span class="field" class:sw={swatch !== undefined}>
      {#if swatch}
        <i style:background={swatch(value) ?? 'var(--soft)'}></i>
      {/if}
      <select aria-label={label} bind:value>
        {#each options as o (o.code)}
          <option value={o.code}>{o.label}</option>
        {/each}
      </select>
      <span class="chev"><Icon name="chevron" size={touch ? 18 : 16} /></span>
    </span>
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

  .field {
    position: relative;
    display: flex;
    min-width: 0;
  }

  /* The chosen pattern's thumbnail over the closed field, before its name. */
  .field i {
    position: absolute;
    top: 50%;
    left: 10px;
    width: 22px;
    height: 14px;
    border-radius: 2px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
    transform: translateY(-50%);
    pointer-events: none;
  }

  /* The app's control bar: 36 px, the send button tonal so it stands out. */
  /* Our own chevron: iOS Safari ignores a native select's padding, which put
     the thumbnail over the pattern's name. */
  select {
    appearance: none;
    flex: 1;
    height: 36px;
    min-width: 0;
    padding: 0 34px 0 10px;
    border-radius: 10px;
    border: 1px solid var(--line-strong);
    background: var(--field);
    color: var(--text);
    font: inherit;
    font-size: 13.5px;
  }

  .sw select {
    padding-left: 40px;
  }

  .chev {
    position: absolute;
    top: 50%;
    right: 10px;
    display: flex;
    color: var(--muted);
    transform: translateY(-50%);
    pointer-events: none;
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

  .touch select,
  .touch .btn {
    height: 44px;
    border-radius: 12px;
  }

  .touch select {
    font-size: 15px;
  }

  .touch .btn {
    padding: 0 18px;
    font-size: 14px;
  }
</style>
