<!--
  Touch layouts' bar under the list while something is selected: opens the
  Control sheet. The count and the clear live in the toolbar's bulk selector.
-->
<script lang="ts">
  import { panel } from '../../state/panel.svelte';
  import Icon from '../Icon.svelte';
</script>

<div class="bar">
  <button class="btn" onclick={() => (panel.sheet = true)}>
    <Icon name="panel" size={16} /> Control
  </button>
</div>

<style>
  .bar {
    padding: 10px 12px calc(10px + env(safe-area-inset-bottom));
    background: var(--surface);
    border-top: 1px solid var(--line);
    box-shadow: 0 -4px 16px -8px rgba(16, 24, 40, 0.18);
  }

  .btn {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 44px;
    border: 1px solid var(--accent);
    border-radius: var(--r-sm);
    background: var(--accent);
    color: var(--on-accent);
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
  }
</style>
