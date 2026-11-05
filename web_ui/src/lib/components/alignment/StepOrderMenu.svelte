<!--
  The banner's *Step order* button: a round button after ▶ (the app's
  Presets ▾ › Step order submenu) opening a popover with Layout / IP address.
  No on state: either order is valid, so the button never fills.
-->
<script lang="ts">
  import type { AlignmentStepOrder } from '../../api/types';
  import { stepOrders } from '../../logic/alignment';
  import { device } from '../../state/device.svelte';
  import Icon from '../Icon.svelte';

  let {
    value,
    onpick,
  }: { value: AlignmentStepOrder; onpick: (order: AlignmentStepOrder) => void } = $props();

  let open = $state(false);
  let wrap = $state<HTMLElement>();
  const current = $derived(stepOrders.find((o) => o.id === value)?.label ?? '');

  function pick(order: AlignmentStepOrder) {
    open = false;
    onpick(order);
  }
</script>

<svelte:window
  onpointerdown={(e) => {
    if (open && wrap && !wrap.contains(e.target as Node)) open = false;
  }}
  onkeydowncapture={(e) => {
    if (open && e.key === 'Escape') {
      e.preventDefault();
      open = false;
    }
  }}
/>

<div class="wrap" bind:this={wrap}>
  <button
    class="nb"
    class:touch={device.touch}
    aria-label="Step order: {current}"
    title="Step order: {current}"
    aria-haspopup="true"
    aria-expanded={open}
    onclick={() => (open = !open)}
  >
    <Icon name="stepOrder" size={device.touch ? 22 : 18} />
  </button>
  {#if open}
    <div class="pop" role="group" aria-label="Step order">
      <div class="cap">Step order</div>
      {#each stepOrders as o (o.id)}
        <label class="opt" class:touch={device.touch}>
          <input
            type="radio"
            name="step-order"
            checked={o.id === value}
            onchange={() => pick(o.id)}
          />{o.label}
        </label>
      {/each}
    </div>
  {/if}
</div>

<style>
  .wrap {
    position: relative;
    flex: none;
  }

  /* The ◀ ▶ circle, so the nav group reads as one block. */
  .nb {
    width: 34px;
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 50%;
    background: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
  }

  .nb.touch {
    width: 44px;
    height: 44px;
  }

  .nb[aria-expanded='true'] {
    background: var(--hover);
  }

  @media (hover: hover) {
    .nb:hover {
      background: var(--hover);
    }
  }

  .pop {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    z-index: 30;
    width: 200px;
    padding: 6px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 11px;
    box-shadow: var(--sh-2);
  }

  .cap {
    padding: 6px 10px 4px;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .opt {
    height: 38px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 10px;
    border-radius: 8px;
    font-size: 13.5px;
    cursor: pointer;
  }

  .opt.touch {
    height: 44px;
  }

  .opt:hover {
    background: var(--hover);
  }

  .opt input {
    width: 16px;
    height: 16px;
    margin: 0;
    accent-color: var(--accent);
    cursor: pointer;
  }
</style>
