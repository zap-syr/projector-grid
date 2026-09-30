<script lang="ts">
  import Header from './lib/components/shell/Header.svelte';
  import Login from './lib/components/shell/Login.svelte';
  import Toolbar from './lib/components/shell/Toolbar.svelte';
  import DataTable from './lib/components/table/DataTable.svelte';
  import { config } from './lib/state/config.svelte';
  import { live } from './lib/state/live.svelte';
  import { session } from './lib/state/session.svelte';
  import { tableLayout } from './lib/state/tableLayout.svelte';

  void session.refresh();

  // Signed in → load the config and open the event stream; signed out → close it.
  $effect(() => {
    if (session.status !== 'signedIn') return;
    void config.load().then(() => {
      if (config.value) tableLayout.init(config.value);
    });
    live.connect();
    return () => live.disconnect();
  });
</script>

{#if session.status === 'signedIn'}
  <div class="app">
    <Header />
    {#if config.value && tableLayout.value}
      <Toolbar config={config.value} layout={tableLayout.value} />
      <main class="body">
        <DataTable config={config.value} layout={tableLayout.value} />
      </main>
    {/if}
  </div>
{:else if session.status === 'signedOut'}
  <Login />
{/if}

<style>
  .app {
    height: 100%;
    display: grid;
    grid-template-rows: auto auto 1fr;
    /* The table sizes itself from the scroller's width; without the 0 floor
       the column would grow to the table and the scroller would never shrink. */
    grid-template-columns: minmax(0, 1fr);
    min-height: 0;
  }

  .body {
    min-height: 0;
    min-width: 0;
  }
</style>
