<!--
  One projector in detail, the app's projector panel (`projector_panel.dart`)
  on every view: the header, what needs attention and since when, Status,
  Temperature with the threshold mark, Runtime and power, then Preview and
  Web UI. In the Control panel's place, in a bottom sheet (two columns on a
  tablet) or in the Map's popover.
-->
<script lang="ts">
  import type { Config, Group, Problem, Projector } from '../../api/types';
  import { formatStart } from '../../logic/alerts';
  import { cellText } from '../../logic/cells';
  import { withUnit } from '../../logic/labels';
  import { alerts } from '../../state/alerts.svelte';
  import { control } from '../../state/control.svelte';
  import Icon from '../Icon.svelte';
  import GroupPill from '../status/GroupPill.svelte';
  import PowerState from '../status/PowerState.svelte';
  import ShutterState from '../status/ShutterState.svelte';
  import SignalPill from '../status/SignalPill.svelte';
  import StatusDot from '../status/StatusDot.svelte';
  import TemperatureBar from '../status/TemperatureBar.svelte';
  import TemperatureText from '../status/TemperatureText.svelte';
  import TestPatternThumb from '../status/TestPatternThumb.svelte';

  let {
    p,
    config,
    groups,
    patternLabel,
    placement,
    columns = false,
    touch = false,
    onclose,
    onpreview,
  }: {
    p: Projector;
    config: Config;
    groups: ReadonlyMap<string, Group>;
    patternLabel: (code: string) => string;
    /** The side panel closes on Esc itself; a sheet and the popover do it for it. */
    placement: 'panel' | 'sheet' | 'popover';
    /** A tablet's sheet: Needs attention and Status | Temperature and Runtime. */
    columns?: boolean;
    /** 44 / 48 px controls. */
    touch?: boolean;
    onclose: () => void;
    /** Opens Remote Preview; none in Alignment mode. */
    onpreview?: () => void;
  } = $props();

  const group = $derived(p.groupId ? groups.get(p.groupId) : undefined);
  const status = $derived(p.status);
  /** Not "Error": a hot reading or a lost signal is an alert, not a fault of the projector. */
  const attentionTitle = $derived(
    status.level === 'error' ? 'Alert' : status.level === 'offline' ? 'Offline' : 'Needs attention',
  );
  const since = $derived(status.problems[0]?.since ?? null);
  const at = (iso: string) => formatStart(new Date(iso), alerts.now);
  const tone = (level: Problem['level']) =>
    level === 'warning' ? 'warn' : level === 'error' ? 'err' : 'faint';
</script>

<svelte:window
  onkeydown={(e) => {
    // After the toolbar's menus and any dialog, before nothing else: the
    // toolbar leaves the selection alone while the details are open.
    if (placement === 'panel' && e.key === 'Escape' && !e.defaultPrevented && !control.pending) {
      e.preventDefault();
      onclose();
    }
  }}
/>

{#snippet row(label: string, value: string)}
  <div class="kv"><span class="k">{label}</span><b>{value}</b></div>
{/snippet}

{#snippet attention()}
  {#if status.problems.length > 0}
    <section class="sec attn" style:--c="var(--{tone(status.level)})">
      <h4 class:plain={status.level === 'offline'}>{attentionTitle}</h4>
      {#each status.problems as problem (problem.kind + problem.title)}
        <div class="kv">
          <span class="k">{problem.title}</span>
          <b style:color="var(--{tone(problem.level)})">{problem.value}</b>
        </div>
      {/each}
      {#if since}{@render row('Since', at(since))}{/if}
      {#if status.level === 'offline' && p.lastSeen}{@render row('Last seen', at(p.lastSeen))}{/if}
    </section>
  {/if}
{/snippet}

{#snippet statusSection()}
  <section class="sec">
    <h4>Status</h4>
    <div class="kv"><span class="k">Power</span><PowerState power={p.power} /></div>
    <div class="kv"><span class="k">Shutter</span><ShutterState {p} /></div>
    {@render row('Input', p.input)}
    <div class="kv"><span class="k">Signal</span><span class="fit"><SignalPill {p} /></span></div>
    <div class="kv">
      <span class="k">Test pattern</span>
      <span class="fit tp"
        ><TestPatternThumb
          code={p.testPattern}
          label={cellText('testPattern', p, groups, patternLabel)}
        /></span
      >
    </div>
  </section>
{/snippet}

{#snippet gauge(
  label: string,
  display: string,
  threshold: Config['thresholds']['intake'],
  level: Projector['status']['intake'],
)}
  <div class="gauge">
    <div class="gt"><span class="k">{label}</span><b><TemperatureText {display} {level} /></b></div>
    <TemperatureBar {display} {threshold} height={6} mark />
  </div>
{/snippet}

{#snippet readings()}
  <section class="sec">
    <h4>Temperature</h4>
    {@render gauge('Intake', p.intakeTemp, config.thresholds.intake, status.intake ?? null)}
    {@render gauge('Exhaust', p.exhaustTemp, config.thresholds.exhaust, status.exhaust ?? null)}
  </section>
  <section class="sec">
    <h4>Runtime and power</h4>
    {@render row('Projector', withUnit(p.runtime))}
    {@render row('Light source', withUnit(p.lightRuntime))}
    <!-- No Errors row: the codes are in the section above, as in the app. -->
    {@render row('AC voltage', withUnit(p.acVoltage))}
  </section>
{/snippet}

<div class="details {placement}" class:touch role="region" aria-label="Projector {p.ip}">
  <header>
    <span class="dotc"><StatusDot connection={p.connection} /></span>
    <div class="who">
      <!-- The group beside the IP, so the header is two lines with or
           without one; the pill gives way, the IP stays whole. -->
      <div class="l1">
        <span class="ip">{p.ip}</span>
        {#if group}<span class="gp"><GroupPill {group} /></span>{/if}
      </div>
      <small>{p.serial === '-' || p.serial === '' ? p.name : `${p.name}, serial ${p.serial}`}</small
      >
    </div>
    <button class="x" aria-label="Close details" onclick={onclose}>
      <Icon name="close" size={touch ? 22 : 18} />
    </button>
  </header>

  <div class="body" class:columns>
    {#if columns}
      <div class="col">{@render attention()}{@render statusSection()}</div>
      <div class="col">{@render readings()}</div>
    {:else}
      {@render attention()}{@render statusSection()}{@render readings()}
    {/if}
  </div>

  <footer>
    {#if onpreview}
      <button class="act" onclick={onpreview}
        ><Icon name="preview" size={touch ? 19 : 17} />Preview</button
      >
    {/if}
    <a class="act" href="http://{p.ip}" target="_blank" rel="noopener noreferrer"
      ><Icon name="globe" size={touch ? 19 : 17} />Web UI</a
    >
  </footer>
</div>

<style>
  .details {
    min-height: 0;
    display: flex;
    flex-direction: column;
    background: var(--surface);
  }

  .details.panel {
    height: 100%;
  }

  .details.sheet {
    flex: 1;
    background: none;
  }

  header {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 12px 8px 12px 16px;
    border-bottom: 1px solid var(--line);
  }

  .sheet header {
    align-items: center;
    padding: 0 12px 12px 20px;
  }

  .dotc {
    display: flex;
    padding-top: 7px;
  }

  .sheet .dotc {
    align-self: flex-start;
    padding-top: 9px;
  }

  .who {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .l1 {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
  }

  .ip {
    flex: none;
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 15px;
    font-weight: 600;
  }

  .gp {
    display: flex;
    min-width: 0;
  }

  .who small {
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .x {
    width: 36px;
    height: 36px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 50%;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  @media (hover: hover) {
    .x:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  .body {
    flex: 1;
    min-height: 0;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 12px 16px;
    overscroll-behavior: contain;
  }

  .body.columns {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    align-items: start;
  }

  .col {
    display: flex;
    flex-direction: column;
    gap: 12px;
    min-width: 0;
  }

  .sec {
    flex: none;
    padding: 10px 14px;
    border: 1px solid var(--line-strong);
    border-radius: 14px;
    background: var(--card);
  }

  .sec.attn {
    border-color: color-mix(in srgb, var(--c) 60%, transparent);
  }

  h4 {
    margin: 0 0 4px;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .attn h4:not(.plain) {
    color: var(--c);
  }

  .kv {
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    font-size: 13px;
  }

  .k {
    flex: none;
    color: var(--muted);
  }

  .kv b,
  .gt b {
    min-width: 0;
    overflow: hidden;
    font-weight: 500;
    font-variant-numeric: tabular-nums;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .kv :global(.st) {
    font-weight: 500;
  }

  .fit {
    display: flex;
    justify-content: flex-end;
    min-width: 0;
  }

  .tp {
    font-weight: 500;
  }

  .gauge {
    display: flex;
    flex-direction: column;
    gap: 5px;
    padding: 5px 0;
  }

  .gt {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
  }

  .gt b {
    font-weight: 600;
  }

  footer {
    display: flex;
    gap: 8px;
    padding: 12px 16px;
    border-top: 1px solid var(--line);
  }

  /* Tonal, equal widths, the label on one line (owner, 2026-10-21). */
  .act {
    flex: 1 1 0;
    min-width: 0;
    height: 36px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    border: 0;
    border-radius: 10px;
    background: var(--pc);
    color: var(--on-pc);
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    white-space: nowrap;
    cursor: pointer;
  }

  @media (hover: hover) {
    .act:hover {
      background: color-mix(in srgb, var(--on-pc) 8%, var(--pc));
    }
  }

  /* ── Touch: 44 px close, 32 px rows, 48 px buttons ─────────────────── */
  .touch .x {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--soft);
    color: var(--text);
  }

  .touch .ip {
    font-size: 16px;
  }

  .touch .who small {
    font-size: 13px;
  }

  .touch .kv,
  .touch .gt {
    font-size: 14px;
  }

  .touch .kv {
    height: 32px;
  }

  .touch .sec {
    padding: 8px 14px;
  }

  .touch footer {
    gap: 10px;
    padding: 12px 16px calc(16px + env(safe-area-inset-bottom));
  }

  .touch .act {
    height: 48px;
    border-radius: 12px;
    font-size: 15px;
  }
</style>
