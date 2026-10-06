<script lang="ts">
  import AlertPill from './lib/components/alerts/AlertPill.svelte';
  import AlertsPanel from './lib/components/alerts/AlertsPanel.svelte';
  import AlertsRail from './lib/components/alerts/AlertsRail.svelte';
  import AlertToast from './lib/components/alerts/AlertToast.svelte';
  import AlignScreen from './lib/components/alignment/AlignScreen.svelte';
  import Banner from './lib/components/alignment/Banner.svelte';
  import ControlPanel from './lib/components/control/ControlPanel.svelte';
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
  import { alerts } from './lib/state/alerts.svelte';
  import { alignment } from './lib/state/alignment.svelte';
  import { config } from './lib/state/config.svelte';
  import { device } from './lib/state/device.svelte';
  import { listMode } from './lib/state/listMode.svelte';
  import { live } from './lib/state/live.svelte';
  import { panel } from './lib/state/panel.svelte';
  import { preview } from './lib/state/preview.svelte';
  import { selection } from './lib/state/selection.svelte';
  import { session } from './lib/state/session.svelte';
  import { tableLayout } from './lib/state/tableLayout.svelte';

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
      {@const sidePanel = operator && panel.open && !sheetLayout}
      <div class="work" class:op={sidePanel} class:rail={!sheetLayout}>
        <div class="main">
          <div class="top">
            <Toolbar config={config.value} layout={tableLayout.value} {operator} />
            {#if sheetLayout}
              <AlertPill />
            {/if}
          </div>
          <div class="table">
            {#if listMode.value === 'cards'}
              <CardList config={config.value} layout={tableLayout.value} {operator} />
            {:else if listMode.value === 'map'}
              <MapView config={config.value} {operator} />
            {:else}
              <DataTable config={config.value} layout={tableLayout.value} {operator} />
            {/if}
          </div>
          {#if sheetLayout && operator && selection.ids.size > 0}
            <SelectBar />
          {/if}
        </div>
        {#if sidePanel}
          <ControlPanel config={config.value} onclose={() => panel.toggle()} />
        {/if}
        {#if !sheetLayout}
          <AlertsRail touch={device.touch} />
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
    {/if}
  </div>
  {#if device.control !== 'side' && alerts.sheet}
    <Sheet
      label="Alerts"
      placement={device.control === 'right' ? 'right' : 'bottom'}
      wide
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

  .work {
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    min-height: 0;
  }

  .work.op {
    grid-template-columns: minmax(0, 1fr) 340px;
  }

  /* The alerts rail at the far right; the drawer opens over everything left of it. */
  .work.rail {
    position: relative;
    grid-template-columns: minmax(0, 1fr) 52px;
  }

  .work.rail.op {
    grid-template-columns: minmax(0, 1fr) 340px 52px;
  }

  .drawer {
    position: absolute;
    top: 0;
    bottom: 0;
    right: 52px;
    z-index: 20;
    width: min(404px, calc(100% - 52px));
    border-left: 1px solid var(--line);
    background: var(--surface);
    box-shadow: var(--sh-3);
    animation: slide 0.18s ease-out;
  }

  .drawer.touch {
    width: min(440px, calc(100% - 52px));
  }

  @keyframes slide {
    from {
      transform: translateX(16px);
      opacity: 0;
    }
  }

  .top {
    min-width: 0;
  }

  .main {
    display: grid;
    /* toolbar · list · the phone's select bar */
    grid-template-rows: auto 1fr auto;
    /* Same 0 floor as .app, or a wide toolbar / table stretches the column
       under the Control panel. */
    grid-template-columns: minmax(0, 1fr);
    min-width: 0;
    min-height: 0;
    overflow: hidden;
  }

  .table {
    min-height: 0;
    min-width: 0;
  }
</style>
