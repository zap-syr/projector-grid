<!--
  One projector card (Phase 6 boards): the IP with its worst problem, the
  model (last seen while offline), power and shutter, input and signal, then
  the temperatures. Offline it is the app's compact tile: a dashed outline and
  a grey Offline pill. Every card has the same height, and the whole card
  answers a click. The operator taps the card to select it and ⓘ to open the
  details; the viewer's tap opens them.
-->
<script lang="ts">
  import type { AlignmentRole, Projector } from '../../api/types';
  import { modelLine } from '../../logic/cells';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import { isSelectable } from '../../logic/selection';
  import { alerts } from '../../state/alerts.svelte';
  import { device } from '../../state/device.svelte';
  import Checkbox from '../Checkbox.svelte';
  import Icon from '../Icon.svelte';
  import PowerState from '../status/PowerState.svelte';
  import ShutterState from '../status/ShutterState.svelte';
  import SignalPill from '../status/SignalPill.svelte';
  import StatusDot from '../status/StatusDot.svelte';
  import StatusPill from '../status/StatusPill.svelte';
  import TemperatureText from '../status/TemperatureText.svelte';

  let {
    p,
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
  const online = $derived(p.connection === 'connected' || p.connection === 'unprotected');
  /**
   * The worst problem beside the IP. A projector that doesn't answer says so
   * in its own pill (Offline, Wrong login) instead.
   */
  const problem = $derived(
    online
      ? p.status.problems.find((x) => x.level === 'warning' || x.level === 'error')
      : undefined,
  );
  const pattern = $derived(
    online && isPatternActive(p.testPattern) && p.testPattern ? p.testPattern : null,
  );

  /** No details in Alignment mode: the Control's place belongs to the lens. */
  function primary() {
    if (aligning) {
      if (operator && role) onfocus?.();
    } else if (!operator) ondetails();
    else if (selectable) onselect();
  }
</script>

<article
  class="card {role ?? ''}"
  class:sel={operator && selected && !aligning}
  class:open
  class:hasinfo={operator && !aligning}
  class:outside
  class:warn={p.connection !== 'offline' && p.status.level === 'warning'}
  class:err={p.connection !== 'offline' && p.status.level === 'error'}
  class:offline={p.connection === 'offline'}
>
  <div class="head">
    {#if operator && !aligning}
      <span class="cb">
        <Checkbox
          state={selected}
          label="Select {p.ip}"
          disabled={!selectable}
          onclick={onselect}
        />
      </span>
    {/if}
    <button
      class="main"
      disabled={operator && !selectable}
      aria-label="{p.ip}, {p.name}"
      aria-pressed={operator
        ? aligning
          ? role === 'focused'
          : selected
        : aligning
          ? undefined
          : open}
      onclick={primary}
    >
      <span class="top">
        <StatusDot connection={p.connection} />
        <span class="ip">{p.ip}</span>
        {#if problem}
          <span class="badge" title="{problem.title}: {problem.value}">
            <StatusPill
              label={problem.flag}
              tone={problem.level === 'error' ? 'err' : 'warn'}
              icon={problem.level === 'error' ? 'error' : 'warn'}
            />
          </span>
        {/if}
      </span>
      <small class="md">{modelLine(p, alerts.now)}</small>
      <!-- Three lines of fixed height whatever the state, so every card is
           the same height and a change of value moves nothing. -->
      <span class="lines">
        {#if online}
          <span class="l1">
            <PowerState power={p.power} />
            <ShutterState {p} />
            {#if pattern}
              <span
                class="tp"
                role="img"
                aria-label="Test pattern: {patternLabel(pattern)}"
                title="Test pattern: {patternLabel(pattern)}"
                style:background={patternSwatch(pattern) ?? 'var(--hover)'}
              ></span>
            {/if}
          </span>
          <span class="l2">
            <span class="in">{p.input}</span>
            <span class="sig"><SignalPill {p} /></span>
          </span>
          <span class="l3">
            <span
              >In <TemperatureText display={p.intakeTemp} level={p.status.intake ?? null} /></span
            >
            <span
              >Ex <TemperatureText display={p.exhaustTemp} level={p.status.exhaust ?? null} /></span
            >
          </span>
        {:else}
          <span class="l1"></span>
          <span class="l2">
            {#if p.connection === 'unauthorized'}
              <StatusPill label="Wrong login" tone="warn" icon="lock" />
            {:else}
              <StatusPill label="Offline" tone="faint" dot />
            {/if}
          </span>
          <span class="l3"></span>
        {/if}
      </span>
    </button>
    <!-- The operator's way to the details (a tap selects); a viewer's tap opens them. -->
    {#if operator && !aligning}
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
    {/if}
  </div>
</article>

<style>
  /* The card's button fills it, so every part of the card answers a click. */
  .card {
    flex: none;
    display: flex;
    flex-direction: column;
    background: var(--card);
    border: 1px solid var(--line-strong);
    border-radius: 14px;
  }

  /* A problem tints the outline: amber for a warning, red for an error. */
  .card.warn {
    border-color: color-mix(in srgb, var(--warn) 55%, transparent);
  }

  .card.err {
    border-color: color-mix(in srgb, var(--err) 60%, transparent);
  }

  /* The app's compact offline tile: a dashed outline on the window, a grey IP. */
  .card.offline {
    border-style: dashed;
    background: transparent;
  }

  .card.offline .ip {
    color: var(--faint);
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

  .head {
    position: relative;
    flex: 1;
    display: flex;
    align-items: stretch;
  }

  .cb {
    display: flex;
    align-self: flex-start;
    padding: 13px 0 0 12px;
  }

  .main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 5px;
    padding: 11px 12px 12px;
    border: 0;
    background: none;
    text-align: left;
    cursor: pointer;
  }

  .main:disabled {
    cursor: default;
  }

  /* IP, then the worst problem; clear of the operator's ⓘ. */
  .top {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
    height: 22px;
  }

  .card.hasinfo .top {
    padding-right: 30px;
  }

  .ip {
    flex: none;
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 13.5px;
    font-weight: 600;
  }

  .badge {
    display: flex;
    min-width: 0;
  }

  .md {
    margin: -4px 0 0 16px;
    overflow: hidden;
    color: var(--muted);
    font-size: 12px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .lines {
    display: flex;
    flex-direction: column;
    gap: 5px;
    min-width: 0;
    font-size: 13px;
  }

  .l1,
  .l2,
  .l3 {
    display: flex;
    align-items: center;
    min-width: 0;
  }

  .l1 {
    height: 20px;
    gap: 14px;
    font-weight: 500;
  }

  .l2 {
    height: 22px;
    gap: 8px;
    color: var(--muted);
    font-size: 12.5px;
  }

  .l3 {
    height: 18px;
    gap: 18px;
    color: var(--faint);
    font-size: 12.5px;
    font-variant-numeric: tabular-nums;
  }

  .l3 :global(.tt) {
    color: var(--muted);
    font-weight: 500;
  }

  .in {
    flex: none;
    white-space: nowrap;
  }

  /* The signal gives way first on a narrow card. */
  .sig {
    display: flex;
    min-width: 0;
  }

  /* Test-pattern thumbnail, bordered so white / black fields don't vanish. */
  .tp {
    width: 24px;
    height: 16px;
    flex: none;
    margin-left: auto;
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
  }

  /* ⓘ in the top-right corner: 32 px with a mouse, 44 px for a finger. */
  .info {
    position: absolute;
    top: 6px;
    right: 6px;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--muted);
    cursor: pointer;
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

  @media (pointer: coarse) {
    .info {
      top: 1px;
      right: 1px;
      width: 44px;
      height: 44px;
      border-radius: 10px;
    }

    .card.hasinfo .top {
      padding-right: 38px;
    }
  }
</style>
