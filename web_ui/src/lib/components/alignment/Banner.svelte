<!--
  The app's Alignment banner across the page (shell canvas, *Alignment
  banner…*): one 52 px row tinted with the mode's orange, ◀ 3 of 24 ▶ (the
  ring on the card names the focused projector), Neighbours, Diagonals and
  Show all, the preset switch, Focused ▾ / Others ▾ and Exit alignment. A
  viewer gets one read-only sentence; entering or leaving, a spinner.
-->
<script lang="ts">
  import type { AlignmentPresetId, Config } from '../../api/types';
  import { position, presetPatterns } from '../../logic/alignment';
  import { testPatternLabel } from '../../logic/cells';
  import { alignment } from '../../state/alignment.svelte';
  import { device } from '../../state/device.svelte';
  import Icon, { type IconName } from '../Icon.svelte';
  import PatternPicker from './PatternPicker.svelte';

  let { config, operator }: { config: Config; operator: boolean } = $props();

  const patternLabels = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  const patternLabel = (code: string) => testPatternLabel(code, patternLabels);
  const a = $derived(alignment.value);
  const presetLabel = $derived(
    config.alignmentPresets.find((p) => p.id === a?.preset)?.label ?? '',
  );
  /** "3 of 24". */
  const pos = $derived(a ? position(alignment.order, a.focusedId).replace(' / ', ' of ') : '');

  const toggles: { op: 'neighbours' | 'diagonals' | 'showAll'; label: string; icon: IconName }[] = [
    { op: 'neighbours', label: 'Neighbours', icon: 'neighbours' },
    { op: 'diagonals', label: 'Diagonals', icon: 'diagonal' },
    { op: 'showAll', label: 'Show all', icon: 'all' },
  ];
  /** A sideways tablet: 60 px bar, 44 px controls. */
  const touch = $derived(device.touch);

  const on = (op: 'neighbours' | 'diagonals' | 'showAll') =>
    op === 'neighbours' ? a?.showNeighbours : op === 'diagonals' ? a?.includeDiagonals : a?.showAll;
</script>

<div class="banner" class:touch role="region" aria-label="Alignment mode">
  {#if !a || alignment.busy}
    <span class="atile"><span class="spin"></span></span>
    <span class="ro"><b>Alignment</b>, waiting for the projectors</span>
  {:else if !operator}
    <span class="atile"><Icon name="alignment" size={18} /></span>
    <span class="ro"
      ><b>Alignment</b>, <span class="mono">{alignment.focused?.ip ?? ''}</span> focused ({pos}),
      {presetLabel} patterns</span
    >
    <span class="grow"></span>
    <span class="lockn"><Icon name="lock" size={16} />An operator controls it</span>
  {:else}
    <span class="atile"><Icon name="alignment" size={18} /></span>
    <span class="at">Alignment</span>
    <div class="nav">
      <button class="nb" aria-label="Previous projector" onclick={() => alignment.prev()}>
        <Icon name="left" size={touch ? 22 : 18} />
      </button>
      <span class="pos">{pos}</span>
      <button class="nb" aria-label="Next projector" onclick={() => alignment.next()}>
        <Icon name="right" size={touch ? 22 : 18} />
      </button>
    </div>
    <span class="sep"></span>
    {#each toggles as t (t.op)}
      <button
        class="tog"
        aria-pressed={on(t.op)}
        aria-label={t.label}
        title={t.label}
        disabled={t.op === 'diagonals' && !a.showNeighbours}
        onclick={() => alignment.toggle(t.op)}
      >
        <Icon name={t.icon} size={touch ? 20 : 16} /><span class="tl">{t.label}</span>
      </button>
    {/each}
    <span class="sep"></span>
    <div class="seg" role="group" aria-label="Patterns">
      {#each config.alignmentPresets as p (p.id)}
        <button
          aria-pressed={a.preset === p.id}
          onclick={() => alignment.setPreset(p.id as AlignmentPresetId)}>{p.label}</button
        >
      {/each}
    </div>
    <PatternPicker
      label="Focused"
      variant="banner"
      value={a.focusedPattern}
      patterns={presetPatterns(config, a)}
      {patternLabel}
      onpick={(code) => code && alignment.setFocusedPattern(code)}
    />
    <PatternPicker
      label="Others"
      variant="banner"
      value={a.othersPattern}
      patterns={presetPatterns(config, a)}
      same
      {patternLabel}
      onpick={(code) => alignment.setOthersPattern(code)}
    />
    <span class="grow"></span>
    <!-- Labelled, and no Esc: a stray one would restore the whole wall. -->
    <button class="exit" onclick={() => alignment.exit()}
      ><Icon name="close" size={18} />Exit alignment</button
    >
  {/if}
</div>

<style>
  .banner {
    height: 52px;
    display: flex;
    flex: none;
    align-items: center;
    gap: 8px;
    padding: 0 12px 0 14px;
    background: color-mix(in srgb, var(--align) 9%, var(--surface));
    border-bottom: 1px solid color-mix(in srgb, var(--align) 40%, transparent);
    font-size: 13px;
  }

  .atile {
    width: 30px;
    height: 30px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border-radius: 9px;
    background: color-mix(in srgb, var(--align) 18%, transparent);
    color: var(--align);
  }

  .spin {
    width: 18px;
    height: 18px;
    border: 2px solid color-mix(in srgb, var(--align) 30%, transparent);
    border-top-color: var(--align);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .at {
    margin-right: 4px;
    font-size: 13.5px;
    font-weight: 600;
  }

  .ro {
    min-width: 0;
    overflow: hidden;
    color: var(--muted);
    font-size: 13.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ro b {
    color: var(--text);
    font-weight: 600;
  }

  .mono {
    color: var(--text);
    font-family: var(--mono);
    letter-spacing: 0;
    font-weight: 600;
  }

  .lockn {
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 7px;
    color: var(--faint);
    font-size: 12.5px;
  }

  .nav {
    display: flex;
    align-items: center;
    gap: 2px;
  }

  button {
    font: inherit;
    color: inherit;
    cursor: pointer;
  }

  .nb {
    width: 34px;
    height: 34px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 50%;
    background: none;
  }

  .pos {
    min-width: 62px;
    font-size: 13.5px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    text-align: center;
  }

  .sep {
    width: 1px;
    height: 24px;
    flex: none;
    margin: 0 4px;
    background: color-mix(in srgb, var(--align) 30%, var(--line-strong));
  }

  /* Off: an outlined pill; on: primaryContainer, as the app's toolbar (owner,
     2026-10-21). Same weight either way, so turning one on doesn't widen it. */
  .tog {
    height: 32px;
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 7px;
    padding: 0 12px 0 10px;
    border: 1px solid var(--line-strong);
    border-radius: 999px;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .tog[aria-pressed='true'] {
    border-color: var(--accent);
    background: var(--pc);
    color: var(--on-pc);
  }

  .tog:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .seg {
    display: flex;
    flex: none;
    gap: 2px;
    padding: 3px;
    border: 1px solid var(--line);
    border-radius: 10px;
    background: var(--hover);
  }

  .seg button {
    height: 26px;
    padding: 0 10px;
    border: 0;
    border-radius: 7px;
    background: none;
    color: var(--faint);
    font-size: 12.5px;
    font-weight: 500;
  }

  .seg button[aria-pressed='true'] {
    background: var(--card);
    color: var(--text);
    font-weight: 600;
    box-shadow: var(--sh-1);
  }

  /* Hover only where there's a mouse, and never over what's on. */
  @media (hover: hover) {
    .nb:hover,
    .tog:not([aria-pressed='true']):hover:not(:disabled),
    .seg button:not([aria-pressed='true']):hover,
    .exit:hover {
      background: var(--hover);
    }
  }

  .grow {
    flex: 1;
  }

  .exit {
    height: 34px;
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 8px;
    padding: 0 14px;
    border: 1px solid var(--line-strong);
    border-radius: 10px;
    background: none;
    font-size: 13px;
    font-weight: 600;
  }

  .exit :global(svg) {
    color: var(--err);
  }

  /* Touch (a sideways tablet): a 60 px bar and 44 px controls. */
  .touch {
    height: 60px;
  }

  .touch .nb {
    width: 44px;
    height: 44px;
  }

  .touch .tog,
  .touch .exit {
    height: 44px;
  }

  .touch .tog {
    border-radius: 12px;
  }

  .touch .seg button {
    height: 38px;
    font-size: 13.5px;
  }

  .touch :global(.wrap.banner .trigger) {
    height: 44px;
  }

  /* Narrower screens: icon toggles, like the app's banner. */
  @media (max-width: 1279px) {
    .tl {
      display: none;
    }

    .tog {
      width: 34px;
      justify-content: center;
      padding: 0;
    }

    .touch .tog {
      width: 44px;
    }
  }
</style>
