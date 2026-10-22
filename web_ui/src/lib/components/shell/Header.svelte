<!--
  The page's header (shell canvas, *Desktop header…*, *Phone header…*).
  Desktop and tablets: logo, project over *Projector Grid*, the Live pill;
  the operator's Alignment toggle and Refresh, then the role pill whose menu
  holds Lock control, Theme and Sign out. A viewer gets *Unlock control*
  (while control is allowed) and a menu with Theme and Sign out. Phones:
  name over Live, the Alignment icon or the viewer's Unlock icon, the bell
  and ⋮ with the rest.
-->
<script lang="ts">
  import { api, ApiError } from '../../api/client';
  import { alerts } from '../../state/alerts.svelte';
  import { alignment } from '../../state/alignment.svelte';
  import { control } from '../../state/control.svelte';
  import { device } from '../../state/device.svelte';
  import { live } from '../../state/live.svelte';
  import { session } from '../../state/session.svelte';
  import { theme, type ThemeChoice } from '../../state/theme.svelte';
  import AlertBell from '../alerts/AlertBell.svelte';
  import Icon, { type IconName } from '../Icon.svelte';
  import AppLogo from './AppLogo.svelte';
  import UnlockDialog from './UnlockDialog.svelte';

  let { operator }: { operator: boolean } = $props();

  let unlocking = $state(false);
  let menuOpen = $state(false);
  let menuWrap = $state<HTMLElement>();
  /** A refresh request is out: the button spins and ignores more presses. */
  let refreshing = $state(false);
  /** Briefly a green check after a finished poll, in place of a toast. */
  let refreshed = $state(false);
  let refreshedTimer: ReturnType<typeof setTimeout> | undefined;

  /** A phone either way up: the compact bar with ⋮. */
  const phone = $derived(device.phone || device.short);
  /** Touch layouts without the rail open the alerts from the header. */
  const bell = $derived(device.control !== 'side');
  const role = $derived(session.role === 'operator' ? 'Operator' : 'Viewer');

  const liveText = $derived(
    live.connection === 'live'
      ? 'Live'
      : live.connection === 'reconnecting'
        ? 'Reconnecting'
        : 'Connecting',
  );

  const THEMES: { value: ThemeChoice; icon: IconName; label: string }[] = [
    { value: 'system', icon: 'monitor', label: 'Same as the device' },
    { value: 'light', icon: 'sun', label: 'Light' },
    { value: 'dark', icon: 'moon', label: 'Dark' },
  ];

  async function refresh(fromMenu = false) {
    clearTimeout(refreshedTimer);
    refreshed = false;
    refreshing = true;
    try {
      await api.refresh();
      // The phone's menu closes on the tap, so it confirms with a toast.
      if (fromMenu) control.notify({ text: 'Status refreshed', ok: true });
      else {
        refreshed = true;
        refreshedTimer = setTimeout(() => (refreshed = false), 1500);
      }
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      // 403/404: control was locked or switched off meanwhile.
      control.notify({ text: 'Not refreshed, control is locked', ok: false });
    } finally {
      refreshing = false;
    }
  }

  function run(action: () => void) {
    menuOpen = false;
    action();
  }
</script>

<svelte:window
  onpointerdown={(e) => {
    if (menuOpen && !menuWrap?.contains(e.target as Node)) menuOpen = false;
  }}
  onkeydowncapture={(e) => {
    // Before the toolbar's Esc, which would clear the selection.
    if (menuOpen && e.key === 'Escape') {
      e.preventDefault();
      menuOpen = false;
    }
  }}
/>

{#snippet menu()}
  <div class="menu" role="menu" aria-label={phone ? 'More' : 'Session'}>
    <div class="mh">
      <span class="tile"><Icon name={operator ? 'unlock' : 'lock'} size={16} /></span>
      <div>
        <b>{role}</b>
        <small>{operator ? 'Control unlocked in this browser' : 'View only'}</small>
      </div>
    </div>
    {#if phone && operator}
      <button
        class="mi"
        role="menuitem"
        disabled={refreshing}
        onclick={() => run(() => refresh(true))}
        ><Icon name="refresh" size={18} />Refresh status</button
      >
    {/if}
    {#if operator}
      <button class="mi" role="menuitem" onclick={() => run(() => session.lock())}
        ><Icon name="lock" size={18} />Lock control</button
      >
    {/if}
    <div class="hr"></div>
    <div class="trow">
      <span class="tl"><Icon name="contrast" size={18} />Theme</span>
      <div class="seg" role="radiogroup" aria-label="Theme">
        {#each THEMES as t (t.value)}
          <button
            role="radio"
            aria-checked={theme.value === t.value}
            aria-label={t.label}
            title={t.label}
            onclick={() => theme.set(t.value)}><Icon name={t.icon} size={phone ? 18 : 16} /></button
          >
        {/each}
      </div>
    </div>
    <div class="hr"></div>
    <button class="mi" role="menuitem" onclick={() => run(() => session.logout())}
      ><Icon name="logout" size={18} />Sign out</button
    >
  </div>
{/snippet}

<header class="hdr" class:phone class:touch={device.touch}>
  <AppLogo size={30} />
  <div class="proj">
    <b>{session.projectName}</b>
    {#if phone}
      <span class="lv" class:off={live.connection !== 'live'}><i></i>{liveText}</span>
    {:else}
      <span>Projector Grid</span>
    {/if}
  </div>
  {#if !phone}
    <span class="live" class:off={live.connection !== 'live'}><i></i>{liveText}</span>
  {/if}
  <span class="grow"></span>

  {#if operator}
    <!-- The app's Alignment mode toggle: the same session the app's banner drives. -->
    <button
      class="tool"
      class:ic={phone}
      aria-pressed={alignment.active}
      aria-label="Alignment"
      disabled={alignment.busy}
      title={alignment.active ? 'Exit Alignment mode' : 'Alignment mode'}
      onclick={() => (alignment.active ? alignment.exit() : alignment.enter())}
    >
      <Icon name="alignment" size={phone ? 22 : 18} />{#if !phone}Alignment{/if}
    </button>
    {#if !phone}
      <!-- The app's F5: polls every projector now, not just the selection. -->
      <button
        class="tool ic refresh"
        class:spin={refreshing}
        class:done={refreshed}
        disabled={refreshing}
        aria-label={refreshed ? 'Status refreshed' : 'Refresh status'}
        title={refreshing ? 'Polling projectors…' : 'Refresh status of all projectors'}
        onclick={() => refresh()}
      >
        <Icon name={refreshed ? 'checkmark' : 'refresh'} size={18} />
      </button>
    {/if}
  {:else if session.controlAllowed}
    <!-- The viewer's main action: a tonal button, an icon on a phone. -->
    <button
      class="unl"
      class:ic={phone}
      aria-label="Unlock control"
      title={phone ? 'Unlock control' : undefined}
      onclick={() => (unlocking = true)}
    >
      <Icon name="unlock" size={phone ? 22 : 18} />{#if !phone}Unlock control{/if}
    </button>
  {/if}

  {#if bell}
    <AlertBell pressed={alerts.sheet} touch={device.touch} onclick={() => (alerts.sheet = true)} />
  {/if}

  <div class="mw" bind:this={menuWrap}>
    {#if phone}
      <button
        class="tool ic"
        class:open={menuOpen}
        aria-label="More"
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        onclick={() => (menuOpen = !menuOpen)}><Icon name="more" size={22} /></button
      >
    {:else}
      <span class="vsep"></span>
      <button
        class="role"
        class:open={menuOpen}
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        onclick={() => (menuOpen = !menuOpen)}
      >
        <Icon name={operator ? 'unlock' : 'lock'} size={16} />{role}<span class="cv"
          ><Icon name={menuOpen ? 'up' : 'down'} size={15} /></span
        >
      </button>
    {/if}
    {#if menuOpen}{@render menu()}{/if}
  </div>
</header>

{#if unlocking}
  <UnlockDialog onclose={() => (unlocking = false)} />
{/if}

<style>
  .hdr {
    height: 56px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 12px 0 16px;
    background: var(--surface);
    border-bottom: 1px solid var(--line);
  }

  /* Touch: a 60 px bar with 44 px controls. */
  .hdr.touch {
    height: 60px;
  }

  .hdr.phone {
    gap: 4px;
    padding: 0 6px 0 14px;
  }

  .proj {
    display: flex;
    flex-direction: column;
    min-width: 0;
    line-height: 1.25;
  }

  .phone .proj {
    flex: 1;
    margin-left: 6px;
  }

  .proj b {
    overflow: hidden;
    font-size: 15px;
    font-weight: 600;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .proj span {
    color: var(--faint);
    font-size: 11.5px;
    font-weight: 500;
  }

  .grow {
    flex: 1;
  }

  .phone .grow {
    display: none;
  }

  /* Live, amber while the stream reconnects. */
  .live {
    height: 24px;
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 6px;
    margin-left: 6px;
    padding: 0 10px;
    border-radius: 999px;
    background: var(--ok-soft);
    color: var(--ok);
    font-size: 11.5px;
    font-weight: 600;
  }

  .live.off {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .live i,
  .lv i {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: currentColor;
  }

  .proj .lv {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    color: var(--ok);
    font-weight: 600;
  }

  .proj .lv.off {
    color: var(--warn);
  }

  .tool {
    height: 36px;
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 8px;
    padding: 0 12px 0 10px;
    border: 0;
    border-radius: 10px;
    background: none;
    color: var(--muted);
    font-size: 13.5px;
    font-weight: 500;
    white-space: nowrap;
    cursor: pointer;
  }

  .tool.ic {
    width: 38px;
    justify-content: center;
    padding: 0;
  }

  @media (hover: hover) {
    .tool:hover:not(:disabled) {
      background: var(--hover);
      color: var(--text);
    }
  }

  /* A pressed toggle in primaryContainer, as the app's toolbar. */
  .tool[aria-pressed='true'],
  .tool[aria-pressed='true']:hover {
    background: var(--pc);
    color: var(--on-pc);
  }

  .tool.open {
    background: var(--soft);
    color: var(--text);
  }

  .tool:disabled {
    cursor: progress;
  }

  .refresh.done :global(svg) {
    color: var(--ok);
  }

  .refresh.spin :global(svg) {
    animation: spin 0.9s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .refresh.spin :global(svg) {
      animation: none;
      opacity: 0.5;
    }
  }

  .unl {
    height: 34px;
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 8px;
    padding: 0 14px;
    border: 0;
    border-radius: 10px;
    background: var(--pc);
    color: var(--on-pc);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  .unl.ic {
    width: 44px;
    height: 44px;
    justify-content: center;
    padding: 0;
    border-radius: 12px;
  }

  .vsep {
    width: 1px;
    height: 24px;
    flex: none;
    margin: 0 4px;
    background: var(--line-strong);
  }

  .mw {
    position: relative;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .role {
    height: 34px;
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 0 8px 0 10px;
    border: 1px solid var(--line-strong);
    border-radius: 999px;
    background: none;
    color: var(--muted);
    font-size: 12.5px;
    font-weight: 600;
    cursor: pointer;
  }

  .role.open {
    background: var(--soft);
    color: var(--text);
  }

  .cv {
    display: flex;
    color: var(--faint);
  }

  /* Touch: 44 px controls in the 60 px bar. */
  .touch .tool,
  .touch .unl {
    height: 44px;
  }

  .touch .tool.ic {
    width: 44px;
    border-radius: 12px;
  }

  .touch .role {
    height: 44px;
    padding: 0 10px 0 12px;
  }

  /* The role menu, under the pill; on a phone under ⋮. */
  .menu {
    position: absolute;
    top: calc(100% + 8px);
    right: 0;
    z-index: 40;
    width: 280px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 6px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: var(--menu);
    box-shadow: var(--sh-3);
  }

  .phone .menu {
    width: 272px;
  }

  .mh {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 8px 10px;
  }

  .mh .tile {
    width: 30px;
    height: 30px;
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    border-radius: 9px;
    background: var(--soft);
    color: var(--accent);
  }

  .mh b {
    display: block;
    font-size: 14px;
    font-weight: 600;
  }

  .mh small {
    display: block;
    color: var(--muted);
    font-size: 12.5px;
  }

  .mi {
    width: 100%;
    height: 36px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 10px;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--text);
    font-size: 13.5px;
    text-align: left;
    cursor: pointer;
  }

  .mi :global(svg) {
    color: var(--muted);
  }

  @media (hover: hover) {
    .mi:hover {
      background: var(--hover);
    }
  }

  .mi:disabled {
    color: var(--disabled);
    cursor: progress;
  }

  .hr {
    height: 1px;
    margin: 4px 2px;
    background: var(--line);
  }

  .trow {
    height: 44px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 6px 4px 10px;
  }

  .tl {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 13.5px;
  }

  .tl :global(svg) {
    color: var(--muted);
  }

  .seg {
    display: flex;
    gap: 2px;
    padding: 3px;
    border: 1px solid var(--line);
    border-radius: 10px;
    background: var(--hover);
  }

  .seg button {
    width: 36px;
    height: 28px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 0;
    border-radius: 7px;
    background: none;
    color: var(--faint);
    cursor: pointer;
  }

  .seg button[aria-checked='true'] {
    background: var(--card);
    color: var(--text);
    box-shadow: var(--sh-1);
  }

  /* Phone: 44 px menu rows and a larger theme switch. */
  .phone .mi {
    height: 44px;
    gap: 12px;
    font-size: 14px;
  }

  .phone .trow {
    height: 52px;
    padding: 4px 4px 4px 10px;
  }

  .phone .seg button {
    width: 42px;
    height: 38px;
    border-radius: 9px;
  }
</style>
