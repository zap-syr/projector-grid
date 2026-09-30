<script lang="ts">
  import ControlPanel from './lib/components/control/ControlPanel.svelte';
  import ConfirmDialog from './lib/components/shell/ConfirmDialog.svelte';
  import Header from './lib/components/shell/Header.svelte';
  import Login from './lib/components/shell/Login.svelte';
  import Toast from './lib/components/shell/Toast.svelte';
  import Toolbar from './lib/components/shell/Toolbar.svelte';
  import DataTable from './lib/components/table/DataTable.svelte';
  import { config } from './lib/state/config.svelte';
  import { live } from './lib/state/live.svelte';
  import { panel } from './lib/state/panel.svelte';
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
    return () => live.disconnect();
  });

  // Locking (or losing control) drops the selection with the controls.
  $effect(() => {
    if (!operator) selection.clear();
  });
</script>

{#if session.status === 'signedIn'}
  <div class="app">
    <Header />
    {#if config.value && tableLayout.value}
      <div class="work" class:op={operator && panel.open}>
        <div class="main">
          <Toolbar config={config.value} layout={tableLayout.value} {operator} />
          <div class="table">
            <DataTable config={config.value} layout={tableLayout.value} {operator} />
          </div>
        </div>
        {#if operator && panel.open}
          <ControlPanel config={config.value} />
        {/if}
      </div>
    {/if}
  </div>
  <ConfirmDialog />
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

  .work {
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    min-height: 0;
  }

  .work.op {
    grid-template-columns: minmax(0, 1fr) 340px;
  }

  .main {
    display: grid;
    grid-template-rows: auto 1fr;
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
