<!--
  Alignment mode on touch layouts (ROADMAP §5, *Phone* — walking the room
  with a phone): big ◀ ▶ with the focused name, Neighbours / Diagonals /
  Show all, the wall mini-map, the preset switch and Focused / Others rows,
  then the lens for the focused projector. A viewer sees the same screen
  without the controls.
-->
<script lang="ts">
  import type { AlignmentPresetId, Config } from '../../api/types';
  import { position, presetPatterns } from '../../logic/alignment';
  import { testPatternLabel } from '../../logic/cells';
  import { alignment } from '../../state/alignment.svelte';
  import ControlPanel from '../control/ControlPanel.svelte';
  import Icon, { type IconName } from '../Icon.svelte';
  import PatternPicker from './PatternPicker.svelte';
  import WallMap from './WallMap.svelte';

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
  const on = (op: 'neighbours' | 'diagonals' | 'showAll') =>
    op === 'neighbours' ? a?.showNeighbours : op === 'diagonals' ? a?.includeDiagonals : a?.showAll;
</script>

<div class="screen">
  {#if !a || alignment.busy}
    <p class="busy"><span class="spin"></span>Reading / restoring projectors…</p>
  {:else}
    <div class="nav">
      {#if operator}
        <button class="step" aria-label="Previous projector" onclick={() => alignment.prev()}>
          <Icon name="left" size={28} />
        </button>
      {/if}
      <div class="who">
        <b>{alignment.focused?.name ?? '—'}</b>
        <span>{position(alignment.order, a.focusedId)} · {presetLabel}</span>
      </div>
      {#if operator}
        <button class="step" aria-label="Next projector" onclick={() => alignment.next()}>
          <Icon name="right" size={28} />
        </button>
      {/if}
    </div>

    {#if !operator}
      <p class="ro">Controlled by an operator</p>
    {:else}
      <div class="toggles">
        {#each toggles as t (t.op)}
          <button
            aria-pressed={on(t.op)}
            disabled={t.op === 'diagonals' && !a.showNeighbours}
            onclick={() => alignment.toggle(t.op)}
          >
            <Icon name={t.icon} size={18} />{t.label}
          </button>
        {/each}
      </div>
    {/if}

    <WallMap {operator} {patternLabel} />

    {#if operator}
      <section>
        <h6>Patterns</h6>
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
          variant="row"
          value={a.focusedPattern}
          patterns={presetPatterns(config, a)}
          {patternLabel}
          onpick={(code) => code && alignment.setFocusedPattern(code)}
        />
        <PatternPicker
          label="Others"
          variant="row"
          value={a.othersPattern}
          patterns={presetPatterns(config, a)}
          same
          {patternLabel}
          onpick={(code) => alignment.setOthersPattern(code)}
        />
      </section>

      <ControlPanel {config} embedded onclose={() => {}} />

      <button class="exit" onclick={() => alignment.exit()}>Exit alignment</button>
    {/if}
  {/if}
</div>

<style>
  .screen {
    height: 100%;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 12px 14px calc(20px + env(safe-area-inset-bottom));
    overscroll-behavior: contain;
  }

  /* The screen scrolls; its blocks keep their height instead of squeezing. */
  .screen > :global(*) {
    flex: none;
  }

  .busy {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    margin: 48px 0;
    color: var(--muted);
  }

  .spin {
    width: 16px;
    height: 16px;
    border: 2px solid var(--align);
    border-right-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  /* Stays at the top while the lens below is scrolled to, so the next
     projector is one tap away. The shadow covers the padding above it,
     where scrolled content would otherwise show. */
  .nav {
    position: sticky;
    top: 0;
    /* Above the embedded Control panel's own layer (z-index 5). */
    z-index: 6;
    box-shadow:
      0 -12px 0 var(--app),
      0 6px 16px -8px rgb(0 0 0 / 0.35);
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px;
    border-radius: var(--r-lg);
    background: var(--align);
    color: var(--on-align);
  }

  .step {
    width: 64px;
    height: 64px;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 12px;
    background: rgb(0 0 0 / 0.12);
    color: inherit;
    cursor: pointer;
  }

  .step:active {
    background: rgb(0 0 0 / 0.22);
  }

  .who {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 4px 0;
  }

  .who b {
    max-width: 100%;
    overflow: hidden;
    font-size: 22px;
    font-weight: 750;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .who span {
    font-size: 13.5px;
    font-variant-numeric: tabular-nums;
  }

  .ro {
    margin: -4px 0 0;
    text-align: center;
    color: var(--muted);
    font-size: 13px;
  }

  .toggles {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }

  .toggles button {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
    height: 58px;
    border: 1px solid var(--line-strong);
    border-radius: var(--r);
    background: var(--surface);
    color: var(--muted);
    font-size: 13px;
    font-weight: 550;
    cursor: pointer;
  }

  .toggles button[aria-pressed='true'] {
    border-color: var(--align);
    background: var(--align-soft);
    color: var(--text);
    box-shadow: 0 0 0 1px var(--align);
  }

  .toggles button:disabled {
    opacity: 0.45;
    cursor: default;
  }

  section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  h6 {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 4px 0 0;
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--align);
  }

  h6::after {
    content: '';
    flex: 1;
    height: 1px;
    background: color-mix(in srgb, var(--align) 40%, transparent);
  }

  .seg {
    display: grid;
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: 2px;
    padding: 3px;
    border-radius: 9px;
    background: var(--hover);
  }

  .seg button {
    height: 40px;
    border: 0;
    border-radius: 7px;
    background: none;
    color: var(--muted);
    font-size: 14px;
    font-weight: 550;
    cursor: pointer;
  }

  .seg button[aria-pressed='true'] {
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  .exit {
    flex: none;
    height: 50px;
    margin-top: 6px;
    border: 1px solid var(--align);
    border-radius: var(--r);
    background: var(--surface);
    color: var(--text);
    font-size: 15px;
    font-weight: 650;
    cursor: pointer;
  }
</style>
