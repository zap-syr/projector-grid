<!--
  Lens step button: fires once on press, then repeats while held. The server
  drops a step while the previous one is still running on that projector.
-->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    label,
    disabled = false,
    onstep,
    children,
  }: { label: string; disabled?: boolean; onstep: () => void; children: Snippet } = $props();

  const REPEAT_MS = 250;
  let timer: ReturnType<typeof setInterval> | undefined;
  let held = $state(false);

  function start(e: PointerEvent) {
    if (disabled || e.button !== 0) return;
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    held = true;
    onstep();
    timer = setInterval(onstep, REPEAT_MS);
  }

  function stop() {
    held = false;
    clearInterval(timer);
    timer = undefined;
  }

  $effect(() => stop);
</script>

<button
  type="button"
  class:hold={held}
  aria-label={label}
  title={label}
  {disabled}
  onpointerdown={start}
  onpointerup={stop}
  onpointercancel={stop}
  onlostpointercapture={stop}
  onkeydown={(e) => {
    if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) onstep();
  }}
>
  {@render children()}
</button>

<style>
  button {
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid var(--line-strong);
    border-radius: 9px;
    background: var(--surface);
    color: var(--text);
    cursor: pointer;
    user-select: none;
    touch-action: none;
    width: 100%;
    height: 100%;
    font-size: 17px;
  }

  button:hover {
    background: var(--hover);
  }

  button.hold {
    background: var(--accent-soft);
    border-color: var(--accent);
    color: var(--accent);
  }

  button:disabled {
    opacity: 0.45;
    cursor: default;
  }
</style>
