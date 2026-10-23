<!--
  Alignment mode on touch layouts (shell canvas, *Phone Alignment screen…*):
  a pinned step bar with big ◀ ▶ around the focused projector's IP, model and
  place in the order; under it Neighbours / Diagonals / Show all and the
  cards Wall, Patterns and Lens, then Exit alignment. A viewer gets the bar
  without arrows, the wall and the patterns read-only.
-->
<script lang="ts">
  import type { AlignmentPresetId, Config } from '../../api/types';
  import { position, presetPatterns } from '../../logic/alignment';
  import { testPatternLabel } from '../../logic/cells';
  import { patternSwatch } from '../../logic/patterns';
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
  const focused = $derived(alignment.focused);

  const toggles: { op: 'neighbours' | 'diagonals' | 'showAll'; label: string; icon: IconName }[] = [
    { op: 'neighbours', label: 'Neighbours', icon: 'neighbours' },
    { op: 'diagonals', label: 'Diagonals', icon: 'diagonal' },
    { op: 'showAll', label: 'Show all', icon: 'all' },
  ];
  const on = (op: 'neighbours' | 'diagonals' | 'showAll') =>
    op === 'neighbours' ? a?.showNeighbours : op === 'diagonals' ? a?.includeDiagonals : a?.showAll;
</script>

{#snippet roRow(label: string, code: string | null)}
  <div class="prow">
    <span class="l">{label}</span>
    <i style:background={code ? (patternSwatch(code) ?? 'var(--soft)') : 'var(--soft)'}></i>
    <span class="n">{code ? patternLabel(code) : 'Same as focused'}</span>
  </div>
{/snippet}

<div class="screen">
  {#if !a || alignment.busy}
    <p class="busy"><span class="spin"></span>Alignment, waiting for the projectors</p>
  {:else}
    <!-- Pinned: the list below scrolls, the next projector stays one tap away. -->
    <div class="nav" class:ro={!operator}>
      {#if operator}
        <button class="step" aria-label="Previous projector" onclick={() => alignment.prev()}>
          <Icon name="left" size={28} />
        </button>
      {/if}
      <div class="who">
        <span class="tag">Alignment</span>
        <b>{focused?.ip ?? ''}</b>
        <span
          >{focused?.name ?? ''}, {position(alignment.order, a.focusedId).replace(
            ' / ',
            ' of ',
          )}</span
        >
      </div>
      {#if operator}
        <button class="step" aria-label="Next projector" onclick={() => alignment.next()}>
          <Icon name="right" size={28} />
        </button>
      {/if}
    </div>

    <div class="body">
      {#if operator}
        <div class="tgs">
          {#each toggles as t (t.op)}
            <button
              class="tog"
              aria-pressed={on(t.op)}
              disabled={t.op === 'diagonals' && !a.showNeighbours}
              onclick={() => alignment.toggle(t.op)}
            >
              <Icon name={t.icon} size={18} />{t.label}
            </button>
          {/each}
        </div>
      {:else}
        <p class="rol"><Icon name="lock" size={16} />An operator controls it</p>
      {/if}

      <section class="card">
        <div class="ch"><Icon name="map" size={16} />Wall</div>
        <WallMap {operator} {patternLabel} />
      </section>

      <section class="card">
        <div class="ch"><Icon name="grid" size={16} />Patterns</div>
        {#if operator}
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
        {:else}
          <p class="preset">{presetLabel}</p>
          {@render roRow('Focused', a.focusedPattern)}
          {@render roRow('Others', a.othersPattern)}
        {/if}
      </section>

      {#if operator}
        <section class="card">
          <!-- The lens names itself, with Home in its header. -->
          <ControlPanel {config} embedded onclose={() => {}} />
        </section>

        <button class="exit" onclick={() => alignment.exit()}
          ><Icon name="close" size={20} />Exit alignment</button
        >
      {/if}
    </div>
  {/if}
</div>

<style>
  .screen {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;
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

  /* The step bar, tinted with the mode's orange like the desktop banner. */
  .nav {
    flex: none;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    background: color-mix(in srgb, var(--align) 9%, var(--surface));
    border-bottom: 1px solid color-mix(in srgb, var(--align) 40%, transparent);
  }

  .nav.ro {
    padding: 14px 12px;
  }

  .step {
    width: 56px;
    height: 56px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 16px;
    background: var(--app);
    color: var(--text);
    cursor: pointer;
  }

  .step:active {
    background: var(--hover);
  }

  .who {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    text-align: center;
  }

  .tag {
    height: 22px;
    display: inline-flex;
    align-items: center;
    margin-bottom: 2px;
    padding: 0 9px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--align) 16%, transparent);
    color: var(--align);
    font-size: 11.5px;
    font-weight: 600;
  }

  .who b {
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 17px;
    font-weight: 600;
  }

  .who span:last-child {
    max-width: 100%;
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .body {
    flex: 1;
    min-height: 0;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px 12px calc(20px + env(safe-area-inset-bottom));
    overscroll-behavior: contain;
  }

  /* The body scrolls; its blocks keep their height instead of squeezing. */
  .body > :global(*) {
    flex: none;
  }

  .tgs {
    display: flex;
    gap: 6px;
  }

  .tog {
    flex: 1;
    height: 44px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 0 6px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: none;
    color: var(--muted);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
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

  .rol {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    margin: 2px 0;
    color: var(--faint);
    font-size: 13px;
  }

  .card {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 10px 12px 12px;
    border: 1px solid var(--line-strong);
    border-radius: 14px;
    background: var(--card);
  }

  .ch {
    height: 28px;
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .ch :global(svg) {
    color: var(--accent);
  }

  .seg {
    display: flex;
    gap: 2px;
    margin-bottom: 4px;
    padding: 3px;
    border: 1px solid var(--line);
    border-radius: 12px;
    background: var(--hover);
  }

  .seg button {
    flex: 1;
    height: 38px;
    border: 0;
    border-radius: 9px;
    background: none;
    color: var(--faint);
    font-size: 13.5px;
    font-weight: 500;
    cursor: pointer;
  }

  .seg button[aria-pressed='true'] {
    background: var(--card);
    color: var(--text);
    font-weight: 600;
    box-shadow: var(--sh-1);
  }

  .preset {
    margin: 0 0 4px;
    color: var(--muted);
    font-size: 13.5px;
  }

  .prow {
    height: 52px;
    display: flex;
    align-items: center;
    gap: 12px;
    border-top: 1px solid var(--line);
    font-size: 14px;
  }

  .prow .l {
    width: 70px;
    color: var(--muted);
  }

  .prow i {
    width: 30px;
    height: 19px;
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .prow .n {
    font-weight: 500;
  }

  .exit {
    height: 52px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    margin-top: 4px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: none;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
  }

  .exit :global(svg) {
    color: var(--err);
  }
</style>
