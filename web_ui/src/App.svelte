<script lang="ts">
  import Header from './lib/components/shell/Header.svelte';
  import Login from './lib/components/shell/Login.svelte';
  import InterimTable from './lib/components/table/InterimTable.svelte';
  import { config } from './lib/state/config.svelte';
  import { live } from './lib/state/live.svelte';
  import { session } from './lib/state/session.svelte';

  void session.refresh();

  // Signed in → load the config and open the event stream; signed out → close it.
  $effect(() => {
    if (session.status !== 'signedIn') return;
    void config.load();
    live.connect();
    return () => live.disconnect();
  });
</script>

{#if session.status === 'signedIn'}
  <div class="app">
    <Header />
    {#if config.value}
      <InterimTable config={config.value} />
    {/if}
  </div>
{:else if session.status === 'signedOut'}
  <Login />
{/if}

<style>
  .app {
    height: 100%;
    display: grid;
    grid-template-rows: auto 1fr;
    min-height: 0;
  }
</style>
