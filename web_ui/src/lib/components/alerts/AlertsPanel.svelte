<!--
  Active alerts, the app's panel (`active_alerts_panel.dart`, plan §7m;
  shell canvas, *Alerts on the desktop / phone / tablet…*): a 52 px header
  with the count, project groups, By projector / By alert, Fold all and ✕;
  the severity chips; rows with the white message, a severity edge and icon,
  the start time and a quiet Acknowledge; the Acknowledged fold. The footer
  holds Sound on the left (the web has no event log) and Acknowledge all on
  the right; a viewer's says acknowledging needs control, with Unlock.
  `touch` is the tablet / phone sheet: 44 px+ targets, labelled buttons on a
  tablet's bottom sheet; `narrow` (a phone held sideways, the 440 px drawer
  of a tablet held sideways) keeps the icons.
-->
<script lang="ts">
  import type { Alert, AlertSeverity } from '../../api/types';
  import {
    alertKind,
    alertMessage,
    alertOverAt,
    alertsInSections,
    byProjectGroup,
    countAlerts,
    filterEmptyTitle,
    formatStart,
    formatStarted,
    groupAlerts,
    hiddenByFilter,
    isRecovered,
    sortAlerts,
    type AlertGroup,
  } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import { device } from '../../state/device.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import Icon from '../Icon.svelte';
  import UnlockDialog from '../shell/UnlockDialog.svelte';
  import AlertIcon, { severityIcon } from './AlertIcon.svelte';

  let {
    operator,
    touch = false,
    narrow = false,
    onclose,
  }: { operator: boolean; touch?: boolean; narrow?: boolean; onclose: () => void } = $props();

  /** Groups start folded past this many (`foldAbove`). */
  const FOLD_ABOVE = 4;

  let filter = $state<AlertSeverity | null>(null);
  /** Folded / unfolded by hand; anything not in here follows the default. */
  let open = $state<Record<string, boolean>>({});
  let ackedOpen = $state<boolean | null>(null);
  let unlocking = $state(false);

  /** A tablet's sheet has room for labelled buttons; a phone keeps the icons. */
  const labelled = $derived(touch && !narrow && !device.phone);
  /** A phone's rows put the start time in the line under the message. */
  const timeInSub = $derived(touch && !labelled);

  const projectors = $derived(new Map(live.projectors.map((p) => [p.id, p])));
  const modelOf = (a: Alert) =>
    projectors.get(a.projectorId)?.name ?? (a.projector || 'Removed projector');
  const ipOf = (a: Alert) => projectors.get(a.projectorId)?.ip ?? a.ip;
  const groupOf = (id: string) => projectors.get(id)?.groupId;
  const order = $derived(live.groups.map((g) => g.id));
  const groupById = $derived(new Map(live.groups.map((g) => [g.id, g])));

  const grouping = $derived(alerts.prefs.grouping);
  const byProjector = $derived(grouping === 'projector');
  const canSection = $derived(live.groups.length > 0);
  const sectioned = $derived(canSection && alerts.prefs.byProjectGroups);

  // A severity filter is for what is still wrong; recovered ones show under All only.
  const passes = (a: Alert) => filter === null || (a.severity === filter && !isRecovered(a));
  const all = $derived(alerts.list);
  const unacked = $derived(all.filter((a) => !a.acknowledged));
  const counts = $derived(countAlerts(unacked));
  const groups = $derived(groupAlerts(unacked.filter(passes), grouping));
  const acked = $derived(sortAlerts(all.filter((a) => a.acknowledged && passes(a))));

  const groupKey = (g: AlertGroup) => `${grouping}|${g.key}`;
  const isOpen = (g: AlertGroup) => open[groupKey(g)] ?? groups.length <= FOLD_ABOVE;
  const sectionOpen = (key: string) => open[key] ?? true;
  /**
   * Everything Fold all / Unfold all reaches, in both groupings: the groups,
   * and the project-group sections or a rule's subsections. Keys as the list
   * below builds them.
   */
  const foldable = $derived<[string, boolean][]>([
    ...groups.map((g): [string, boolean] => [groupKey(g), isOpen(g)]),
    ...(sectioned && byProjector
      ? alertsInSections(groups, groupOf, order).map((s): [string, boolean] => [
          `section|${s.groupId}`,
          sectionOpen(`section|${s.groupId}`),
        ])
      : []),
    ...(sectioned && !byProjector
      ? groups.flatMap((g) =>
          byProjectGroup(g.alerts, (a) => a.projectorId, groupOf, order).map(
            (s): [string, boolean] => [
              `sub|${g.key}|${s.groupId}`,
              sectionOpen(`sub|${g.key}|${s.groupId}`),
            ],
          ),
        )
      : []),
  ]);
  const allOpen = $derived(foldable.length > 0 && foldable.every(([, o]) => o));
  const showAcked = $derived(ackedOpen ?? acked.length <= 3);

  function toggle(key: string, current: boolean) {
    open[key] = !current;
  }

  function foldAll() {
    const next = !allOpen;
    for (const [key] of foldable) open[key] = next;
  }

  const ack = (list: readonly Alert[]) => void alerts.acknowledge({ ids: list.map((a) => a.id) });
  const sectionName = (id: string | null) =>
    id ? (groupById.get(id)?.name ?? 'Ungrouped') : 'Ungrouped';
  const plural = (n: number, w: string) => `${n} ${w}${n === 1 ? '' : 's'}`;
  const projectorCount = (list: readonly Alert[]) =>
    plural(new Set(list.map((a) => a.projectorId)).size, 'projector');
  const kind = (a: Alert) => (isRecovered(a) ? 'recovered' : a.severity);
  const icon = (a: Alert) => (isRecovered(a) ? 'checkCircle' : severityIcon(a.severity));
  const since = (a: Alert) => new Date(a.since);
  const sz = (mouse: number, finger: number) => (touch ? finger : mouse);
</script>

{#snippet pills(list: readonly Alert[])}
  {@const c = countAlerts(list)}
  <span class="pills">
    {#if c.critical > 0}<span class="pl crit"
        ><AlertIcon name="error" size={sz(13, 14)} />{c.critical}</span
      >{/if}
    {#if c.warning > 0}<span class="pl warn"
        ><AlertIcon name="warning" size={sz(13, 14)} />{c.warning}</span
      >{/if}
    {#if c.recovered > 0}<span class="pl ok"
        ><AlertIcon name="checkCircle" size={sz(13, 14)} />{c.recovered}</span
      >{/if}
  </span>
{/snippet}

{#snippet ackButton(list: readonly Alert[], label: string, many: boolean)}
  {#if operator}
    <button
      class="ack"
      aria-label={label}
      title={touch ? undefined : label}
      onclick={() => ack(list)}
    >
      <AlertIcon name={many ? 'doneAll' : 'check'} size={sz(18, 22)} />
    </button>
  {/if}
{/snippet}

{#snippet row(a: Alert, byRule: boolean)}
  {@const over = alertOverAt(a, alerts.now)}
  {@const start = formatStart(since(a), alerts.now)}
  <div class="ar {kind(a)}">
    {#if !byRule || !touch}
      <span class="sic {kind(a)}"><AlertIcon name={icon(a)} size={sz(18, 20)} /></span>
    {/if}
    <span class="tx">
      <span class="msg"
        >{alertMessage(a, byRule)}{#if over},
          <span class="okc">{over}</span>{/if}</span
      >
      <span class="sub">
        {#if byRule}
          <span class="mono">{ipOf(a)}</span> {modelOf(a)}
        {:else}
          {alertKind(a)}
        {/if}
        {#if timeInSub}, {start}{/if}
      </span>
    </span>
    {#if !timeInSub}
      <span class="tm" title={formatStarted(since(a), alerts.now)}>{start}</span>
    {/if}
    {@render ackButton([a], 'Acknowledge', false)}
  </div>
{/snippet}

{#snippet sectionHeader(
  key: string,
  groupId: string | null,
  list: readonly Alert[],
  projectorsText: string,
)}
  {@const isOpenNow = sectionOpen(key)}
  <div class="gh">
    <button class="fold" aria-expanded={isOpenNow} onclick={() => toggle(key, isOpenNow)}>
      <span class="chev" class:open={isOpenNow}
        ><AlertIcon name="chevronRight" size={sz(16, 20)} /></span
      >
      <span
        class="sq"
        class:none={!groupId}
        style:background={groupId ? groupById.get(groupId)?.color : undefined}
      ></span>
      <span class="nm">{sectionName(groupId)}</span>
      <span class="md">{projectorsText}</span>
      <span class="sp"></span>
      {@render pills(list)}
    </button>
    {@render ackButton(list, `Acknowledge ${sectionName(groupId)}`, true)}
  </div>
{/snippet}

{#snippet group(g: AlertGroup)}
  {@const isOpenNow = isOpen(g)}
  {@const top = g.alerts[0] as Alert}
  <div class="gh">
    <button class="fold" aria-expanded={isOpenNow} onclick={() => toggle(groupKey(g), isOpenNow)}>
      <span class="chev" class:open={isOpenNow}
        ><AlertIcon name="chevronRight" size={sz(16, 20)} /></span
      >
      {#if byProjector}
        <span class="ip">{ipOf(top)}</span>
        <span class="md">{modelOf(top)}</span>
      {:else}
        <span class="sic {kind(top)}"><AlertIcon name={icon(top)} size={sz(16, 18)} /></span>
        <span class="nm">{alertKind(top) === 'Temperature' ? top.label : alertKind(top)}</span>
        <span class="md">{projectorCount(g.alerts)}</span>
      {/if}
      <span class="sp"></span>
      {@render pills(g.alerts)}
    </button>
    {@render ackButton(
      g.alerts,
      byProjector ? 'Acknowledge projector' : 'Acknowledge alert group',
      true,
    )}
  </div>
  {#if isOpenNow}
    <div class="ind">
      {#if !byProjector && sectioned}
        {#each byProjectGroup(g.alerts, (a) => a.projectorId, groupOf, order) as s (s.groupId)}
          {@const key = `sub|${g.key}|${s.groupId}`}
          {@render sectionHeader(key, s.groupId, s.items, projectorCount(s.items))}
          {#if sectionOpen(key)}
            <div class="ind">
              {#each s.items as a (a.id)}{@render row(a, true)}{/each}
            </div>
          {/if}
        {/each}
      {:else}
        {#each g.alerts as a (a.id)}{@render row(a, !byProjector)}{/each}
      {/if}
    </div>
  {/if}
{/snippet}

<section class="panel" class:touch class:labelled aria-label="Active alerts">
  <div class="hd">
    <div class="g">
      <b>Active alerts</b>
      <small
        >{all.length === 0
          ? 'Nothing active'
          : touch
            ? `${unacked.length} new, ${all.length} active`
            : `${all.length} active`}</small
      >
    </div>
    {#if all.length > 0}
      {#if canSection}
        <button
          class="ab"
          class:tb={labelled}
          aria-pressed={alerts.prefs.byProjectGroups}
          aria-label="Sort into project groups"
          title={touch ? undefined : 'Sort into project groups'}
          onclick={() => alerts.setPref('byProjectGroups', !alerts.prefs.byProjectGroups)}
        >
          <AlertIcon name="workspaces" size={sz(18, 20)} />{#if labelled}Groups{/if}
        </button>
      {/if}
      <span class="seg" role="group" aria-label="Group by">
        <button
          aria-pressed={byProjector}
          aria-label="By projector"
          title={touch ? undefined : 'By projector'}
          onclick={() => alerts.setPref('grouping', 'projector')}
          ><AlertIcon name="videocam" size={sz(16, 20)} />{#if labelled}By projector{/if}</button
        >
        <button
          aria-pressed={!byProjector}
          aria-label="By alert"
          title={touch ? undefined : 'By alert'}
          onclick={() => alerts.setPref('grouping', 'alert')}
          ><AlertIcon name="category" size={sz(16, 20)} />{#if labelled}By alert{/if}</button
        >
      </span>
      {#if foldable.length > 0 && !(touch && !labelled)}
        <button
          class="ab"
          class:tb={labelled}
          aria-label={allOpen ? 'Fold all' : 'Unfold all'}
          title={touch ? undefined : allOpen ? 'Fold all' : 'Unfold all'}
          onclick={foldAll}
        >
          <AlertIcon
            name={allOpen ? 'unfoldLess' : 'unfoldMore'}
            size={sz(18, 20)}
          />{#if labelled}{allOpen ? 'Collapse' : 'Expand'}{/if}
        </button>
      {/if}
    {/if}
    <button
      class="ab x"
      aria-label="Close alerts"
      title={touch ? undefined : 'Close'}
      onclick={onclose}
    >
      <AlertIcon name="close" size={sz(18, 22)} />
    </button>
  </div>

  {#if all.length === 0}
    <div class="empty">
      <span class="okc"><AlertIcon name="checkCircle" size={sz(30, 44)} /></span>
      <b>No active alerts</b>
      <span>Everything is within limits. Past alerts are in the app's event log.</span>
    </div>
  {:else}
    <div class="chips" role="group" aria-label="Severity">
      <button class="chip" aria-pressed={filter === null} onclick={() => (filter = null)}
        >All <b>{counts.critical + counts.warning + counts.recovered}</b></button
      >
      <button
        class="chip"
        aria-pressed={filter === 'critical'}
        onclick={() => (filter = 'critical')}
        ><span class="crit"><AlertIcon name="error" size={sz(14, 16)} /></span>Critical
        <b>{counts.critical}</b></button
      >
      <button class="chip" aria-pressed={filter === 'warning'} onclick={() => (filter = 'warning')}
        ><span class="warn"><AlertIcon name="warning" size={sz(14, 16)} /></span>Warning
        <b>{counts.warning}</b></button
      >
    </div>

    <div class="list">
      {#if unacked.length === 0}
        <div class="empty">
          <span class="okc"><AlertIcon name="doneAll" size={sz(30, 44)} /></span>
          <b>All acknowledged</b>
          <span>These alerts are still active; they leave the list when the condition clears.</span>
        </div>
      {:else if groups.length === 0 && filter}
        <div class="empty">
          <b>{filterEmptyTitle(filter)}</b>
          <span>{hiddenByFilter(unacked, filter)}</span>
        </div>
      {/if}
      {#if byProjector && sectioned}
        {#each alertsInSections(groups, groupOf, order) as s (s.groupId)}
          {@const key = `section|${s.groupId}`}
          {@render sectionHeader(
            key,
            s.groupId,
            s.items.flatMap((g) => g.alerts),
            plural(s.items.length, 'projector'),
          )}
          {#if sectionOpen(key)}
            <div class="ind">
              {#each s.items as g (g.key)}{@render group(g)}{/each}
            </div>
          {/if}
        {/each}
      {:else}
        {#each groups as g (g.key)}{@render group(g)}{/each}
      {/if}
      {#if acked.length > 0}
        <button class="ak" aria-expanded={showAcked} onclick={() => (ackedOpen = !showAcked)}>
          <span class="chev" class:open={showAcked}
            ><AlertIcon name="chevronRight" size={sz(16, 20)} /></span
          >
          Acknowledged <b>{acked.length}</b>
        </button>
        {#if showAcked}
          {#each acked as a (a.id)}
            <div class="ackl">
              <span class="sic {a.severity}"
                ><AlertIcon name={severityIcon(a.severity)} size={sz(15, 18)} /></span
              >
              <!-- One quiet line, as in the app; the mouse gets the rest on hover. -->
              <span class="tx" title="{ipOf(a)} {alertMessage(a)}"
                ><span class="mono">{ipOf(a)}</span> {alertMessage(a)}</span
              >
              <span class="tm">{formatStart(since(a), alerts.now)}</span>
            </div>
          {/each}
        {/if}
      {/if}
    </div>
  {/if}

  <!-- Sound on the left, where the app has the Event log; the main action on the right. -->
  <div class="ft">
    <button
      class="btn-t"
      class:locked={alerts.soundLocked}
      aria-pressed={alerts.prefs.sound}
      title={alerts.soundLocked ? 'Sound blocked by the browser, click to enable' : undefined}
      onclick={() => alerts.toggleSound()}
    >
      <AlertIcon
        name={alerts.prefs.sound ? 'volumeOn' : 'volumeOff'}
        size={sz(18, 22)}
      />{alerts.soundLocked
        ? 'Tap for sound'
        : touch && !labelled
          ? 'Sound'
          : alerts.prefs.sound
            ? 'Sound on'
            : 'Sound off'}
    </button>
    {#if operator}
      <!-- A phone's Acknowledge all takes the rest of the row. -->
      {#if labelled || !touch}<span class="sp"></span>{/if}
      {#if unacked.length > 0}
        <button class="btn-f" class:grow={touch && !labelled} onclick={() => ack(unacked)}>
          <AlertIcon name="doneAll" size={sz(18, 22)} />Acknowledge all
        </button>
      {/if}
    {:else}
      <span class="vn">Acknowledging needs control</span>
      {#if session.controlAllowed}
        <button
          class="btn-u"
          class:ic={touch && !labelled}
          aria-label="Unlock control"
          onclick={() => (unlocking = true)}
          >{#if touch && !labelled}<Icon name="unlock" size={22} />{:else}Unlock{/if}</button
        >
      {/if}
    {/if}
  </div>
</section>

{#if unlocking}
  <UnlockDialog onclose={() => (unlocking = false)} />
{/if}

<style>
  .panel {
    height: 100%;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    background: var(--menu);
    color: var(--text);
  }

  button {
    font: inherit;
    color: inherit;
    cursor: pointer;
  }

  .mono {
    font-family: var(--mono);
    letter-spacing: 0;
  }

  .crit {
    color: var(--err);
  }

  .warn {
    color: var(--warn);
  }

  .okc,
  .ok {
    color: var(--ok);
  }

  /* ── Header ─────────────────────────────────────────────────────────── */
  .hd {
    height: 52px;
    flex: none;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 8px 0 16px;
  }

  .hd .g {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: baseline;
    gap: 8px;
  }

  .hd b {
    font-size: 15px;
    font-weight: 600;
    white-space: nowrap;
  }

  .hd small {
    color: var(--muted);
    font-size: 12.5px;
    white-space: nowrap;
  }

  .ab {
    width: 32px;
    height: 32px;
    display: inline-flex;
    flex: none;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 0;
    border: 0;
    border-radius: 9px;
    background: none;
    color: var(--muted);
  }

  .ab[aria-pressed='true'] {
    background: var(--pc);
    color: var(--on-pc);
  }

  .seg {
    display: flex;
    flex: none;
    gap: 2px;
    padding: 2px;
    border: 1px solid var(--line);
    border-radius: 10px;
    background: var(--hover);
  }

  .seg button {
    width: 30px;
    height: 26px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    padding: 0;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--muted);
  }

  .seg button[aria-pressed='true'] {
    background: var(--card);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  @media (hover: hover) {
    .ab:not([aria-pressed='true']):hover,
    .ack:hover {
      background: var(--hover);
      color: var(--text);
    }
  }

  /* ── Severity chips ─────────────────────────────────────────────────── */
  .chips {
    flex: none;
    display: flex;
    gap: 6px;
    padding: 0 12px 10px;
  }

  .chip {
    height: 30px;
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 0 11px;
    border: 1px solid var(--line-strong);
    border-radius: 999px;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 500;
  }

  .chip span {
    display: flex;
  }

  .chip b {
    color: var(--faint);
    font-weight: 600;
  }

  .chip[aria-pressed='true'] {
    border-color: var(--accent);
    background: var(--pc);
    color: var(--on-pc);
  }

  .chip[aria-pressed='true'] b {
    color: var(--on-pc);
  }

  /* ── List ───────────────────────────────────────────────────────────── */
  .list {
    flex: 1;
    min-height: 0;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 8px;
    border-top: 1px solid var(--line);
    overscroll-behavior: contain;
  }

  .list > :global(*),
  .ind > :global(*) {
    flex: none;
  }

  .ind {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-left: 12px;
  }

  .gh {
    min-height: 36px;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .fold {
    flex: 1;
    min-width: 0;
    min-height: 36px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 4px 0 6px;
    border: 0;
    border-radius: 9px;
    background: none;
    text-align: left;
  }

  @media (hover: hover) {
    .fold:hover,
    .ak:hover {
      background: var(--hover);
    }
  }

  .chev {
    display: flex;
    flex: none;
    color: var(--muted);
    transition: transform 0.12s;
  }

  .chev.open {
    transform: rotate(90deg);
  }

  .ip {
    flex: none;
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 13px;
  }

  .nm {
    flex: none;
    font-size: 13.5px;
    font-weight: 600;
    white-space: nowrap;
  }

  .md {
    min-width: 0;
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sp {
    flex: 1;
  }

  .sq {
    width: 12px;
    height: 12px;
    flex: none;
    border-radius: 3px;
  }

  .sq.none {
    border: 1.5px solid var(--line-strong);
  }

  .pills {
    display: inline-flex;
    flex: none;
    gap: 4px;
  }

  .pl {
    height: 20px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 0 7px 0 5px;
    border-radius: 999px;
    font-size: 11.5px;
    font-weight: 600;
  }

  .pl.crit {
    background: color-mix(in srgb, var(--err) 18%, transparent);
  }

  .pl.warn {
    background: color-mix(in srgb, var(--warn) 16%, transparent);
  }

  .pl.ok {
    background: color-mix(in srgb, var(--ok) 15%, transparent);
  }

  .ack {
    width: 30px;
    height: 30px;
    display: inline-flex;
    flex: none;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 0;
    border-radius: 9px;
    background: none;
    color: var(--muted);
  }

  /* A row: the white message, a severity edge and icon, the start time. */
  .ar {
    --edge: var(--err);
    position: relative;
    min-height: 52px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 7px 4px 7px 12px;
    border-radius: 10px;
    background: color-mix(in srgb, var(--text) 6%, var(--menu));
  }

  .ar::before {
    content: '';
    position: absolute;
    left: 0;
    top: 9px;
    bottom: 9px;
    width: 3px;
    border-radius: 0 2px 2px 0;
    background: var(--edge);
  }

  .ar.warning {
    --edge: var(--warn);
  }

  .ar.recovered {
    --edge: var(--ok);
  }

  .sic {
    display: flex;
    flex: none;
  }

  .sic.critical {
    color: var(--err);
  }

  .sic.warning {
    color: var(--warn);
  }

  .sic.recovered {
    color: var(--ok);
  }

  .tx {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .msg {
    font-size: 14px;
    font-weight: 500;
  }

  .sub {
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sub .mono {
    color: var(--text);
  }

  .tm {
    flex: none;
    color: var(--muted);
    font-family: var(--mono);
    letter-spacing: 0;
    font-size: 12px;
  }

  /* The Acknowledged fold. */
  .ak {
    min-height: 34px;
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 6px;
    padding: 6px 6px 0;
    border: 0;
    border-top: 1px solid var(--line);
    border-radius: 0;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
    text-align: left;
  }

  .ak b {
    color: var(--faint);
  }

  .ackl {
    min-height: 32px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 6px 0 12px;
    color: var(--muted);
    font-size: 12.5px;
  }

  .ackl .tx {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 32px 20px;
    color: var(--muted);
    font-size: 13px;
    text-align: center;
  }

  .empty b {
    color: var(--text);
    font-size: 14px;
  }

  /* ── Footer ─────────────────────────────────────────────────────────── */
  /* Pinned to the bottom: without alerts there is no list to push it there. */
  .ft {
    min-height: 56px;
    flex: none;
    margin-top: auto;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px 0 8px;
    border-top: 1px solid var(--line);
    background: color-mix(in srgb, var(--menu) 85%, var(--app));
  }

  .ft button,
  .ft span {
    white-space: nowrap;
  }

  .btn-t {
    height: 36px;
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 0 12px;
    border: 0;
    border-radius: 999px;
    background: none;
    color: var(--accent);
    font-size: 13.5px;
    font-weight: 600;
  }

  .btn-t[aria-pressed='false'] {
    color: var(--muted);
  }

  /* The browser still blocks sound until a tap: amber, as before. */
  .btn-t.locked {
    color: var(--warn);
  }

  @media (hover: hover) {
    .btn-t:hover {
      background: var(--accent-soft);
    }
  }

  .btn-f {
    height: 36px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    padding: 0 16px 0 12px;
    border: 0;
    border-radius: 999px;
    background: var(--primary);
    color: var(--on-primary);
    font-size: 13.5px;
    font-weight: 600;
  }

  .vn {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    color: var(--muted);
    font-size: 12.5px;
    text-align: right;
    text-overflow: ellipsis;
  }

  .btn-u {
    height: 36px;
    flex: none;
    padding: 0 14px;
    border: 0;
    border-radius: 999px;
    background: var(--pc);
    color: var(--on-pc);
    font-size: 13.5px;
    font-weight: 600;
  }

  /* ── Touch sheets: 44 px+ targets; a tablet labels its buttons ──────── */
  .touch .hd {
    height: 64px;
    gap: 4px;
    padding: 0 8px 0 18px;
  }

  .touch .hd .g {
    flex-direction: column;
    gap: 0;
  }

  .touch .hd b {
    font-size: 16px;
  }

  .touch .ab {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }

  .touch .ab.x {
    background: var(--soft);
    color: var(--text);
  }

  .touch .seg {
    border-radius: 12px;
  }

  .touch .seg button {
    width: 42px;
    height: 38px;
    border-radius: 9px;
  }

  .labelled .hd {
    height: 68px;
    gap: 8px;
    padding: 0 12px 0 22px;
  }

  .labelled .hd b {
    font-size: 17px;
  }

  .labelled .ab.tb {
    width: auto;
    padding: 0 14px 0 12px;
    border: 1px solid var(--line-strong);
    font-size: 13.5px;
    font-weight: 600;
  }

  .labelled .ab.tb[aria-pressed='true'] {
    border-color: var(--accent);
  }

  .labelled .seg button {
    width: auto;
    padding: 0 12px;
    font-size: 13.5px;
    font-weight: 500;
  }

  .touch .chips {
    gap: 8px;
    padding: 0 14px 12px;
  }

  .touch .chip {
    height: 40px;
    padding: 0 14px;
    font-size: 13.5px;
  }

  .touch .list {
    gap: 6px;
    padding: 10px;
  }

  .touch .gh,
  .touch .fold {
    min-height: 48px;
  }

  .touch .ip {
    font-size: 14px;
  }

  .touch .md {
    font-size: 13px;
  }

  .touch .pl {
    height: 22px;
    font-size: 12px;
  }

  .touch .ack {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }

  .touch .ar {
    min-height: 62px;
    gap: 12px;
    padding: 8px 2px 8px 14px;
    border-radius: 12px;
  }

  .touch .msg {
    font-size: 14.5px;
  }

  .touch .ak {
    min-height: 44px;
    font-size: 13.5px;
  }

  .touch .ft {
    gap: 8px;
    padding: 12px 14px calc(16px + env(safe-area-inset-bottom));
  }

  .touch .btn-t,
  .touch .btn-f,
  .touch .btn-u {
    height: 48px;
    font-size: 14.5px;
  }

  .touch .btn-f.grow {
    flex: 1;
    font-size: 15px;
  }

  .touch .btn-u.ic {
    width: 48px;
    padding: 0;
    border-radius: 14px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
</style>
