<!--
  The app's Alignment banner across the page (ROADMAP §5 *Alignment mode on
  the web*): ◀ n / N ▶ (the ring on the card names the focused projector),
  Neighbours · Diagonals · Show
  all, the preset switch, Focused ▾ / Others ▾, Exit. A viewer gets one
  read-only line instead.
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

  const toggles: { op: 'neighbours' | 'diagonals' | 'showAll'; label: string; icon: IconName }[] = [
    { op: 'neighbours', label: 'Neighbours', icon: 'neighbours' },
    { op: 'diagonals', label: 'Diagonals', icon: 'diagonal' },
    { op: 'showAll', label: 'Show all', icon: 'all' },
  ];
  /** A sideways tablet: finger-sized controls (44–48 px). */
  const touch = $derived(device.touch);

  const on = (op: 'neighbours' | 'diagonals' | 'showAll') =>
    op === 'neighbours' ? a?.showNeighbours : op === 'diagonals' ? a?.includeDiagonals : a?.showAll;
</script>

<div class="banner" class:touch role="region" aria-label="Alignment mode">
  <span class="mode"><Icon name="target" size={touch ? 22 : 18} /></span>
  {#if !a || alignment.busy}
    <span class="busy"></span>
    <span>Alignment — reading / restoring projectors…</span>
  {:else if !operator}
    <span class="ro">
      Alignment in progress · <b>{alignment.focused?.name ?? '—'}</b> focused ·
      {position(alignment.order, a.focusedId).replace(' / ', ' of ')} · {presetLabel} — controlled by
      an operator
    </span>
  {:else}
    <div class="nav">
      <button class="icon" aria-label="Previous projector" onclick={() => alignment.prev()}>
        <Icon name="left" size={touch ? 26 : 18} />
      </button>
      <span class="pos">{position(alignment.order, a.focusedId)}</span>
      <button class="icon" aria-label="Next projector" onclick={() => alignment.next()}>
        <Icon name="right" size={touch ? 26 : 18} />
      </button>
    </div>
    <span class="sep"></span>
    {#each toggles as t (t.op)}
      <button
        class="tog"
        aria-pressed={on(t.op)}
        title={t.label}
        disabled={t.op === 'diagonals' && !a.showNeighbours}
        onclick={() => alignment.toggle(t.op)}
      >
        <Icon name={t.icon} size={touch ? 20 : 16} /><span class="tl">{t.label}</span>
      </button>
    {/each}
    <span class="sep"></span>
    <div class="seg" role="group" aria-label="Preset">
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
    <button class="exit" onclick={() => alignment.exit()}>Exit</button>
  {/if}
</div>

<style>
  .banner {
    display: flex;
    align-items: center;
    gap: 6px;
    min-height: 46px;
    padding: 4px 10px 4px 14px;
    background: var(--align);
    color: var(--on-align);
    font-size: 13px;
  }

  .mode {
    display: flex;
    margin-right: 2px;
  }

  .busy {
    width: 14px;
    height: 14px;
    border: 2px solid var(--on-align);
    border-right-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .ro b {
    font-weight: 700;
  }

  .nav {
    display: flex;
    align-items: center;
    gap: 2px;
    min-width: 0;
  }

  .pos {
    min-width: 5ch;
    font-variant-numeric: tabular-nums;
    text-align: center;
  }

  .sep {
    width: 1px;
    height: 22px;
    margin: 0 4px;
    background: rgb(0 0 0 / 0.18);
  }

  button {
    border: 0;
    background: none;
    color: inherit;
    font-size: 13px;
    cursor: pointer;
  }

  .icon {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 7px;
  }

  /* Hover only where there's a mouse (a touch screen keeps :hover after a
     tap), and never over a toggle that's on — it keeps its dark pill. */
  @media (hover: hover) {
    .icon:hover,
    .tog:not([aria-pressed='true']):hover:not(:disabled),
    .seg button:not([aria-pressed='true']):hover,
    .exit:hover {
      background: rgb(0 0 0 / 0.1);
    }
  }

  /* Off: plain text on the banner; on: a dark pill with orange text, like
     the app — same weight, so turning one on doesn't widen it. */
  .tog {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 32px;
    padding: 0 10px;
    border-radius: 999px;
    font-weight: 550;
  }

  .tog[aria-pressed='true'] {
    background: var(--on-align);
    color: var(--align);
  }

  .tog:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .seg {
    display: flex;
    gap: 2px;
    padding: 2px;
    border-radius: 8px;
    background: rgb(0 0 0 / 0.12);
  }

  .seg button {
    height: 28px;
    padding: 0 10px;
    border-radius: 6px;
    font-weight: 550;
  }

  .seg button[aria-pressed='true'] {
    background: var(--on-align);
    color: var(--align);
  }

  .grow {
    flex: 1;
  }

  .exit {
    height: 32px;
    padding: 0 14px;
    border-radius: 7px;
    border: 1px solid rgb(0 0 0 / 0.3);
    font-weight: 650;
  }

  /* Touch (a sideways tablet): everything at least 44 px, ◀ ▶ as wide,
     visible buttons well apart from the count — they're pressed the most —
     and Exit set off from the rest so it isn't hit by accident. */
  .touch {
    gap: 8px;
    min-height: 60px;
    padding: 6px 12px 6px 16px;
    font-size: 14px;
  }

  .touch .nav {
    gap: 8px;
  }

  /* The orange bar already says which mode this is; its room goes to ◀ ▶. */
  .touch .mode {
    display: none;
  }

  .touch .icon {
    flex: none;
    width: 56px;
    height: 48px;
    border-radius: 10px;
    background: rgb(0 0 0 / 0.1);
  }

  .touch .icon:active {
    background: rgb(0 0 0 / 0.22);
  }

  .touch .pos {
    min-width: 6ch;
    font-size: 15px;
    font-weight: 600;
  }

  .touch .sep {
    height: 32px;
    margin: 0 2px;
  }

  .touch .tog,
  .touch .seg,
  .touch .exit {
    flex: none;
  }

  .touch .tog {
    justify-content: center;
    min-width: 48px;
    height: 48px;
    padding: 0 12px;
    border-radius: 12px;
    font-size: 14px;
  }

  .touch .seg {
    padding: 3px;
    border-radius: 11px;
  }

  .touch .seg button {
    height: 42px;
    padding: 0 11px;
    border-radius: 8px;
    font-size: 14px;
  }

  .touch .exit {
    height: 44px;
    margin-left: 12px;
    padding: 0 18px;
    border-radius: 10px;
    font-size: 14px;
  }

  .touch :global(.wrap.banner .trigger) {
    height: 44px;
    padding: 0 10px;
    border-radius: 10px;
    font-size: 14px;
  }

  .touch :global(.wrap.banner .sw.sm) {
    width: 32px;
    height: 21px;
  }

  /* Narrower screens (a sideways tablet): icon toggles, like the app's banner. */
  @media (max-width: 1279px) {
    .tl {
      display: none;
    }

    .tog {
      padding: 0 8px;
    }

    .touch .tog {
      width: 48px;
      padding: 0;
    }
  }
</style>
