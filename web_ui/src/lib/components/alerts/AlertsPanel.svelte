<!--
  Active alerts, the app's panel (`active_alerts_panel.dart`): severity
  filter, grouping by projector or by alert, the project-groups toggle (by
  projector: sections; by alert: subsections inside each rule), acknowledged
  ones folded at the bottom. `touch` is the tablet / phone layout: labelled
  segments, 44 px+ targets, Sound and Acknowledge all in a footer at the
  bottom edge; `narrow` (a phone held sideways) puts the segments in one row.
-->
<script lang="ts">
  import type { Alert, AlertSeverity } from '../../api/types';
  import {
    alertsInSections,
    byProjectGroup,
    countAlerts,
    formatDuration,
    formatStart,
    groupAlerts,
    isRecovered,
    sortAlerts,
    type AlertGroup,
  } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
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

  const projectors = $derived(new Map(live.projectors.map((p) => [p.id, p])));
  const nameOf = (a: Alert) =>
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
  const since = (a: Alert) => new Date(a.since);
</script>

{#snippet countIcons(list: readonly Alert[])}
  {@const c = countAlerts(list)}
  {#if c.critical > 0}<span class="sc crit"
      ><AlertIcon name="error" size={touch ? 19 : 14} />{c.critical}</span
    >{/if}
  {#if c.warning > 0}<span class="sc warn"
      ><AlertIcon name="warning" size={touch ? 19 : 14} />{c.warning}</span
    >{/if}
  {#if c.recovered > 0}<span class="sc ok"
      ><AlertIcon name="checkCircle" size={touch ? 19 : 14} />{c.recovered}</span
    >{/if}
{/snippet}

{#snippet ackButton(list: readonly Alert[], label: string, many: boolean)}
  {#if operator}
    <button
      class="ack"
      class:many
      aria-label={label}
      title={touch ? undefined : label}
      onclick={() => ack(list)}
    >
      <AlertIcon name={many ? 'doneAll' : 'check'} size={touch ? (many ? 24 : 26) : 16} />
    </button>
  {/if}
{/snippet}

{#snippet row(a: Alert, byRule: boolean)}
  <div class="row {kind(a)}">
    <span class="chip {kind(a)}"
      ><AlertIcon
        name={isRecovered(a) ? 'checkCircle' : severityIcon(a.severity)}
        size={touch ? 22 : 16}
      /></span
    >
    <span class="mid">
      {#if byRule}
        <span class="rl subj">{nameOf(a)}<span>{ipOf(a)}</span></span>
      {:else}
        <span class="rl">{a.label}</span>
      {/if}
      <span class="val {kind(a)}">{a.value}</span>
      {#if touch}
        <span class="tm"
          ><b>{formatDuration(alerts.now.getTime() - Date.parse(a.since))}</b>, since {formatStart(
            since(a),
            alerts.now,
          )}</span
        >
      {/if}
    </span>
    {#if !touch}
      <span class="tm">
        <b>{formatDuration(alerts.now.getTime() - Date.parse(a.since))}</b>
        <span>{formatStart(since(a), alerts.now)}</span>
      </span>
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
  <div class="sec">
    <button class="fold" aria-expanded={isOpenNow} onclick={() => toggle(key, isOpenNow)}>
      <span class="chev" class:open={isOpenNow}
        ><AlertIcon name="chevronRight" size={touch ? 22 : 16} /></span
      >
      <span
        class="gdot"
        class:none={!groupId}
        style:background={groupId ? groupById.get(groupId)?.color : undefined}
      ></span>
      <span class="nm">{sectionName(groupId)}<span>{projectorsText}</span></span>
      {@render countIcons(list)}
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
        ><AlertIcon name="chevronRight" size={touch ? 22 : 16} /></span
      >
      {#if byProjector}
        <span class="ttl">{nameOf(top)}<span>{ipOf(top)}</span></span>
        {@render countIcons(g.alerts)}
      {:else}
        {#if !touch}
          <span class="chip sm {kind(top)}"
            ><AlertIcon
              name={isRecovered(top) ? 'checkCircle' : severityIcon(top.severity)}
              size={14}
            /></span
          >
        {/if}
        <span class="ttl"
          >{top.label}<span
            >{projectorCount(g.alerts)}, since {formatStart(
              new Date(Math.min(...g.alerts.map((a) => Date.parse(a.since)))),
              alerts.now,
            )}</span
          ></span
        >
        <span class="sc {isRecovered(top) ? 'ok' : top.severity === 'critical' ? 'crit' : 'warn'}"
          >{#if touch}<AlertIcon
              name={isRecovered(top) ? 'checkCircle' : severityIcon(top.severity)}
              size={19}
            />{/if}{g.alerts.length}</span
        >
      {/if}
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

<div class="panel" class:touch class:narrow role="region" aria-label="Active alerts">
  <div class="head">
    <div class="title">
      <h2>Active alerts</h2>
      {#if touch}
        <span class="sub"
          >{all.length ? `${unacked.length} new, ${all.length} active` : 'Nothing active'}</span
        >
      {:else if all.length}
        <span class="sub">{all.length} total</span>
      {/if}
    </div>
    {#if foldable.length > 0}
      <button
        class="ib"
        class:text={touch && !narrow}
        aria-label={allOpen ? 'Fold all' : 'Unfold all'}
        title={touch ? undefined : allOpen ? 'Fold all' : 'Unfold all'}
        onclick={foldAll}
      >
        <AlertIcon name={allOpen ? 'unfoldLess' : 'unfoldMore'} size={touch ? 22 : 18} />
        {#if touch && !narrow}<span>{allOpen ? 'Collapse' : 'Expand'}</span>{/if}
      </button>
    {/if}
    {#if !touch}
      {#if operator && unacked.length > 0}
        <button
          class="ib"
          aria-label="Acknowledge all"
          title="Acknowledge all"
          onclick={() => ack(unacked)}
        >
          <AlertIcon name="doneAll" size={18} />
        </button>
      {/if}
      <button
        class="ib"
        aria-pressed={alerts.prefs.sound}
        class:locked={alerts.soundLocked}
        aria-label="Sound"
        title={alerts.soundLocked
          ? 'Sound blocked by the browser, click to enable'
          : alerts.prefs.sound
            ? 'Sound on in this browser'
            : 'Sound off'}
        onclick={() => alerts.toggleSound()}
      >
        <AlertIcon name={alerts.prefs.sound ? 'volumeOn' : 'volumeOff'} size={18} />
      </button>
    {/if}
    <button
      class="ib close"
      aria-label="Close alerts"
      title={touch ? undefined : 'Close'}
      onclick={onclose}
    >
      <AlertIcon name="close" size={touch ? 24 : 18} />
    </button>
  </div>

  {#if all.length === 0}
    <div class="empty">
      <span class="ok"><AlertIcon name="checkCircle" size={touch ? 44 : 30} /></span>
      <b>No active alerts</b>
      <span>Everything is within limits. Past alerts are in the app's event log.</span>
    </div>
  {:else}
    <div class="tools">
      <div class="seg sev" role="group" aria-label="Severity">
        <button aria-pressed={filter === null} onclick={() => (filter = null)}
          >All <b>{counts.critical + counts.warning + counts.recovered}</b></button
        >
        <button
          aria-pressed={filter === 'critical'}
          aria-label="Critical"
          onclick={() => (filter = 'critical')}
          ><span class="crit"><AlertIcon name="error" size={touch ? 20 : 13} /></span
          >{#if touch && !narrow}Critical{/if}
          <b>{counts.critical}</b></button
        >
        <button
          aria-pressed={filter === 'warning'}
          aria-label="Warning"
          onclick={() => (filter = 'warning')}
          ><span class="warn"><AlertIcon name="warning" size={touch ? 20 : 13} /></span
          >{#if touch && !narrow}Warning{/if}
          <b>{counts.warning}</b></button
        >
      </div>
      <div class="opts">
        {#if canSection}
          <button
            class="pg"
            aria-pressed={alerts.prefs.byProjectGroups}
            aria-label="Sort into project groups"
            title={touch ? undefined : 'Sort into project groups'}
            onclick={() => alerts.setPref('byProjectGroups', !alerts.prefs.byProjectGroups)}
          >
            <AlertIcon name="workspaces" size={touch ? 22 : 15} />{#if touch && !narrow}<span
                >Groups</span
              >{/if}
          </button>
        {/if}
        <div class="seg grp" role="group" aria-label="Group by">
          <button aria-pressed={byProjector} onclick={() => alerts.setPref('grouping', 'projector')}
            ><AlertIcon name="videocam" size={touch ? 20 : 14} />{touch
              ? narrow
                ? 'Projector'
                : 'By projector'
              : 'Projector'}</button
          >
          <button aria-pressed={!byProjector} onclick={() => alerts.setPref('grouping', 'alert')}
            ><AlertIcon name="category" size={touch ? 20 : 14} />{touch
              ? narrow
                ? 'Alert'
                : 'By alert'
              : 'Alert'}</button
          >
        </div>
      </div>
    </div>

    <div class="list">
      {#if unacked.length === 0}
        <div class="empty">
          <span class="ok"><AlertIcon name="doneAll" size={touch ? 44 : 30} /></span>
          <b>All acknowledged</b>
          <span>These alerts are still active; they leave the list when the condition clears.</span>
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
      {#if unacked.length > 0 && groups.length === 0}
        <p class="nothing">Nothing at this severity</p>
      {/if}
      {#if acked.length > 0}
        <button class="ackh" aria-expanded={showAcked} onclick={() => (ackedOpen = !showAcked)}>
          <span class="chev" class:open={showAcked}
            ><AlertIcon name="chevronRight" size={touch ? 22 : 16} /></span
          >
          Acknowledged ({acked.length})
        </button>
        {#if showAcked}
          {#each acked as a (a.id)}
            <div class="ackl">
              <span class={a.severity === 'critical' ? 'crit' : 'warn'}
                ><AlertIcon name={severityIcon(a.severity)} size={touch ? 20 : 15} /></span
              >
              <!-- One quiet line, as in the app; the mouse gets the rest on hover. -->
              <span class="tx" title="{nameOf(a)} {a.label}: {a.value}"
                ><b>{nameOf(a)} {a.label}:</b> {a.value}</span
              >
              <span class="d">{formatDuration(alerts.now.getTime() - Date.parse(a.since))}</span>
            </div>
          {/each}
        {/if}
      {/if}
    </div>
  {/if}

  {#if touch}
    <!-- Thumb zone: the actions sit on the bottom edge. -->
    <div class="foot">
      <button
        class="fbtn"
        class:locked={alerts.soundLocked}
        aria-pressed={alerts.prefs.sound}
        onclick={() => alerts.toggleSound()}
      >
        <AlertIcon name={alerts.prefs.sound ? 'volumeOn' : 'volumeOff'} size={22} />
        {alerts.soundLocked ? 'Tap for sound' : 'Sound'}
      </button>
      {#if operator}
        {#if unacked.length > 0}
          <button class="fbtn primary" onclick={() => ack(unacked)}>
            <AlertIcon name="doneAll" size={22} />Acknowledge all ({unacked.length})
          </button>
        {/if}
      {:else}
        <span class="vtext">Acknowledging needs control.</span>
        {#if session.controlAllowed && unacked.length > 0}
          <button class="fbtn primary short" onclick={() => (unlocking = true)}>Unlock</button>
        {/if}
      {/if}
    </div>
  {:else if !operator && unacked.length > 0}
    <div class="vnote">
      <span>Viewers see alerts; acknowledging needs control.</span>
      {#if session.controlAllowed}
        <button class="small" onclick={() => (unlocking = true)}>Unlock control</button>
      {/if}
    </div>
  {/if}
</div>

{#if unlocking}
  <UnlockDialog onclose={() => (unlocking = false)} />
{/if}

<style>
  /* Fills the drawer; in a sheet, takes what the sheet's max height leaves. */
  .panel {
    display: flex;
    flex-direction: column;
    flex: 1 1 auto;
    gap: 6px;
    height: 100%;
    min-height: 0;
    padding: 10px 10px 12px;
    background: var(--surface);
  }

  .crit {
    color: var(--sev-crit);
    display: inline-flex;
  }

  .warn {
    color: var(--sev-warn);
    display: inline-flex;
  }

  .ok {
    color: var(--sev-ok);
    display: inline-flex;
  }

  /* ── header ── */
  .head {
    display: flex;
    align-items: center;
    gap: 2px;
    min-height: 34px;
    padding-left: 8px;
    flex: none;
  }

  .title {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: baseline;
    gap: 8px;
  }

  h2 {
    margin: 0;
    font-size: 14px;
    font-weight: 650;
    white-space: nowrap;
  }

  .sub {
    font-size: 12px;
    color: var(--faint);
    white-space: nowrap;
  }

  .ib {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    min-width: 30px;
    height: 30px;
    padding: 0;
    border: 0;
    border-radius: 7px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .ib:hover {
    background: var(--hover);
    color: var(--text);
  }

  .ib[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  /* Sound on but not yet allowed by the browser: needs a tap. */
  .ib.locked,
  .fbtn.locked {
    background: var(--warn-soft);
    color: var(--warn);
  }

  /* ── tools ── */
  .tools {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    gap: 6px;
    padding: 0 2px 4px 4px;
    flex: none;
  }

  .opts {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .seg {
    display: flex;
    align-items: center;
  }

  .seg.sev {
    gap: 6px;
  }

  .seg.sev button {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    height: 24px;
    padding: 0 9px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: none;
    font-size: 12px;
    color: var(--text);
    cursor: pointer;
    white-space: nowrap;
  }

  .seg.sev b {
    font-weight: 600;
    color: var(--faint);
    font-variant-numeric: tabular-nums;
  }

  .seg.sev button[aria-pressed='true'] {
    border-color: transparent;
    background: var(--accent-soft);
    color: var(--accent);
  }

  .seg.sev button[aria-pressed='true'] b {
    color: var(--accent);
  }

  .seg.grp {
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    overflow: hidden;
  }

  .seg.grp button {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    height: 22px;
    padding: 0 8px;
    border: 0;
    background: none;
    font-size: 11.5px;
    color: var(--muted);
    cursor: pointer;
    white-space: nowrap;
  }

  .seg.grp button + button {
    border-left: 1px solid var(--line-strong);
  }

  .seg.grp button[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  .pg {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    width: 24px;
    height: 24px;
    padding: 0;
    border: 1px solid var(--line-strong);
    border-radius: 6px;
    background: none;
    color: var(--muted);
    cursor: pointer;
  }

  .pg[aria-pressed='true'] {
    border-color: transparent;
    background: var(--accent-soft);
    color: var(--accent);
  }

  /* ── list ── */
  .list {
    flex: 1;
    min-height: 0;
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding-right: 2px;
    overscroll-behavior: contain;
  }

  .ind {
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding-left: 12px;
  }

  .gh,
  .sec {
    display: flex;
    align-items: center;
    gap: 4px;
    flex: none;
  }

  .gh {
    min-height: 34px;
  }

  .sec {
    min-height: 30px;
  }

  .fold {
    flex: 1;
    min-width: 0;
    align-self: stretch;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 4px;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--text);
    text-align: left;
    cursor: pointer;
  }

  .fold:hover {
    background: var(--hover);
  }

  .chev {
    display: inline-flex;
    color: var(--faint);
    transition: transform 0.12s;
  }

  .chev.open {
    transform: rotate(90deg);
  }

  .ttl {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 13px;
    font-weight: 600;
  }

  .ttl span {
    margin-left: 8px;
    font-size: 11.5px;
    font-weight: 400;
    color: var(--faint);
    font-variant-numeric: tabular-nums;
  }

  .nm {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--muted);
  }

  .nm span {
    margin-left: 8px;
    font-weight: 400;
    letter-spacing: 0;
    text-transform: none;
    color: var(--faint);
  }

  .gdot {
    width: 10px;
    height: 10px;
    flex: none;
    border-radius: 3px;
  }

  .gdot.none {
    border: 1.5px solid var(--line-strong);
  }

  .sc {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    flex: none;
    font-size: 12px;
    font-weight: 650;
    font-variant-numeric: tabular-nums;
  }

  .sc.crit {
    color: var(--err);
  }

  .sc.warn {
    color: var(--warn);
  }

  .sc.ok {
    color: var(--ok);
  }

  .sc :global(svg) {
    color: var(--sev-crit);
  }

  .sc.warn :global(svg) {
    color: var(--sev-warn);
  }

  .sc.ok :global(svg) {
    color: var(--sev-ok);
  }

  .row {
    position: relative;
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 46px;
    padding: 0 6px 0 7px;
    border-radius: 8px;
    background: var(--item);
    flex: none;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    flex: none;
    border-radius: 7px;
  }

  .chip.sm {
    width: 22px;
    height: 22px;
    border-radius: 6px;
  }

  .chip.critical {
    background: color-mix(in srgb, var(--sev-crit) 17%, var(--item));
    color: var(--sev-crit);
  }

  .chip.warning {
    background: color-mix(in srgb, var(--sev-warn) 17%, var(--item));
    color: var(--sev-warn);
  }

  .chip.recovered {
    background: color-mix(in srgb, var(--sev-ok) 17%, var(--item));
    color: var(--sev-ok);
  }

  .mid {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
    line-height: 1.2;
  }

  .rl {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 11.5px;
    font-weight: 500;
    color: var(--muted);
  }

  .rl.subj {
    font-size: 12px;
    font-weight: 600;
    color: var(--text);
  }

  .rl.subj span {
    margin-left: 6px;
    font-size: 11px;
    font-weight: 400;
    color: var(--faint);
  }

  .val {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 14px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  .val.critical {
    color: var(--err);
  }

  .val.warning {
    color: var(--warn);
  }

  .val.recovered {
    color: var(--ok);
  }

  .tm {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 2px;
    flex: none;
    line-height: 1.2;
    font-variant-numeric: tabular-nums;
  }

  .tm b {
    font-size: 12px;
    font-weight: 600;
  }

  .tm span {
    font-size: 11px;
    color: var(--faint);
  }

  .ack {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    flex: none;
    padding: 0;
    border: 1px solid var(--accent-line);
    border-radius: 7px;
    background: none;
    color: var(--accent);
    cursor: pointer;
  }

  .ack:hover {
    background: var(--accent-soft);
  }

  .ackh {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 30px;
    margin-top: 6px;
    padding: 0 4px;
    border: 0;
    border-top: 1px solid var(--line);
    background: none;
    font-size: 12px;
    font-weight: 600;
    color: var(--muted);
    text-align: left;
    cursor: pointer;
    flex: none;
  }

  .ackl {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 22px;
    padding: 0 8px;
    font-size: 12px;
    color: var(--muted);
    flex: none;
  }

  .ackl .tx {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ackl b {
    font-weight: 600;
  }

  .ackl .d {
    font-size: 11px;
    color: var(--faint);
    font-variant-numeric: tabular-nums;
  }

  .empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 20px 16px 22px;
    text-align: center;
    flex: none;
  }

  .empty b {
    font-size: 13px;
  }

  .empty > span:last-child {
    max-width: 34ch;
    font-size: 12px;
    color: var(--faint);
  }

  .nothing {
    margin: 0;
    padding: 16px;
    text-align: center;
    font-size: 12px;
    color: var(--faint);
  }

  .vnote {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 4px;
    padding: 8px 10px;
    border-radius: 8px;
    background: var(--hover);
    font-size: 12px;
    color: var(--muted);
    flex: none;
  }

  .vnote span {
    flex: 1;
  }

  .small {
    height: 26px;
    padding: 0 10px;
    border: 1px solid var(--line-strong);
    border-radius: 6px;
    background: var(--surface);
    font-size: 12.5px;
    font-weight: 550;
    white-space: nowrap;
    cursor: pointer;
  }

  /* ── touch: every target 44 px or more, labels beside icons ── */
  .touch {
    gap: 0;
    padding: 0;
  }

  .touch .head {
    gap: 8px;
    padding: 8px 12px 8px 18px;
  }

  .touch .title {
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
  }

  .touch h2 {
    font-size: 19px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }

  .touch .sub {
    font-size: 13px;
    color: var(--muted);
  }

  .touch .ib {
    min-width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--hover);
    color: var(--text);
  }

  .touch .ib.text {
    padding: 0 12px;
    background: none;
    color: var(--accent);
    font-size: 14px;
    font-weight: 600;
  }

  .touch .tools {
    flex-direction: column;
    flex-wrap: nowrap;
    gap: 8px;
    padding: 0 12px 10px;
  }

  .touch .seg.sev,
  .touch .seg.grp {
    display: grid;
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: 3px;
    padding: 3px;
    border: 0;
    border-radius: 14px;
    background: var(--hover);
  }

  .touch .seg.grp {
    flex: 1;
    min-width: 0;
  }

  .touch .seg.sev button,
  .touch .seg.grp button {
    justify-content: center;
    gap: 7px;
    min-width: 0;
    height: 42px;
    padding: 0 6px;
    border: 0;
    border-radius: 11px;
    background: none;
    font-size: 14px;
    font-weight: 600;
    color: var(--muted);
  }

  .touch .seg.grp button {
    height: 38px;
    font-size: 13.5px;
  }

  .touch .seg.grp button + button {
    border-left: 0;
  }

  .touch .seg.sev b {
    font-weight: 700;
    color: var(--text);
  }

  .touch .seg.sev button[aria-pressed='true'],
  .touch .seg.grp button[aria-pressed='true'] {
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  .touch .seg.sev button[aria-pressed='true'] b {
    color: var(--text);
  }

  .touch .opts {
    gap: 8px;
  }

  .touch .pg {
    width: auto;
    min-width: 44px;
    height: 44px;
    padding: 0 12px;
    border: 0;
    border-radius: 12px;
    background: var(--hover);
    color: var(--text);
    font-size: 14px;
    font-weight: 600;
  }

  .touch .pg[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  .touch .list {
    gap: 6px;
    padding: 6px 12px 12px;
    border-top: 1px solid var(--line);
  }

  .touch .ind {
    gap: 6px;
    padding-left: 14px;
  }

  .touch .gh {
    min-height: 54px;
    gap: 8px;
  }

  .touch .sec {
    min-height: 48px;
    gap: 8px;
  }

  .touch .fold {
    gap: 10px;
    padding: 0 6px;
    border-radius: 12px;
  }

  .touch .ttl {
    font-size: 16px;
    font-weight: 650;
  }

  .touch .ttl span {
    display: block;
    margin: 2px 0 0;
    font-size: 13px;
  }

  .touch .nm {
    font-size: 13px;
  }

  /* The projector count under the group's name, like a group header's note. */
  .touch .nm span {
    display: block;
    margin: 2px 0 0;
    font-size: 12.5px;
  }

  .touch .gdot {
    width: 14px;
    height: 14px;
    border-radius: 4px;
  }

  .touch .sc {
    font-size: 15px;
  }

  .touch .row {
    gap: 12px;
    min-height: 68px;
    padding: 8px 8px 8px 14px;
    border-radius: 14px;
    overflow: hidden;
  }

  .touch .row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 5px;
  }

  .touch .row.critical::before {
    background: var(--sev-crit);
  }

  .touch .row.warning::before {
    background: var(--sev-warn);
  }

  .touch .row.recovered::before {
    background: var(--sev-ok);
  }

  .touch .chip {
    width: 36px;
    height: 36px;
    border-radius: 10px;
  }

  .touch .mid {
    line-height: 1.25;
  }

  .touch .rl {
    font-size: 13px;
    font-weight: 550;
  }

  .touch .rl.subj {
    font-size: 14px;
    font-weight: 650;
  }

  .touch .rl.subj span {
    font-size: 12.5px;
  }

  /* Large, and on two rows rather than cut on a narrow phone. */
  .touch .val {
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    white-space: normal;
    font-size: 17px;
    font-weight: 700;
  }

  .touch .tm {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 12.5px;
    color: var(--muted);
  }

  .touch .tm b {
    font-size: inherit;
    color: var(--text);
    font-weight: 650;
  }

  .touch .ack {
    width: 52px;
    height: 52px;
    border: 2px solid var(--accent-line);
    border-radius: 14px;
  }

  .touch .ack.many {
    width: 48px;
    height: 48px;
    border-radius: 12px;
  }

  .touch .ackh {
    gap: 10px;
    min-height: 52px;
    padding: 0 6px;
    font-size: 15px;
    font-weight: 650;
  }

  .touch .ackl {
    gap: 10px;
    min-height: 44px;
    padding: 6px 10px;
    font-size: 14px;
  }

  /* A phone's width: the whole line, wrapped rather than cut. */
  .touch .ackl .tx {
    white-space: normal;
    line-height: 1.3;
  }

  .touch .ackl b {
    color: var(--text);
    font-weight: 650;
  }

  .touch .ackl .d {
    font-size: 12.5px;
  }

  .touch .empty {
    gap: 8px;
    padding: 28px 20px;
  }

  .touch .empty b {
    font-size: 16px;
  }

  .touch .empty > span:last-child {
    max-width: 32ch;
    font-size: 14px;
  }

  .touch .nothing {
    font-size: 14px;
  }

  .foot {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px 14px;
    border-top: 1px solid var(--line);
    background: var(--surface);
    flex: none;
  }

  .fbtn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    min-width: 52px;
    height: 52px;
    padding: 0 16px;
    border: 0;
    border-radius: 14px;
    background: var(--hover);
    color: var(--text);
    font-size: 15px;
    font-weight: 600;
    white-space: nowrap;
    cursor: pointer;
    flex: none;
  }

  .fbtn[aria-pressed='true'] {
    background: var(--accent-soft);
    color: var(--accent);
  }

  .fbtn.primary {
    flex: 1;
    min-width: 0;
    background: var(--accent);
    color: var(--on-accent);
  }

  .fbtn.primary.short {
    flex: none;
  }

  .vtext {
    flex: 1;
    min-width: 0;
    font-size: 13px;
    line-height: 1.3;
    color: var(--muted);
  }

  /* A phone held sideways: the segments share one row, short labels. */
  .narrow .head {
    padding: 6px 10px 4px 16px;
  }

  .narrow h2 {
    font-size: 17px;
  }

  .narrow .tools {
    flex-direction: row;
    padding-bottom: 6px;
  }

  .narrow .seg.sev {
    flex: 1;
  }

  .narrow .seg.sev button,
  .narrow .seg.grp button {
    height: 38px;
  }

  .narrow .foot {
    padding: 6px 10px 8px;
  }

  .narrow .fbtn {
    height: 46px;
  }

  .narrow .row {
    min-height: 60px;
  }
</style>
