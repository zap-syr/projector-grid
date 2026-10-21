<!--
  A small rounded pill: an optional icon or dot, then a short label, tinted
  with its status colour on a 14 % fill with a 35 % border (`StatusPill` in
  the app's `status_pill.dart`).
-->
<script lang="ts" module>
  /** Status colours only, from tokens.css. */
  export type PillTone = 'ok' | 'warn' | 'err' | 'faint' | 'accent';
</script>

<script lang="ts">
  import Icon, { type IconName } from '../Icon.svelte';

  let {
    label,
    tone,
    icon,
    dot = false,
  }: { label: string; tone: PillTone; icon?: IconName; dot?: boolean } = $props();
</script>

<span class="pill" style:--c="var(--{tone})">
  {#if icon}<Icon name={icon} size={14} />{:else if dot}<i></i>{/if}
  <span class="l">{label}</span>
</span>

<style>
  .pill {
    height: 22px;
    max-width: 100%;
    padding: 0 8px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    flex: none;
    border-radius: 11px;
    border: 1px solid color-mix(in srgb, var(--c) 35%, transparent);
    background: color-mix(in srgb, var(--c) 14%, transparent);
    color: var(--c);
    font-size: 11.5px;
    font-weight: 600;
    line-height: 1.1;
    white-space: nowrap;
    vertical-align: middle;
  }

  i {
    width: 7px;
    height: 7px;
    margin-right: 2px;
    flex: none;
    border-radius: 50%;
    background: currentColor;
  }

  .l {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
