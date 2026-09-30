<script lang="ts" module>
  /** Stroke icons (24×24 grid), inline so the page needs no icon font or CDN. */
  const PATHS = {
    power: '<path d="M12 3v8"/><path d="M6.3 6.8a8 8 0 1 0 11.4 0"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    check: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9.5"/>',
    error: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.5v.01"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    unlock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 7.5-2"/>',
    chevron: '<path d="M6 9l6 6 6-6"/>',
    arrow: '<path d="M12 19V5M6 11l6-6 6 6"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    columns: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M9 4v16M15 4v16"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
  } as const;

  export type IconName = keyof typeof PATHS;
</script>

<script lang="ts">
  let { name, size = 16 }: { name: IconName; size?: number } = $props();
</script>

<svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
  <!-- eslint-disable-next-line svelte/no-at-html-tags -- static paths from PATHS above -->
  {@html PATHS[name]}
</svg>

<style>
  svg {
    flex: none;
    stroke: currentColor;
    fill: none;
    stroke-width: 1.8;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
</style>
