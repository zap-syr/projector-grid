<!-- The *Preview* button in a projector's details (card strip, Map popover). -->
<script lang="ts">
  import Icon from '../Icon.svelte';

  let { onclick }: { onclick: () => void } = $props();
</script>

<button class="pv" {onclick}><Icon name="preview" size={16} />Preview</button>

<style>
  .pv {
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 6px;
    height: 32px;
    padding: 0 12px;
    border: 1px solid var(--line-strong);
    border-radius: var(--r-sm);
    background: var(--surface);
    color: var(--text);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  @media (hover: hover) {
    .pv:hover {
      background: var(--hover);
    }
  }

  @media (pointer: coarse) {
    .pv {
      height: 40px;
      padding: 0 14px;
    }
  }
</style>
