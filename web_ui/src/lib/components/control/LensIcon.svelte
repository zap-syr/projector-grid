<!--
  The app's lens-shift icons (assets/icons/lens_shift, copied into
  src/assets/lens_shift): one, two or three chevrons for slow / normal / fast.
  Recoloured to currentColor so they follow the theme, like the app's
  colorFilter does.
-->
<script lang="ts" module>
  const files = import.meta.glob<string>('../../../assets/lens_shift/*.svg', {
    query: '?raw',
    import: 'default',
    eager: true,
  });

  const ICONS: Record<string, string> = Object.fromEntries(
    Object.entries(files).map(([path, svg]) => [
      path.replace(/^.*\/|\.svg$/g, ''),
      svg
        .replace(/<\?xml[^>]*>/, '')
        .replaceAll('#e3e3e3', 'currentColor')
        .replace('<svg', '<svg width="20" height="20" aria-hidden="true"'),
    ]),
  );

  export type LensDirection = 'up' | 'down' | 'left' | 'right';
  export type LensStepSpeed = 'slow' | 'normal' | 'fast';
</script>

<script lang="ts">
  let { dir, speed }: { dir: LensDirection; speed: LensStepSpeed } = $props();
</script>

<!-- eslint-disable-next-line svelte/no-at-html-tags -- bundled icon files, not user data -->
<span class="ic">{@html ICONS[`${dir}_${speed}`]}</span>

<style>
  .ic {
    display: flex;
  }
</style>
