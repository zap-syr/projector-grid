<script lang="ts">
  import ProjectorIcon from './lib/components/shell/ProjectorIcon.svelte';
</script>

<div class="app">
  <header class="hdr">
    <div class="logo"><ProjectorIcon /></div>
    <div class="title">
      <b>Projector Grid</b>
      <span>Web Monitor</span>
    </div>
  </header>
  <main class="empty">
    <p>Connected to the app. Monitoring is not available yet.</p>
  </main>
</div>

<style>
  .app {
    min-height: 100%;
    display: grid;
    grid-template-rows: auto 1fr;
  }

  .hdr {
    display: flex;
    align-items: center;
    gap: 12px;
    height: 60px;
    padding: 0 16px;
    background: var(--surface);
    border-bottom: 1px solid var(--line);
  }

  .logo {
    width: 32px;
    height: 32px;
    border-radius: 9px;
    background: var(--accent);
    color: var(--on-accent);
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
  }

  .title {
    display: flex;
    flex-direction: column;
    line-height: 1.2;
  }

  .title b {
    font-size: 15px;
    font-weight: 650;
    letter-spacing: -0.01em;
  }

  .title span {
    font-size: 12px;
    color: var(--faint);
  }

  .empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px 16px;
    color: var(--faint);
    text-align: center;
  }
</style>
