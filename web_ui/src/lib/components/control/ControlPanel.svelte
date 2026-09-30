<!--
  Operator control panel, in the app's control-bar order: Power, Shutter, OSD,
  Input, Lens, Test pattern. Acts on the selection; disabled while nothing is
  selected. A side panel on desktop, the content of a bottom sheet on a phone.
-->
<script lang="ts">
  import type { Action, Config, LensAxis } from '../../api/types';
  import { act, type LensSpeed } from '../../logic/actions';
  import { testPatternLabel } from '../../logic/cells';
  import { MAIN_PATTERNS, patternSwatch } from '../../logic/patterns';
  import { alignment } from '../../state/alignment.svelte';
  import { control } from '../../state/control.svelte';
  import { device } from '../../state/device.svelte';
  import { selection } from '../../state/selection.svelte';
  import Icon from '../Icon.svelte';
  import HoldButton from './HoldButton.svelte';
  import LensIcon, { type LensDirection } from './LensIcon.svelte';
  import OptionRow from './OptionRow.svelte';

  let {
    config,
    sheet = false,
    columns = false,
    embedded = false,
    onclose,
  }: {
    config: Config;
    sheet?: boolean;
    /** A tablet's bottom sheet: the lens in a second column. */
    columns?: boolean;
    /** Inside the phone's Alignment screen: no header of its own. */
    embedded?: boolean;
    onclose: () => void;
  } = $props();

  /** Alignment mode: the mode owns shutters and patterns, so only the lens is left, on the focused projector. */
  const lensOnly = $derived(alignment.active);

  /** Touch screens get the big lens block; the app's 40 px buttons need a mouse. */
  const touchLens = $derived(device.phone || device.touch);

  const count = $derived(selection.projectors.length);
  const none = $derived(count === 0);
  const patternLabels = $derived(new Map(config.testPatterns.map((t) => [t.code, t.label])));
  /** Any code from the config lists → its label, for confirm titles. */
  const codeLabels = $derived(
    new Map(
      [...config.inputs, ...config.lensCalibrations, ...config.lensTypes].map((o) => [
        o.code,
        o.label,
      ]),
    ),
  );
  const codeLabel = (code: string) => codeLabels.get(code) ?? testPatternLabel(code, patternLabels);
  const morePatterns = $derived(
    config.testPatterns.map((t) => t.code).filter((c) => !MAIN_PATTERNS.includes(c)),
  );
  // With one projector selected its pattern is highlighted.
  const current = $derived(count === 1 ? (selection.projectors[0]?.testPattern ?? null) : null);

  let showMore = $state(false);
  /** Touch lens block only: the mouse layout has a button per speed, like the app. */
  let speed = $state<LensSpeed>('normal');
  const speeds: LensSpeed[] = ['slow', 'normal', 'fast'];
  const FAST_TO_SLOW: LensSpeed[] = ['fast', 'normal', 'slow'];
  const SLOW_TO_FAST: LensSpeed[] = ['slow', 'normal', 'fast'];
  const cap = (s: string) => s[0]?.toUpperCase() + s.slice(1);
  const axes = [
    { axis: 'focus', label: 'Focus', minus: 'Near', plus: 'Far' },
    { axis: 'zoom', label: 'Zoom', minus: 'Out', plus: 'In' },
  ] as const;
  const dirNames = { up: 'up', down: 'down', left: 'left', right: 'right' } as const;

  const send = (a: Action) => control.request(a, codeLabel);
  const step = (axis: LensAxis, plus: boolean, s: LensSpeed) => () =>
    send(act.lensStep(axis, plus, s));
</script>

{#snippet lensButton(
  dir: LensDirection,
  axis: LensAxis,
  plus: boolean,
  s: LensSpeed,
  name: string = dirNames[dir],
)}
  <HoldButton
    label="{axis === 'shiftH' || axis === 'shiftV' ? 'Shift' : cap(axis)} {name}, {s}"
    disabled={none}
    onstep={step(axis, plus, s)}
  >
    <LensIcon {dir} speed={s} />
  </HoldButton>
{/snippet}

{#snippet lensSettings()}
  <button class="btn wide" disabled={none} onclick={() => send(act.lensHome())}>
    <Icon name="home" size={15} /> Home position
  </button>
  <OptionRow
    label="Lens calibration"
    showLabel
    options={config.lensCalibrations}
    disabled={none}
    onset={(code) => send(act.lensCalibration(code))}
  />
  <OptionRow
    label="Lens type"
    showLabel
    options={config.lensTypes}
    disabled={none}
    onset={(code) => send(act.lensType(code))}
  />
{/snippet}

<aside class="panel" class:sheet class:embedded aria-label={lensOnly ? 'Lens' : 'Control'}>
  {#if !embedded}
    <header>
      <!-- The toolbar's bulk selector shows the count. -->
      {#if lensOnly}
        <h3 class="lens">Lens · {alignment.focused?.ip ?? '—'}</h3>
      {:else}
        <h3>Control</h3>
      {/if}
      <button
        class="x"
        aria-label={sheet ? 'Close' : 'Hide control panel'}
        title={sheet ? 'Close' : 'Hide'}
        onclick={onclose}
      >
        <Icon name="close" size={15} />
      </button>
    </header>
  {/if}

  <div class="body" class:columns={columns && !lensOnly}>
    {#if lensOnly}
      {@render lens()}
    {:else if columns}
      <div class="col">
        {@render basics()}
        {@render patterns()}
      </div>
      <div class="col">{@render lens()}</div>
    {:else}
      {@render basics()}
      {@render lens()}
      {@render patterns()}
    {/if}
  </div>
</aside>

{#snippet basics()}
  <section>
    <h6>Power</h6>
    <div class="pair">
      <button class="btn" disabled={none} onclick={() => send(act.power(true))}>On</button>
      <button class="btn" disabled={none} onclick={() => send(act.power(false))}>Standby</button>
    </div>
  </section>

  <section>
    <h6>Shutter</h6>
    <div class="pair">
      <button class="btn" disabled={none} onclick={() => send(act.shutter(true))}>Open</button>
      <button class="btn" disabled={none} onclick={() => send(act.shutter(false))}>Close</button>
    </div>
  </section>

  <section>
    <h6>OSD</h6>
    <div class="pair">
      <button class="btn" disabled={none} onclick={() => send(act.osd(true))}>On</button>
      <button class="btn" disabled={none} onclick={() => send(act.osd(false))}>Off</button>
    </div>
  </section>

  <section>
    <h6>Input</h6>
    <OptionRow
      label="Input"
      options={config.inputs}
      disabled={none}
      onset={(code) => send(act.input(code))}
    />
  </section>
{/snippet}

{#snippet lens()}
  {#if touchLens}
    <!-- Touch: one speed switch and big single-step buttons, well apart, so
           a finger can't hit Focus for Zoom. The rarely used settings go last. -->
    <section>
      <h6>Lens</h6>
      <div class="seg" role="group" aria-label="Lens speed">
        {#each speeds as s (s)}
          <button aria-pressed={speed === s} onclick={() => (speed = s)}>{cap(s)}</button>
        {/each}
      </div>
      <div class="dpad">
        <span></span>
        <HoldButton label="Shift up" disabled={none} onstep={step('shiftV', true, speed)}
          ><Icon name="up" size={24} /></HoldButton
        >
        <span></span>
        <HoldButton label="Shift left" disabled={none} onstep={step('shiftH', false, speed)}
          ><Icon name="left" size={24} /></HoldButton
        >
        <span class="hub">SHIFT</span>
        <HoldButton label="Shift right" disabled={none} onstep={step('shiftH', true, speed)}
          ><Icon name="right" size={24} /></HoldButton
        >
        <span></span>
        <HoldButton label="Shift down" disabled={none} onstep={step('shiftV', false, speed)}
          ><Icon name="down" size={24} /></HoldButton
        >
        <span></span>
      </div>
    </section>
    {#each axes as a (a.axis)}
      <section>
        <h6>{a.label}</h6>
        <div class="big">
          <HoldButton
            label="{a.label} {a.minus}"
            disabled={none}
            onstep={step(a.axis, false, speed)}
            ><span class="bl"><Icon name="left" size={20} />{a.minus}</span></HoldButton
          >
          <HoldButton label="{a.label} {a.plus}" disabled={none} onstep={step(a.axis, true, speed)}
            ><span class="bl">{a.plus}<Icon name="right" size={20} /></span></HoldButton
          >
        </div>
      </section>
    {/each}
    <section>
      <h6>Lens settings</h6>
      {@render lensSettings()}
    </section>
  {:else}
    <!-- Desktop: the app's control bar — each arrow has fast / normal / slow. -->
    <section>
      <h6>Lens shift</h6>
      <div class="shift">
        {#each FAST_TO_SLOW as s (s)}
          <div class="lb">{@render lensButton('up', 'shiftV', true, s)}</div>
        {/each}
        <div class="shiftrow">
          {#each FAST_TO_SLOW as s (s)}
            <div class="lb">{@render lensButton('left', 'shiftH', false, s)}</div>
          {/each}
          <span class="gap"></span>
          {#each SLOW_TO_FAST as s (s)}
            <div class="lb">{@render lensButton('right', 'shiftH', true, s)}</div>
          {/each}
        </div>
        {#each SLOW_TO_FAST as s (s)}
          <div class="lb">{@render lensButton('down', 'shiftV', false, s)}</div>
        {/each}
      </div>
      {@render lensSettings()}
    </section>

    {#each axes as a (a.axis)}
      <section>
        <h6>{a.label}</h6>
        <div class="linear">
          {#each FAST_TO_SLOW as s (s)}
            <div class="lb">{@render lensButton('left', a.axis, false, s, a.minus)}</div>
          {/each}
          <span class="spacer"></span>
          {#each SLOW_TO_FAST as s (s)}
            <div class="lb">{@render lensButton('right', a.axis, true, s, a.plus)}</div>
          {/each}
        </div>
      </section>
    {/each}
  {/if}
{/snippet}

{#snippet patterns()}
  <section>
    <h6>Test pattern</h6>
    <button
      class="btn wide"
      class:cur={current === 'OTS:00'}
      disabled={none}
      onclick={() => send(act.testPattern('OTS:00'))}>Off</button
    >
    <div class="tpgrid">
      {#each showMore ? [...MAIN_PATTERNS, ...morePatterns] : MAIN_PATTERNS as code (code)}
        <button
          class="tp"
          class:cur={current === code}
          disabled={none}
          title={codeLabel(code)}
          onclick={() => send(act.testPattern(code))}
        >
          <span class="img" style:background={patternSwatch(code) ?? 'var(--hover)'}></span>
          <span class="nm">{codeLabel(code)}</span>
        </button>
      {/each}
    </div>
    <button class="link" onclick={() => (showMore = !showMore)}>
      {showMore ? 'Fewer patterns' : 'More patterns'}
    </button>
  </section>
{/snippet}

<style>
  .panel {
    position: relative;
    z-index: 5;
    width: 340px;
    min-height: 0;
    display: flex;
    flex-direction: column;
    background: var(--surface);
    border-left: 1px solid var(--line);
  }

  .panel.sheet {
    width: 100%;
    flex: 1;
    border-left: 0;
    background: none;
  }

  .sheet header {
    border-bottom: 0;
    padding-top: 0;
  }

  .panel.embedded {
    width: 100%;
    border-left: 0;
    background: none;
  }

  .embedded .body {
    overflow: visible;
    padding: 0;
  }

  h3.lens {
    color: var(--align);
  }

  header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 10px 10px 18px;
    border-bottom: 1px solid var(--line);
  }

  h3 {
    margin: 0;
    font-size: 15px;
    font-weight: 650;
  }

  .x {
    margin-left: auto;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: var(--r-sm);
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .x:hover {
    background: var(--hover);
    color: var(--text);
  }

  .body {
    flex: 1;
    overflow: auto;
    padding: 4px 18px 18px;
  }

  section {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 14px 0 4px;
  }

  /* Block titles like the app's control bar: accent, bold, with a rule. */
  h6 {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0;
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--accent);
  }

  h6::after {
    content: '';
    flex: 1;
    height: 1px;
    background: color-mix(in srgb, var(--accent) 40%, transparent);
  }

  /* Desktop lens buttons: the app's 40 px outlined icon buttons. */
  .lb {
    width: 40px;
    height: 40px;
    flex: none;
  }

  .shift {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }

  .shiftrow {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .shiftrow .gap {
    width: 26px;
  }

  .linear {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .linear .spacer {
    flex: 1;
  }

  .pair {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    height: 34px;
    padding: 0 12px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--surface);
    font-size: 13.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--hover);
  }

  .btn:disabled,
  .tp:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .btn.cur {
    border-color: var(--accent);
    color: var(--accent);
    box-shadow: 0 0 0 1px var(--accent);
  }

  .tpgrid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 6px;
  }

  .tp {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
    padding: 5px;
    border-radius: 8px;
    border: 1px solid var(--line);
    background: var(--surface);
    font-size: 10.5px;
    font-weight: 550;
    color: var(--muted);
    cursor: pointer;
  }

  .tp:hover {
    border-color: var(--accent-line);
  }

  .tp.cur {
    border-color: var(--accent);
    color: var(--accent);
    box-shadow: 0 0 0 1px var(--accent);
  }

  .tp .img {
    height: 28px;
    border-radius: 4px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .tp .nm {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .link {
    align-self: flex-start;
    padding: 0;
    border: 0;
    background: none;
    color: var(--accent);
    font-size: 12.5px;
    font-weight: 550;
    cursor: pointer;
  }

  .seg {
    display: grid;
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: 2px;
    padding: 3px;
    border-radius: 8px;
    background: var(--hover);
  }

  .seg button {
    height: 38px;
    border: 0;
    border-radius: 6px;
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

  /* Touch lens block: 64 px arrows 10 px apart, an inert centre. */
  .dpad {
    align-self: center;
    display: grid;
    grid-template-columns: repeat(3, 64px);
    grid-template-rows: repeat(3, 64px);
    gap: 10px;
    margin-top: 4px;
  }

  .hub {
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px dashed var(--line-strong);
    border-radius: 9px;
    color: var(--faint);
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.04em;
  }

  .big {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    height: 56px;
  }

  .bl {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 15px;
    font-weight: 600;
  }

  /* Tablet bottom sheet: the lens beside the rest. */
  .body.columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
    gap: 0 28px;
  }

  .col {
    min-width: 0;
  }
</style>
