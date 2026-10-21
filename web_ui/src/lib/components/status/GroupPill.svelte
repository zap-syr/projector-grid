<!-- A group's name with its colour dot, read-only (`GroupPill`); caps its own width. -->
<script lang="ts">
  import type { Group } from '../../api/types';

  let { group }: { group: Group } = $props();
</script>

<span class="gp" title={group.name}>
  <i style:background={group.color}></i>
  <span class="l">{group.name}</span>
</span>

<style>
  .gp {
    height: 22px;
    max-width: 160px;
    padding: 0 8px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    flex: none;
    border-radius: 11px;
    border: 1px solid var(--line-strong);
    background: var(--soft);
    color: var(--text);
    font-size: 11.5px;
    font-weight: 500;
    line-height: 1.1;
    white-space: nowrap;
    vertical-align: middle;
  }

  i {
    width: 8px;
    height: 8px;
    flex: none;
    border-radius: 50%;
  }

  .l {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
