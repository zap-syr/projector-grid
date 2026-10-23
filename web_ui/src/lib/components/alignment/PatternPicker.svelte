<!--
  Picks the Focused or Others pattern from the ones the preset offers (the
  app's Presets ▾ submenus). A swatch popover under the banner button on
  desktop; a row that opens a sheet with the swatch grid on touch layouts.
-->
<script lang="ts">
  import { patternSwatch } from '../../logic/patterns';
  import { device } from '../../state/device.svelte';
  import Icon from '../Icon.svelte';
  import Sheet from '../phone/Sheet.svelte';

  let {
    label,
    value,
    patterns,
    same = false,
    patternLabel,
    variant,
    disabled = false,
    onpick,
  }: {
    label: string;
    /** null = same as focused (Others only). */
    value: string | null;
    patterns: readonly string[];
    /** Offer *Same as focused* first. */
    same?: boolean;
    patternLabel: (code: string) => string;
    variant: 'banner' | 'row';
    disabled?: boolean;
    onpick: (code: string | null) => void;
  } = $props();

  let open = $state(false);
  let wrap = $state<HTMLElement>();
  let pop = $state<HTMLElement>();
  /** The popover would run off the right edge: it opens leftwards instead. */
  let flip = $state(false);

  $effect(() => {
    if (pop && wrap) {
      flip = wrap.getBoundingClientRect().left + pop.offsetWidth > window.innerWidth - 8;
    }
  });
  const text = (code: string | null) => (code === null ? 'Same as focused' : patternLabel(code));

  function pick(code: string | null) {
    open = false;
    onpick(code);
  }
</script>

<svelte:window
  onpointerdown={(e) => {
    if (open && variant === 'banner' && wrap && !wrap.contains(e.target as Node)) open = false;
  }}
  onkeydowncapture={(e) => {
    if (open && variant === 'banner' && e.key === 'Escape') {
      e.preventDefault();
      open = false;
    }
  }}
/>

{#snippet swatch(code: string | null, size: 'sm' | 'lg')}
  <span
    class="sw {size}"
    class:same={code === null}
    style:background={code === null ? undefined : (patternSwatch(code) ?? 'var(--hover)')}
  ></span>
{/snippet}

{#snippet grid()}
  <div class="grid" role="listbox" aria-label="{label} pattern">
    {#each same ? [null, ...patterns] : patterns as code (code ?? 'same')}
      <button
        class="opt"
        role="option"
        aria-selected={code === value}
        title={text(code)}
        onclick={() => pick(code)}
      >
        {@render swatch(code, 'lg')}
        <span class="nm">{text(code)}</span>
      </button>
    {/each}
  </div>
{/snippet}

<div class="wrap {variant}" bind:this={wrap}>
  <button
    class="trigger"
    {disabled}
    aria-haspopup="listbox"
    aria-expanded={open}
    onclick={() => (open = !open)}
  >
    {#if variant === 'row'}
      <span class="rl">{label}</span>
      {@render swatch(value, 'sm')}
      <span class="val">{text(value)}</span>
      <Icon name="right" size={16} />
    {:else}
      <!-- The banner is tight: the swatch alone names the pattern (full name on hover). -->
      <span class="bl">{label}</span>
      <span class="swt" title={text(value)}>{@render swatch(value, 'sm')}</span>
      <span class="sr">{text(value)}</span>
      <Icon name="chevron" size={14} />
    {/if}
  </button>
  {#if open && variant === 'banner'}
    <div class="pop" class:touch={device.touch} class:flip bind:this={pop}>
      {@render grid()}
    </div>
  {/if}
</div>

{#if open && variant === 'row'}
  <Sheet
    label="{label} pattern"
    placement={device.control === 'right' ? 'right' : 'bottom'}
    onclose={() => (open = false)}
  >
    <div class="sheet">
      <h3>{label} pattern</h3>
      {@render grid()}
    </div>
  </Sheet>
{/if}

<style>
  .wrap {
    position: relative;
    min-width: 0;
  }

  .trigger {
    display: flex;
    align-items: center;
    gap: 7px;
    min-width: 0;
    border: 0;
    background: none;
    cursor: pointer;
  }

  .trigger:disabled {
    cursor: default;
    opacity: 0.6;
  }

  /* In the banner: a field with the label, the swatch and ▾. */
  .banner .trigger {
    height: 32px;
    gap: 8px;
    padding: 0 6px 0 10px;
    border: 1px solid var(--line-strong);
    border-radius: 9px;
    background: var(--field);
    color: var(--muted);
    font-size: 12.5px;
  }

  .banner .trigger:hover:not(:disabled),
  .banner .trigger[aria-expanded='true'] {
    border-color: var(--accent-line);
  }

  .banner .trigger :global(svg) {
    color: var(--faint);
  }

  .swt {
    display: flex;
  }

  /* Read out, not shown. */
  .sr {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip-path: inset(50%);
  }

  /* A settings row on the touch screen. */
  .row .trigger {
    width: 100%;
    height: 52px;
    padding: 0 12px;
    border: 1px solid var(--line);
    border-radius: var(--r);
    background: var(--surface);
    font-size: 15px;
  }

  .rl {
    min-width: 70px;
    color: var(--muted);
    font-weight: 550;
    text-align: left;
  }

  .row .val {
    flex: 1;
    overflow: hidden;
    font-weight: 600;
    text-align: left;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .row .trigger :global(svg) {
    color: var(--faint);
  }

  .sw {
    flex: none;
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .sw.sm {
    width: 26px;
    height: 17px;
  }

  .sw.lg {
    width: 100%;
    height: 34px;
    border-radius: 5px;
  }

  /* Same as focused: a split swatch. */
  .sw.same {
    background: repeating-linear-gradient(135deg, var(--hover) 0 5px, var(--surface) 5px 10px);
  }

  .pop {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    z-index: 30;
    width: 380px;
    padding: 8px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 11px;
    box-shadow: var(--sh-2);
  }

  .pop.flip {
    left: auto;
    right: 0;
  }

  /* A finger needs bigger tiles than a mouse; six a row and never taller
     than the screen under the banner, the rest scrolls inside (owner,
     2026-10-23: four a row ran off a sideways iPad). */
  .pop.touch {
    width: 640px;
    max-height: calc(100dvh - 140px);
    overflow-y: auto;
    overscroll-behavior: contain;
    padding: 10px;
  }

  .pop.touch .grid {
    grid-template-columns: repeat(6, 1fr);
    gap: 8px;
  }

  .pop.touch .opt {
    padding: 7px;
    font-size: 12.5px;
  }

  .pop.touch .sw.lg {
    height: 36px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 6px;
  }

  .opt {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
    padding: 5px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: var(--surface);
    color: var(--muted);
    font-size: 11px;
    font-weight: 550;
    cursor: pointer;
  }

  .opt:hover {
    border-color: var(--align-2);
  }

  .opt[aria-selected='true'] {
    border-color: var(--align);
    color: var(--text);
    box-shadow: 0 0 0 1px var(--align);
  }

  /* Two lines: "Cross Hatch Magenta" is the longest and must read whole. */
  .nm {
    display: -webkit-box;
    min-height: 2.4em;
    overflow: hidden;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    line-height: 1.2;
    text-align: left;
  }

  .sheet {
    overflow: auto;
    padding: 4px 16px 16px;
  }

  .sheet h3 {
    margin: 4px 0 12px;
    font-size: 15px;
    font-weight: 650;
  }

  .sheet .grid {
    grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
    gap: 8px;
  }

  .sheet .opt {
    padding: 7px;
    font-size: 12.5px;
  }

  .sheet .sw.lg {
    height: 48px;
  }
</style>
