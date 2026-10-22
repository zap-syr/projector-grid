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
  import { details } from '../../state/details.svelte';
  import { device } from '../../state/device.svelte';
  import { selection } from '../../state/selection.svelte';
  import { view } from '../../state/view.svelte';
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
  /** Lens steps go without a dialog, so the heading says when some targets are out of sight. */
  const hiddenCount = $derived(view.hiddenSelected.length);
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
  /** Desktop: Lens setup (calibration, lens type) folds away, closed by default. */
  let setupOpen = $state(false);
  /** The app's four quick patterns beside *Off*. */
  const FAVOURITES = ['OTS:08', 'OTS:07', 'OTS:01', 'OTS:02'];
  /** Power, Shutter and OSD rows: green icon for what turns the picture on, red for off. */
  const STATE_ROWS = [
    {
      label: 'Power',
      on: act.power(true),
      onLabel: 'On',
      onIcon: 'power',
      off: act.power(false),
      offLabel: 'Standby',
      offIcon: 'moon',
    },
    {
      label: 'Shutter',
      on: act.shutter(true),
      onLabel: 'Open',
      onIcon: 'eye',
      off: act.shutter(false),
      offLabel: 'Close',
      offIcon: 'eyeOff',
    },
    {
      label: 'OSD',
      on: act.osd(true),
      onLabel: 'On',
      onIcon: 'osd',
      off: act.osd(false),
      offLabel: 'Off',
      offIcon: 'osdOff',
    },
  ] as const;
  const one = $derived(count === 1 ? selection.projectors[0] : undefined);
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
    disabled={false}
    onstep={step(axis, plus, s)}
  >
    <LensIcon {dir} speed={s} />
  </HoldButton>
{/snippet}

{#snippet lensSettings()}
  <button class="btn wide" disabled={false} onclick={() => send(act.lensHome())}>
    <Icon name="home" size={15} /> Home position
  </button>
  <OptionRow
    label="Lens calibration"
    showLabel
    options={config.lensCalibrations}
    disabled={false}
    onset={(code) => send(act.lensCalibration(code))}
  />
  <OptionRow
    label="Lens type"
    showLabel
    options={config.lensTypes}
    disabled={false}
    onset={(code) => send(act.lensType(code))}
  />
{/snippet}

<aside
  class="panel"
  class:sheet
  class:embedded
  class:touch={touchLens}
  aria-label={lensOnly ? 'Lens' : 'Control'}
>
  {#if !embedded}
    <header>
      <div class="ttl">
        {#if lensOnly}
          <h3 class="lens">Lens</h3>
          <small class="mono">{alignment.focused?.ip ?? ''}</small>
        {:else}
          <h3>Control</h3>
          {#if one}
            <small class="mono">{one.name} ({one.ip})</small>
          {:else if count > 1}
            <small>{count} selected{hiddenCount > 0 ? `, ${hiddenCount} hidden` : ''}</small>
          {:else}
            <small>No projectors selected</small>
          {/if}
        {/if}
      </div>
      {#if !sheet}
        <!-- Only with one projector selected; hidden, it keeps its place so ✕ never moves. -->
        <button
          class="x info"
          class:hid={!one || lensOnly}
          aria-label="Details of {one?.ip ?? ''}"
          title={touchLens ? undefined : 'Details'}
          tabindex={one && !lensOnly ? undefined : -1}
          onclick={() => {
            if (one)
              details.toggle(
                one.id,
                view.shown.map((p) => p.id),
              );
          }}
        >
          <Icon name="info" size={touchLens ? 22 : 18} />
        </button>
      {/if}
      <button
        class="x"
        aria-label={sheet ? 'Close' : 'Hide control panel'}
        title={touchLens ? undefined : sheet ? 'Close' : 'Hide'}
        onclick={onclose}
      >
        <Icon name="close" size={touchLens ? 24 : 15} />
      </button>
    </header>
  {/if}

  <div class="body" class:columns={columns && !lensOnly}>
    {#if lensOnly}
      {#if touchLens}{@render lens()}{:else}{@render deskLens()}{/if}
    {:else if columns}
      <div class="col">
        {@render basics()}
        {@render patterns()}
      </div>
      <div class="col">{@render lens()}</div>
    {:else if touchLens}
      {@render basics()}
      {@render lens()}
      {@render patterns()}
    {:else}
      {@render desk()}
    {/if}
  </div>
</aside>

{#snippet desk()}
  <div class="card rows">
    {#each STATE_ROWS as r (r.label)}
      <div class="srow">
        <span class="l">{r.label}</span>
        <button class="ab g" onclick={() => send(r.on)}
          ><Icon name={r.onIcon} size={18} />{r.onLabel}</button
        >
        <button class="ab r" onclick={() => send(r.off)}
          ><Icon name={r.offIcon} size={18} />{r.offLabel}</button
        >
      </div>
    {/each}
  </div>
  <div class="card">
    <div class="ch"><Icon name="input" size={16} />Input</div>
    <OptionRow label="Input" options={config.inputs} onset={(code) => send(act.input(code))} />
  </div>
  {@render deskLens()}
  <div class="card">
    <div class="ch"><Icon name="grid" size={16} />Test pattern</div>
    <div class="pats">
      <button
        class="pt off"
        class:cur={current === 'OTS:00'}
        onclick={() => send(act.testPattern('OTS:00'))}><Icon name="gridOff" size={18} />Off</button
      >
      {#each FAVOURITES as code (code)}
        <button
          class="pt"
          class:cur={current === code}
          aria-label={codeLabel(code)}
          title={codeLabel(code)}
          onclick={() => send(act.testPattern(code))}
          ><i style:background={patternSwatch(code) ?? 'var(--soft)'}></i></button
        >
      {/each}
    </div>
    <OptionRow
      label="Test pattern"
      action="Show"
      options={config.testPatterns.filter((t) => t.code !== 'OTS:00')}
      swatch={patternSwatch}
      onset={(code) => send(act.testPattern(code))}
    />
  </div>
{/snippet}

{#snippet deskLens()}
  <div class="card">
    <div class="ch">
      <Icon name="lens" size={16} />Lens shift
      {#if hiddenCount > 0}<span class="lhid">{count} projectors, {hiddenCount} hidden</span>{/if}
      <button
        class="hbtn"
        aria-label="Home position"
        title="Home position"
        onclick={() => send(act.lensHome())}><Icon name="home" size={16} /></button
      >
    </div>
    <!-- The app's cross: per direction slow, normal, fast from the centre out. -->
    <div class="xpad">
      {#each FAST_TO_SLOW as sp, i (sp)}
        <div class="lb" style:grid-area="{i + 1} / 4">
          {@render lensButton('up', 'shiftV', true, sp)}
        </div>
        <div class="lb" style:grid-area="4 / {i + 1}">
          {@render lensButton('left', 'shiftH', false, sp)}
        </div>
        <div class="lb" style:grid-area="4 / {7 - i}">
          {@render lensButton('right', 'shiftH', true, sp)}
        </div>
        <div class="lb" style:grid-area="{7 - i} / 4">
          {@render lensButton('down', 'shiftV', false, sp)}
        </div>
      {/each}
    </div>
    {#each axes as a (a.axis)}
      <div class="lr2">
        <span class="l">{a.label}</span>
        {#each FAST_TO_SLOW as sp (sp)}
          <div class="lb">{@render lensButton('left', a.axis, false, sp, a.minus)}</div>
        {/each}
        <span class="gp"></span>
        {#each SLOW_TO_FAST as sp (sp)}
          <div class="lb">{@render lensButton('right', a.axis, true, sp, a.plus)}</div>
        {/each}
      </div>
    {/each}
    <button class="disc" aria-expanded={setupOpen} onclick={() => (setupOpen = !setupOpen)}>
      <Icon name="tune" size={18} />Lens setup<span class="cv" class:open={setupOpen}
        ><Icon name="right" size={18} /></span
      >
    </button>
    {#if setupOpen}
      <div class="setup">
        <OptionRow
          label="Calibration"
          showLabel
          options={config.lensCalibrations}
          onset={(code) => send(act.lensCalibration(code))}
        />
        <OptionRow
          label="Lens type"
          showLabel
          options={config.lensTypes}
          onset={(code) => send(act.lensType(code))}
        />
      </div>
    {/if}
  </div>
{/snippet}

{#snippet basics()}
  <section>
    <h6>Power</h6>
    <div class="pair">
      <button class="btn" disabled={false} onclick={() => send(act.power(true))}>On</button>
      <button class="btn" disabled={false} onclick={() => send(act.power(false))}>Standby</button>
    </div>
  </section>

  <section>
    <h6>Shutter</h6>
    <div class="pair">
      <button class="btn" disabled={false} onclick={() => send(act.shutter(true))}>Open</button>
      <button class="btn" disabled={false} onclick={() => send(act.shutter(false))}>Close</button>
    </div>
  </section>

  <section>
    <h6>OSD</h6>
    <div class="pair">
      <button class="btn" disabled={false} onclick={() => send(act.osd(true))}>On</button>
      <button class="btn" disabled={false} onclick={() => send(act.osd(false))}>Off</button>
    </div>
  </section>

  <section>
    <h6>Input</h6>
    <OptionRow
      label="Input"
      options={config.inputs}
      disabled={false}
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
        <HoldButton label="Shift up" disabled={false} onstep={step('shiftV', true, speed)}
          ><Icon name="up" size={24} /></HoldButton
        >
        <span></span>
        <HoldButton label="Shift left" disabled={false} onstep={step('shiftH', false, speed)}
          ><Icon name="left" size={24} /></HoldButton
        >
        <span class="hub">SHIFT</span>
        <HoldButton label="Shift right" disabled={false} onstep={step('shiftH', true, speed)}
          ><Icon name="right" size={24} /></HoldButton
        >
        <span></span>
        <HoldButton label="Shift down" disabled={false} onstep={step('shiftV', false, speed)}
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
            disabled={false}
            onstep={step(a.axis, false, speed)}
            ><span class="bl"><Icon name="left" size={20} />{a.minus}</span></HoldButton
          >
          <HoldButton label="{a.label} {a.plus}" disabled={false} onstep={step(a.axis, true, speed)}
            ><span class="bl">{a.plus}<Icon name="right" size={20} /></span></HoldButton
          >
        </div>
      </section>
    {/each}
    <section>
      <h6>Lens settings</h6>
      {@render lensSettings()}
    </section>
  {/if}
{/snippet}

{#snippet patterns()}
  <section>
    <h6>Test pattern</h6>
    {#if device.phone}
      <!-- Phone: a full-width Off, then 74 px tiles with the name, four a row. -->
      <button
        class="tpoff"
        class:cur={current === 'OTS:00'}
        onclick={() => send(act.testPattern('OTS:00'))}><Icon name="gridOff" size={20} />Off</button
      >
      <div class="tpgrid">
        {#each showMore ? [...MAIN_PATTERNS, ...morePatterns] : MAIN_PATTERNS as code (code)}
          <button
            class="tp"
            class:cur={current === code}
            aria-label={codeLabel(code)}
            onclick={() => send(act.testPattern(code))}
          >
            <span class="img" style:background={patternSwatch(code) ?? 'var(--hover)'}></span>
            <span class="nm">{codeLabel(code)}</span>
          </button>
        {/each}
      </div>
      <button class="link" onclick={() => (showMore = !showMore)}>
        <Icon name={showMore ? 'up' : 'down'} size={18} />{showMore
          ? 'Fewer patterns'
          : 'More patterns'}
      </button>
    {:else}
      <!-- Tablets: the desktop layout at 44 px; the tile grid made the upright
           sheet's left column far taller than the lens (owner, 2026-10-21). -->
      <div class="pats touchpats">
        <button
          class="pt off"
          class:cur={current === 'OTS:00'}
          onclick={() => send(act.testPattern('OTS:00'))}
          ><Icon name="gridOff" size={20} />Off</button
        >
        {#each FAVOURITES as code (code)}
          <button
            class="pt"
            class:cur={current === code}
            aria-label={codeLabel(code)}
            onclick={() => send(act.testPattern(code))}
            ><i style:background={patternSwatch(code) ?? 'var(--soft)'}></i></button
          >
        {/each}
      </div>
      <OptionRow
        label="Test pattern"
        action="Show"
        options={config.testPatterns.filter((t) => t.code !== 'OTS:00')}
        swatch={patternSwatch}
        touch
        onset={(code) => send(act.testPattern(code))}
      />
    {/if}
  </section>
{/snippet}

<style>
  .panel {
    position: relative;
    z-index: 5;
    width: 344px;
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

  .x.info + .x {
    margin-left: -6px;
  }

  .x.hid {
    visibility: hidden;
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

  /* Touch: the Alerts panel's header, a 44 px close a finger can hit. */
  .touch header {
    padding: 8px 12px 8px 18px;
  }

  .touch h3 {
    font-size: 19px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }

  .touch .x {
    width: 44px;
    height: 44px;
    border-radius: 12px;
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

  /* ── Phone: test pattern tiles (board *Phone: test pattern…*) ─────────── */
  .tpoff {
    width: 100%;
    height: 52px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: none;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
  }

  .tpoff :global(svg) {
    color: var(--err);
  }

  .tpoff.cur {
    border-color: var(--accent);
    box-shadow: inset 0 0 0 1px var(--accent);
    color: var(--accent);
  }

  .tpgrid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 8px;
  }

  .tp {
    height: 74px;
    display: flex;
    flex-direction: column;
    gap: 5px;
    min-width: 0;
    padding: 6px 6px 0;
    border-radius: 12px;
    border: 1px solid var(--line-strong);
    background: none;
    font-size: 11.5px;
    font-weight: 500;
    color: var(--muted);
    cursor: pointer;
  }

  /* With one projector selected its pattern is framed in primary. */
  .tp.cur {
    border-color: var(--accent);
    box-shadow: inset 0 0 0 1px var(--accent);
    background: color-mix(in srgb, var(--accent) 8%, transparent);
    color: var(--accent);
    font-weight: 600;
  }

  .tp .img {
    height: 36px;
    flex: none;
    border-radius: 6px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .tp .nm {
    overflow: hidden;
    text-align: center;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .link {
    align-self: flex-start;
    height: 44px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 0 4px;
    border: 0;
    background: none;
    color: var(--accent);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }

  /* Tablets: the desktop's Off + four swatches, at 44 px. */
  .touchpats .pt {
    width: 56px;
    height: 44px;
    border-radius: 12px;
  }

  .touchpats .pt.off {
    width: auto;
    font-size: 15px;
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

  .lhid {
    margin-left: 8px;
    color: var(--muted);
    font-weight: 600;
    text-transform: none;
    letter-spacing: 0;
  }

  /* ── Desktop: the app's control bar (cards, 36 px controls) ─────────── */
  .panel:not(.touch):not(.sheet) {
    width: 344px;
    background: var(--app);
  }

  .ttl {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
  }

  .ttl small {
    color: var(--muted);
    font-size: 12.5px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ttl small.mono {
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 12px;
  }

  .panel:not(.touch) header {
    height: 60px;
    padding: 0 8px 0 16px;
    border-bottom: 0;
  }

  .panel:not(.touch) .body {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 0 12px 12px;
  }

  .card {
    flex: none;
    padding: 10px 12px 12px;
    border: 1px solid var(--line-strong);
    border-radius: 14px;
    background: var(--card);
  }

  .card.rows {
    padding-top: 2px;
    padding-bottom: 2px;
  }

  .ch {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 28px;
    margin-bottom: 8px;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .ch > :global(svg) {
    color: var(--accent);
  }

  .srow {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 50px;
  }

  .srow + .srow {
    border-top: 1px solid var(--line);
  }

  .srow .l {
    width: 62px;
    flex: none;
    color: var(--muted);
    font-size: 13.5px;
  }

  .ab {
    flex: 1;
    height: 36px;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px;
    border: 1px solid var(--line-strong);
    border-radius: 10px;
    background: none;
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
    cursor: pointer;
  }

  .ab:hover,
  .pt:hover,
  .hbtn:hover,
  .disc:hover {
    background: var(--hover);
  }

  .ab.g :global(svg) {
    color: var(--ok);
  }

  .ab.r :global(svg) {
    color: var(--err);
  }

  .pats {
    display: flex;
    gap: 6px;
    margin-bottom: 8px;
  }

  .pt {
    width: 46px;
    height: 40px;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 10px;
    background: none;
    cursor: pointer;
  }

  .pt i {
    width: 24px;
    height: 15px;
    border-radius: 2px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .pt.off {
    flex: 1;
    width: auto;
    gap: 6px;
    font-size: 13px;
    font-weight: 600;
  }

  .pt.off :global(svg) {
    color: var(--err);
  }

  .pt.cur {
    border: 2px solid var(--accent);
  }

  .hbtn {
    margin-left: auto;
    width: 30px;
    height: 30px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 50%;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .xpad {
    display: grid;
    grid-template-columns: repeat(7, 34px);
    grid-template-rows: repeat(7, 34px);
    gap: 5px 3px;
    justify-content: center;
    margin: 6px 0 16px;
  }

  .xpad .lb {
    width: 34px;
    height: 34px;
  }

  .lr2 .lb {
    width: 36px;
    height: 36px;
  }

  .xpad .lb :global(button),
  .lr2 .lb :global(button) {
    border-radius: 50%;
    background: none;
  }

  .lr2 {
    display: flex;
    align-items: center;
    gap: 4px;
    height: 54px;
    border-top: 1px solid var(--line);
  }

  .lr2 .l {
    width: 46px;
    flex: none;
    color: var(--muted);
    font-size: 13.5px;
  }

  .lr2 .gp {
    flex: 1;
  }

  .disc {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 8px;
    height: 40px;
    padding: 0 2px;
    border: 0;
    border-top: 1px solid var(--line);
    background: none;
    color: var(--muted);
    font-size: 13.5px;
    text-align: left;
    cursor: pointer;
  }

  .disc > :global(svg) {
    color: var(--accent);
  }

  .disc .cv {
    margin-left: auto;
    display: flex;
    color: var(--faint);
    transition: transform 0.15s;
  }

  .disc .cv.open {
    transform: rotate(90deg);
  }

  .setup {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-top: 6px;
  }
</style>
