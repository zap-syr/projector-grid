<script lang="ts">
  import type { Config, Projector } from './lib/api/types';
  import AlertPill from './lib/components/alerts/AlertPill.svelte';
  import AlertsPanel from './lib/components/alerts/AlertsPanel.svelte';
  import AlertsRail from './lib/components/alerts/AlertsRail.svelte';
  import AlertToast from './lib/components/alerts/AlertToast.svelte';
  import AlignScreen from './lib/components/alignment/AlignScreen.svelte';
  import Banner from './lib/components/alignment/Banner.svelte';
  import ControlPanel from './lib/components/control/ControlPanel.svelte';
  import ProjectorDetails from './lib/components/details/ProjectorDetails.svelte';
  import Icon from './lib/components/Icon.svelte';
  import MapView from './lib/components/map/MapView.svelte';
  import CardList from './lib/components/phone/CardList.svelte';
  import PreviewDialog from './lib/components/preview/PreviewDialog.svelte';
  import SelectBar from './lib/components/phone/SelectBar.svelte';
  import Sheet from './lib/components/phone/Sheet.svelte';
  import ConfirmDialog from './lib/components/shell/ConfirmDialog.svelte';
  import Header from './lib/components/shell/Header.svelte';
  import Login from './lib/components/shell/Login.svelte';
  import Toast from './lib/components/shell/Toast.svelte';
  import Toolbar from './lib/components/shell/Toolbar.svelte';
  import DataTable from './lib/components/table/DataTable.svelte';
  import { setFavicon } from './lib/favicon';
  import { testPatternLabel } from './lib/logic/cells';
  import { alerts } from './lib/state/alerts.svelte';
  import { alignment } from './lib/state/alignment.svelte';
  import { config } from './lib/state/config.svelte';
  import { details } from './lib/state/details.svelte';
  import { device } from './lib/state/device.svelte';
  import { listMode } from './lib/state/listMode.svelte';
  import { live } from './lib/state/live.svelte';
  import { panel } from './lib/state/panel.svelte';
  import { preview } from './lib/state/preview.svelte';
  import { selection } from './lib/state/selection.svelte';
  import { session } from './lib/state/session.svelte';
  import { tableLayout } from './lib/state/tableLayout.svelte';
  // Applies the stored theme before the first paint of the page.
  import './lib/state/theme.svelte';

  void session.refresh();

  const operator = $derived(session.role === 'operator');

  // Signed in → load the config and open the event stream; signed out → close it.
  $effect(() => {
    if (session.status !== 'signedIn') return;
    void config.load().then(() => {
      if (config.value) tableLayout.init(config.value);
    });
    live.connect();
    return () => {
      live.disconnect();
      preview.close();
    };
  });

  // Locking (or losing control) drops the selection with the controls.
  $effect(() => {
    if (!operator) selection.clear();
  });

  // The Control sheet only exists on touch layouts, for an operator; the
  // Alignment screen has its own lens block.
  $effect(() => {
    if (!operator || device.control === 'side' || aligning) panel.sheet = false;
  });

  const aligning = $derived(alignment.active || alignment.busy);

  // The Map has its own popover, and in Alignment mode the Control's place is the lens.
  $effect(() => {
    if (listMode.value === 'map' || aligning) details.close();
  });

  const groupMap = $derived(new Map(live.groups.map((g) => [g.id, g])));
  let selectBarH = $state(0);
  const patternLabels = $derived(
    new Map((config.value?.testPatterns ?? []).map((t) => [t.code, t.label])),
  );
  const patternLabel = (code: string) => testPatternLabel(code, patternLabels);

  // A sheet belongs to touch layouts; turning a tablet sideways hands over to the rail.
  $effect(() => {
    if (device.control === 'side') alerts.sheet = false;
  });

  // The tab carries the unacknowledged count, the favicon a dot, so a page in
  // a background tab still says something needs a look.
  $effect(() => {
    const n = session.status === 'signedIn' ? alerts.unacknowledged : 0;
    document.title =
      n > 0 ? `(${n}) ${session.projectName}` : session.projectName || 'Projector Grid';
    setFavicon(n > 0);
  });

  // Alignment mode: the selection is the focused projector, as in the app,
  // so the Control panel's lens acts on it. Anything else snaps back.
  $effect(() => {
    const focused = alignment.focused?.id;
    if (!operator || !focused) return;
    if (selection.ids.size !== 1 || !selection.ids.has(focused)) {
      selection.set(new Set([focused]));
    }
  });

  const inField = (e: KeyboardEvent) =>
    e.target instanceof HTMLInputElement ||
    e.target instanceof HTMLTextAreaElement ||
    e.target instanceof HTMLSelectElement;

  /** The app's Alignment keys: `,` / `.` (or `<` / `>`) step, `A` Show all, `N` Neighbours. */
  function alignmentKeys(e: KeyboardEvent) {
    if (!operator || !alignment.active || inField(e) || e.ctrlKey || e.metaKey || e.altKey) return;
    const key = e.key.toLowerCase();
    if (key === ',' || key === '<') alignment.prev();
    else if (key === '.' || key === '>') alignment.next();
    else if (key === 'a') alignment.toggle('showAll');
    else if (key === 'n') alignment.toggle('neighbours');
    else return;
    e.preventDefault();
  }
</script>

<svelte:window onkeydown={alignmentKeys} />

{#if session.status === 'signedIn'}
  <div class="app" class:aligning={aligning && device.control === 'side'}>
    <Header {operator} />
    {#if config.value && tableLayout.value && aligning && device.control === 'side'}
      <Banner config={config.value} {operator} />
    {/if}
    {#if config.value && tableLayout.value && aligning && device.control !== 'side'}
      <div class="table">
        <AlignScreen config={config.value} {operator} />
      </div>
    {:else if config.value && tableLayout.value}
      {@const sheetLayout = device.control !== 'side'}
      {@const control = operator && panel.open && !sheetLayout}
      {@const sideDetails = details.projector && !sheetLayout ? details.projector : undefined}
      {@const overList = sideDetails !== undefined && !control}
      {@const selectBar = sheetLayout && operator && selection.ids.size > 0}
      {@const overMap = listMode.value === 'map'}
      <!-- The toolbar runs the whole width above the list and the side panel,
           so opening Control or the details never moves its buttons; the
           alerts rail keeps the full height (owner, 2026-10-22). -->
      <div class="work" class:op={control} class:rail={!sheetLayout}>
        <div class="top">
          <Toolbar config={config.value} layout={tableLayout.value} {operator} />
          {#if sheetLayout}
            <AlertPill />
          {/if}
        </div>
        <div class="list" style:--select-bar={selectBar && overMap ? `${selectBarH}px` : '0px'}>
          {#if listMode.value === 'cards'}
            <CardList config={config.value} layout={tableLayout.value} {operator} />
          {:else if listMode.value === 'map'}
            <MapView config={config.value} {operator} />
          {:else}
            <DataTable config={config.value} layout={tableLayout.value} {operator} />
          {/if}
          {#if selectBar && overMap}
            <!-- Over the Map, so its fitted tiles don't move when the first
                 projector is selected; only the zoom buttons step up. -->
            <div class="selectbar over" bind:offsetHeight={selectBarH}>
              <SelectBar />
            </div>
          {/if}
          {#if sideDetails && overList}
            {@render detailsPanel(sideDetails, config.value, false)}
          {/if}
        </div>
        {#if selectBar && !overMap}
          <div class="selectbar">
            <SelectBar />
          </div>
        {/if}
        {#if sideDetails && !overList}
          <!-- In the Control panel's place at its width, so nothing reflows. -->
          {@render detailsPanel(sideDetails, config.value, true)}
        {:else if control}
          <div class="side">
            <ControlPanel config={config.value} onclose={() => panel.toggle()} />
          </div>
        {/if}
        {#if !sheetLayout}
          <div class="railc"><AlertsRail touch={device.touch} /></div>
          {#if alerts.prefs.drawer}
            <!-- Over the content, so the table and Control panel don't reflow. -->
            <aside class="drawer" class:touch={device.touch}>
              <AlertsPanel
                {operator}
                touch={device.touch}
                onclose={() => alerts.setPref('drawer', false)}
              />
            </aside>
          {/if}
        {/if}
      </div>
      {#snippet detailsPanel(p: Projector, cfg: Config, inPlace: boolean)}
        <aside class="slot" class:over={!inPlace} aria-label="Projector {p.ip}">
          {#if inPlace}
            <div class="back">
              <button onclick={() => details.close()}><Icon name="left" size={18} />Control</button>
              <em
                >{selection.ids.size > 0
                  ? `${selection.ids.size} selected`
                  : 'No projectors selected'}</em
              >
            </div>
          {/if}
          <ProjectorDetails
            {p}
            config={cfg}
            groups={groupMap}
            {patternLabel}
            placement="panel"
            touch={device.touch}
            onclose={() => details.close()}
            onpreview={() => preview.open(details.order, p.id)}
          />
        </aside>
      {/snippet}
      {#if device.control !== 'side' && operator && panel.sheet}
        <Sheet label="Control" placement={device.control} onclose={() => (panel.sheet = false)}>
          <ControlPanel
            config={config.value}
            sheet
            columns={device.control === 'bottom' && !device.phone}
            onclose={() => (panel.sheet = false)}
          />
        </Sheet>
      {/if}
      {#if device.control !== 'side' && details.projector}
        {@const p = details.projector}
        <Sheet label="Projector {p.ip}" placement={device.control} onclose={() => details.close()}>
          <ProjectorDetails
            {p}
            config={config.value}
            groups={groupMap}
            {patternLabel}
            placement="sheet"
            columns={device.control === 'bottom' && !device.phone}
            touch
            onclose={() => details.close()}
            onpreview={() => preview.open(details.order, p.id)}
          />
        </Sheet>
      {/if}
    {/if}
  </div>
  {#if device.control !== 'side' && alerts.sheet}
    <Sheet
      label="Alerts"
      placement={device.control === 'right' ? 'right' : 'bottom'}
      wide
      fixed
      onclose={() => (alerts.sheet = false)}
    >
      <AlertsPanel
        {operator}
        touch
        narrow={device.control === 'right'}
        onclose={() => (alerts.sheet = false)}
      />
    </Sheet>
  {/if}
  {#if preview.id && config.value}
    <PreviewDialog config={config.value} {operator} />
  {/if}
  <ConfirmDialog />
  <AlertToast />
  <Toast />
{:else if session.status === 'signedOut'}
  <Login />
{/if}

<style>
  .app {
    height: 100%;
    display: grid;
    grid-template-rows: auto 1fr;
    /* The table sizes itself from the scroller's width; without the 0 floor
       the column would grow to the table and the scroller would never shrink. */
    grid-template-columns: minmax(0, 1fr);
    min-height: 0;
  }

  /* Header · Alignment banner · the rest. */
  .app.aligning {
    grid-template-rows: auto auto 1fr;
  }

  /* toolbar over list and side panel · the phone's select bar · the rail
     on the right the whole height. The 0 floors keep a wide toolbar or table
     from stretching the columns. */
  .work {
    position: relative;
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    grid-template-rows: auto minmax(0, 1fr) auto;
    grid-template-areas: 'top' 'list' 'bar';
    min-height: 0;
  }

  .work.op {
    grid-template-columns: minmax(0, 1fr) 344px;
    grid-template-areas: 'top top' 'list side' 'bar side';
  }

  .work.rail {
    grid-template-columns: minmax(0, 1fr) 52px;
    grid-template-areas: 'top rail' 'list rail' 'bar rail';
  }

  .work.rail.op {
    grid-template-columns: minmax(0, 1fr) 344px 52px;
    grid-template-areas: 'top top rail' 'list side rail' 'bar side rail';
  }

  .top {
    grid-area: top;
    min-width: 0;
  }

  .list {
    grid-area: list;
    position: relative;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
  }

  .selectbar {
    grid-area: bar;
  }

  .side,
  .slot {
    grid-area: side;
    min-height: 0;
    display: flex;
  }

  .railc {
    grid-area: rail;
    display: flex;
    min-height: 0;
  }

  .railc > :global(*) {
    flex: 1;
  }

  .slot {
    position: relative;
    z-index: 5;
    display: flex;
    flex-direction: column;
    background: var(--surface);
    border-left: 1px solid var(--line);
  }

  /* No Control beside the list (a viewer, or Control hidden): the details
     open over the table or the cards, as the app's projector panel does, so
     neither reflows (owner, 2026-10-22). Under the toolbar, beside the
     alerts rail, under its drawer. */
  .slot.over {
    position: absolute;
    top: 0;
    bottom: 0;
    right: 0;
    z-index: 15;
    width: 344px;
    box-shadow: var(--sh-3);
    animation: slide 0.18s ease-out;
  }

  /* ‹ Control: back to the panel, the selection untouched. */
  .back {
    height: 44px;
    flex: none;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px 0 8px;
    border-bottom: 1px solid var(--line);
  }

  .back button {
    height: 32px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 0 10px 0 6px;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--accent);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  @media (hover: hover) {
    .back button:hover {
      background: var(--accent-soft);
    }
  }

  .back em {
    margin-left: auto;
    color: var(--faint);
    font-size: 11.5px;
    font-style: normal;
    font-weight: 500;
  }

  .slot :global(.details) {
    flex: 1;
  }

  /* The drawer opens over everything left of the alerts rail. */
  /* The 420 px Active alerts panel beside the rail, floating as the boards draw it. */
  .drawer {
    position: absolute;
    top: 8px;
    bottom: 8px;
    right: 60px;
    z-index: 20;
    width: min(420px, calc(100% - 68px));
    overflow: hidden;
    border: 1px solid var(--line-strong);
    border-radius: 14px;
    background: var(--menu);
    box-shadow: var(--sh-3);
    animation: slide 0.18s ease-out;
  }

  .drawer.touch {
    width: min(440px, calc(100% - 68px));
  }

  @keyframes slide {
    from {
      transform: translateX(16px);
      opacity: 0;
    }
  }

  .selectbar.over {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 10;
  }

  .table {
    min-height: 0;
    min-width: 0;
  }
</style>
