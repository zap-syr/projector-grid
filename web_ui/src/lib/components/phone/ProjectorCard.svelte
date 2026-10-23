<!--
  One projector card (WEB_UI_PLAN step 14, *Projector card* boards), in two
  sizes with different content. Both: a header (checkbox, status dot, IP,
  model, the active test pattern, ⓘ) and a status footer with the
  projector's verdict, always there so every card has one height.
  Extended: power and shutter chips, then Input | Signal, Intake | Exhaust
  with bars against the threshold, Runtime | AC, each under its label.
  Compact: two rows of three without labels (power / input, shutter /
  signal, In / Ex), names in tooltips. The whole card answers a click: the
  operator's tap selects it and ⓘ opens the details; the viewer's tap opens
  them.
-->
<script lang="ts">
  import type { AlignmentRole, Config, Projector } from '../../api/types';
  import { cardStatus } from '../../logic/cardStatus';
  import { powerLabel, shutterLabel, withUnit } from '../../logic/labels';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import { isSelectable } from '../../logic/selection';
  import { alerts } from '../../state/alerts.svelte';
  import type { CardSize } from '../../state/cardSize.svelte';
  import { device } from '../../state/device.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';
  import SignalPill from '../status/SignalPill.svelte';
  import StatusDot from '../status/StatusDot.svelte';
  import TemperatureBar from '../status/TemperatureBar.svelte';
  import TemperatureText from '../status/TemperatureText.svelte';

  let {
    p,
    size,
    thresholds,
    patternLabel,
    operator,
    selected,
    open,
    onselect,
    ondetails,
    role = null,
    outside = false,
    onfocus,
  }: {
    p: Projector;
    size: CardSize;
    thresholds: Config['thresholds'];
    patternLabel: (code: string) => string;
    operator: boolean;
    selected: boolean;
    /** Its details are open. */
    open: boolean;
    onselect: () => void;
    ondetails: () => void;
    /** Alignment mode: the card's ring or the closed scrim, as in the app. */
    role?: AlignmentRole | null;
    /** Alignment mode is on but this projector isn't in it. */
    outside?: boolean;
    /** Alignment mode: the operator's tap focuses this projector. */
    onfocus?: () => void;
  } = $props();

  const aligning = $derived(role !== null || outside);
  const selectable = $derived(aligning ? role !== null : isSelectable(p));
  /** Operator outside Alignment mode: the checkbox and ⓘ. */
  const tools = $derived(operator && !aligning);
  const offline = $derived(p.connection === 'offline');
  /** Nothing read yet behind a wrong login: every value is *Unknown*. */
  const unknown = $derived(p.connection === 'unauthorized');
  const status = $derived(cardStatus(p, alerts.now));
  const pattern = $derived(
    !offline && !unknown && isPatternActive(p.testPattern) && p.testPattern ? p.testPattern : null,
  );

  /** Offline the last readings stay, in grey; a wrong login knows nothing. */
  const powerTone = $derived(
    offline || unknown ? 'faint' : p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn',
  );
  const shutterTone = $derived(
    offline || unknown || p.power === 'standby' ? 'faint' : p.shutter === 'open' ? 'ok' : 'err',
  );
  const powerText = $derived(unknown ? 'Unknown' : powerLabel(p.power));
  const shutterText = $derived(unknown ? 'Unknown' : shutterLabel(p.shutter));
  const shutterIcon = $derived(p.shutter === 'open' || unknown ? 'eye' : 'eyeOff');
  const value = (display: string) => (unknown ? 'Unknown' : withUnit(display));

  /** No details in Alignment mode: the Control's place belongs to the lens. */
  function primary() {
    if (aligning) {
      if (operator && role) onfocus?.();
    } else if (!operator) ondetails();
    else if (selectable) onselect();
  }
</script>

<article
  class="card {size} {role ?? ''}"
  class:touch={device.touch}
  class:sel={operator && selected && !aligning}
  class:open
  class:tools
  class:outside
  class:warn={status.tone === 'warning'}
  class:err={status.tone === 'error'}
  class:offline
>
  <button
    class="main"
    disabled={operator && !selectable}
    aria-label="{p.ip}, {p.name}, {status.text}"
    aria-pressed={operator
      ? aligning
        ? role === 'focused'
        : selected
      : aligning
        ? undefined
        : open}
    onclick={primary}
  >
    <!-- The checkbox and ⓘ lie over the header's gaps (.over), so the card
         stays one button. Safari doesn't stretch a button's own flex
         children, so the layout lives in .inner. -->
    <span class="inner">
      <span class="hd">
        {#if tools}<span class="cbgap"></span>{/if}
        <span class="id">
          <span class="ipl"
            ><StatusDot connection={p.connection} /><span class="ip">{p.ip}</span></span
          >
          <span class="md">{p.name}</span>
        </span>
        {#if pattern}
          <span
            class="tp"
            role="img"
            aria-label="Test pattern: {patternLabel(pattern)}"
            title="Test pattern: {patternLabel(pattern)}"
            style:background={patternSwatch(pattern) ?? 'var(--hover)'}
          ></span>
        {/if}
        {#if tools}<span class="ibgap"></span>{/if}
      </span>

      {#if size === 'extended'}
        <span class="body">
          <span class="chips">
            <span class="chip" style:--c="var(--{powerTone})" title="Power"
              ><Icon name="power" size={device.touch ? 17 : 15} />{powerText}</span
            >
            <span class="chip" style:--c="var(--{shutterTone})" title="Shutter"
              ><Icon name={shutterIcon} size={device.touch ? 17 : 15} />{shutterText}</span
            >
          </span>
          <span class="rw">
            <span class="cell"
              ><span class="lab">Input</span><span class="val" class:unk={unknown}
                >{unknown ? 'Unknown' : p.input}</span
              ></span
            >
            <span class="cell"
              ><span class="lab">Signal</span><span class="val"><SignalPill {p} /></span></span
            >
          </span>
          <span class="rw">
            {@render temperature('Intake', p.intakeTemp, thresholds.intake, p.status.intake)}
            {@render temperature('Exhaust', p.exhaustTemp, thresholds.exhaust, p.status.exhaust)}
          </span>
          <span class="rw">
            <span class="cell"
              ><span class="lab">Runtime</span><span class="val num" class:unk={unknown}
                >{value(p.runtime)}</span
              ></span
            >
            <span class="cell"
              ><span class="lab">AC</span><span class="val num" class:unk={unknown}
                >{value(p.acVoltage)}</span
              ></span
            >
          </span>
        </span>
      {:else}
        <span class="body grid">
          <span class="cv" style:--c="var(--{powerTone})" title="Power"
            ><Icon name="power" size={device.touch ? 17 : 16} /><span class="t">{powerText}</span
            ></span
          >
          <span class="cv" style:--c="var(--{shutterTone})" title="Shutter"
            ><Icon name={shutterIcon} size={device.touch ? 17 : 16} /><span class="t"
              >{shutterText}</span
            ></span
          >
          <span class="cv num" title="Intake temperature"
            ><u>In</u><span class="t" class:unk={unknown}
              >{#if unknown}Unknown{:else}<TemperatureText
                  display={p.intakeTemp}
                  level={p.status.intake ?? null}
                />{/if}</span
            ></span
          >
          <span class="cv" title="Input"
            ><span class="gi"><Icon name="input" size={device.touch ? 17 : 16} /></span><span
              class="t"
              class:unk={unknown}>{unknown ? 'Unknown' : p.input}</span
            ></span
          >
          <span class="cv" title="Signal"><SignalPill {p} /></span>
          <span class="cv num" title="Exhaust temperature"
            ><u>Ex</u><span class="t" class:unk={unknown}
              >{#if unknown}Unknown{:else}<TemperatureText
                  display={p.exhaustTemp}
                  level={p.status.exhaust ?? null}
                />{/if}</span
            ></span
          >
        </span>
      {/if}

      <span class="ft {status.tone}"
        ><Icon name={status.icon} size={16} /><span>{status.text}</span></span
      >
    </span>
  </button>

  {#if tools}
    <div class="over">
      <span class="cbw">
        <Checkbox
          state={selected}
          label="Select {p.ip}"
          disabled={!selectable}
          onclick={onselect}
        />
      </span>
      <span class="grow"></span>
      <!-- The operator's way to the details (a tap selects); a viewer's tap opens them. -->
      <button
        class="info"
        class:on={open}
        aria-pressed={open}
        aria-label="Details of {p.ip}"
        title={device.touch ? undefined : 'Details'}
        onclick={ondetails}
      >
        <Icon name="info" size={device.touch ? 22 : 18} />
      </button>
    </div>
  {/if}
</article>

{#snippet temperature(
  label: string,
  display: string,
  threshold: Config['thresholds']['intake'],
  level: Projector['status']['intake'],
)}
  <span class="cell">
    <span class="lab">{label}</span>
    <span class="val num" class:unk={unknown}
      >{#if unknown}Unknown{:else}<TemperatureText {display} level={level ?? null} />{/if}</span
    >
    <span class="bar"><TemperatureBar display={unknown ? '-' : display} {threshold} mark /></span>
  </span>
{/snippet}

<style>
  /* Fixed heights per size and pointer, so a change of value moves nothing. */
  .card {
    --pad: 14px;
    position: relative;
    flex: none;
    display: flex;
    flex-direction: column;
    height: 320px;
    overflow: hidden;
    background: var(--card);
    border: 1px solid var(--line-strong);
    border-radius: 14px;
  }

  .card.touch {
    --pad: 16px;
    height: 352px;
  }

  .card.compact {
    height: 146px;
  }

  .card.compact.touch {
    height: 160px;
  }

  /* A problem tints the outline like its footer: amber or red. */
  .card.warn {
    border-color: color-mix(in srgb, var(--warn) 55%, transparent);
  }

  .card.err {
    border-color: color-mix(in srgb, var(--err) 60%, transparent);
  }

  /* Offline: a dashed outline on the window, the last readings dimmed. */
  .card.offline {
    border-style: dashed;
    background: transparent;
  }

  .card.offline .ip {
    color: var(--faint);
  }

  .card.offline .body {
    opacity: 0.55;
  }

  /* Selected: 2 px primary outline (the inset ring keeps the size) and a tint. */
  .card.sel {
    border-color: var(--accent);
    box-shadow: inset 0 0 0 1px var(--accent);
    background: color-mix(in srgb, var(--accent) 8%, var(--card));
  }

  /* Its details are open: a brighter fill, selected or not. */
  .card.open {
    background: color-mix(in srgb, var(--accent) 16%, var(--card));
  }

  /* Alignment rings with a 2 px gap, like the app's canvas card. */
  .card.focused {
    border-color: var(--align);
    box-shadow:
      0 0 0 2px var(--app),
      0 0 0 5px var(--align),
      0 0 14px 5px color-mix(in srgb, var(--align) 45%, transparent);
  }

  .card.shown {
    box-shadow:
      0 0 0 2px var(--app),
      0 0 0 4px var(--align-2);
  }

  .card.closed,
  .card.outside {
    opacity: 0.5;
  }

  .card.outside {
    border-style: dashed;
  }

  .main {
    flex: 1;
    min-height: 0;
    width: 100%;
    display: flex;
    padding: 0;
    border: 0;
    background: none;
    text-align: left;
    cursor: pointer;
  }

  .inner {
    flex: 1;
    width: 100%;
    height: 100%;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .main:disabled {
    cursor: default;
  }

  /* Header: Extended stacks the IP over the model, Compact puts them in a row. */
  .hd,
  .over {
    height: 58px;
    flex: none;
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 12px 8px 0 var(--pad);
  }

  .card:not(.tools) .hd {
    padding-right: var(--pad);
  }

  .touch .hd,
  .touch .over {
    height: 62px;
    padding-right: 4px;
  }

  .compact .hd,
  .compact .over {
    height: 44px;
    align-items: center;
    padding-top: 0;
    padding-right: 6px;
  }

  .compact.touch .hd,
  .compact.touch .over {
    height: 50px;
    gap: 12px;
    padding-right: 4px;
  }

  .over {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    pointer-events: none;
  }

  .over > * {
    pointer-events: auto;
  }

  .over .grow {
    flex: 1;
    pointer-events: none;
  }

  .cbgap,
  .cbw {
    width: 16px;
    flex: none;
    display: flex;
    justify-content: center;
  }

  .cbw {
    margin-top: 3px;
  }

  .compact .cbw {
    margin-top: 0;
  }

  .touch .cbgap,
  .touch .cbw {
    width: 22px;
    margin-top: 0;
  }

  /* The touch box: 22 px, as the boards draw it. */
  .touch .cbw :global(.cb) {
    width: 22px;
    height: 22px;
    border-width: 2px;
    border-radius: 6px;
  }

  .touch .cbw :global(.cb.all::after) {
    width: 11px;
    height: 6px;
    border-left-width: 2.5px;
    border-bottom-width: 2.5px;
  }

  .touch .cbw :global(.cb.some::after) {
    width: 11px;
    height: 2.5px;
  }

  .ibgap {
    width: 32px;
    flex: none;
  }

  .touch .ibgap {
    width: 44px;
  }

  .id {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .compact .id {
    flex-direction: row;
    align-items: center;
    gap: 8px;
  }

  .ipl {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 22px;
    flex: none;
  }

  .ip {
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 15px;
    font-weight: 600;
    white-space: nowrap;
  }

  .compact.touch .ip {
    font-size: 15.5px;
  }

  .md {
    margin-left: 16px;
    overflow: hidden;
    color: var(--faint);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .compact .md {
    min-width: 0;
    margin-left: 0;
  }

  .compact.touch .md {
    font-size: 13px;
  }

  /* Test-pattern thumbnail before ⓘ, framed so white and black fields show. */
  .tp {
    width: 24px;
    height: 15px;
    flex: none;
    margin: 4px 4px 0 0;
    border-radius: 2px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  .touch .tp {
    width: 26px;
    height: 16px;
    margin: 3px 2px 0 0;
  }

  .compact .tp {
    margin: 0;
  }

  /* ⓘ: 32 px with a mouse, 44 px for a finger. */
  .info {
    width: 32px;
    height: 32px;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: -4px;
    padding: 0;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .touch .info {
    width: 44px;
    height: 44px;
    margin-top: -10px;
    border-radius: 10px;
  }

  .compact .info {
    margin-top: 0;
  }

  @media (hover: hover) {
    .info:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  .info.on,
  .info.on:hover {
    background: var(--pc);
    color: var(--on-pc);
  }

  .body {
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  /* Extended: power and shutter as chips, no labels. */
  .chips {
    display: flex;
    gap: 6px;
    padding: 0 var(--pad) 10px;
  }

  .touch .chips {
    padding-bottom: 12px;
  }

  .chip {
    height: 26px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    padding: 0 10px 0 8px;
    border-radius: 8px;
    background: var(--soft);
    color: var(--c);
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
  }

  .touch .chip {
    height: 30px;
    padding: 0 12px 0 10px;
    font-size: 14px;
  }

  /* Label over value, two columns, rows split by hairlines. */
  .rw {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    column-gap: 14px;
    margin: 0 var(--pad);
    padding: 9px 0;
    border-top: 1px solid var(--line);
  }

  .touch .rw {
    padding: 10px 0;
  }

  .cell {
    display: flex;
    flex-direction: column;
    gap: 3px;
    min-width: 0;
  }

  .lab {
    color: var(--faint);
    font-size: 11.5px;
    font-weight: 500;
    line-height: 16px;
  }

  .touch .lab {
    font-size: 12px;
    line-height: 17px;
  }

  .val {
    height: 22px;
    display: flex;
    align-items: center;
    min-width: 0;
    overflow: hidden;
    font-size: 14px;
    font-weight: 600;
    white-space: nowrap;
  }

  .touch .val {
    height: 24px;
    font-size: 15px;
  }

  .num {
    font-variant-numeric: tabular-nums;
  }

  .unk {
    color: var(--faint);
  }

  .bar {
    display: flex;
    margin-top: 1px;
  }

  /* Compact: two rows of three, related values in one column. */
  .grid {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.25fr) 80px;
    gap: 6px 12px;
    margin: 0 var(--pad);
    padding: 8px 0 9px;
    border-top: 1px solid var(--line);
  }

  .touch .grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.25fr) 84px;
    padding: 9px 0 10px;
  }

  .cv {
    height: 22px;
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    overflow: hidden;
    color: var(--c, var(--text));
    font-size: 14px;
    font-weight: 600;
    white-space: nowrap;
  }

  .touch .cv {
    height: 24px;
    font-size: 14.5px;
  }

  .cv .t {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .cv u {
    width: 18px;
    flex: none;
    color: var(--faint);
    font-size: 11.5px;
    font-weight: 500;
    text-decoration: none;
  }

  .touch .cv u {
    font-size: 12px;
  }

  .gi {
    display: flex;
    color: var(--faint);
  }

  /* The verdict: grey when fine, amber or red on its soft fill. */
  .ft {
    height: 36px;
    flex: none;
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: auto;
    padding: 0 var(--pad);
    overflow: hidden;
    border-top: 1px solid var(--line);
    color: var(--faint);
    font-size: 12.5px;
    font-weight: 500;
    white-space: nowrap;
  }

  .ft span {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .touch .ft {
    height: 42px;
    font-size: 13.5px;
  }

  .compact .ft {
    height: 32px;
  }

  .compact.touch .ft {
    height: 34px;
    font-size: 13px;
  }

  .ft.warning {
    border-top-color: color-mix(in srgb, var(--warn) 30%, transparent);
    background: var(--warn-soft);
    color: var(--warn);
    font-weight: 600;
  }

  .ft.error {
    border-top-color: color-mix(in srgb, var(--err) 30%, transparent);
    background: var(--err-soft);
    color: var(--err);
    font-weight: 600;
  }

  .ft.offline {
    background: color-mix(in srgb, var(--text) 3%, transparent);
    color: var(--muted);
    font-weight: 600;
  }
</style>
