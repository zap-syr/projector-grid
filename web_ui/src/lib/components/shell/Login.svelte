<!--
  Sign in (shell canvas, *Sign in…*, *Phone: sign in…*): a card with the
  app's logo, the project name, the PIN field with its help line and *Sign
  in*; on phones and touch screens the logo sits beside the name and the
  PIN pad takes the field's place.
-->
<script lang="ts">
  import { device } from '../../state/device.svelte';
  import { session } from '../../state/session.svelte';
  import AppLogo from './AppLogo.svelte';
  import PinEntry from './PinEntry.svelte';
</script>

<main class="wrap">
  <div class="card" class:pad={device.pinPad}>
    <div class="top">
      <AppLogo size={device.pinPad ? 48 : 56} />
      <div class="t">
        <b>{session.projectName}</b>
        <small>{device.pinPad ? 'Enter your PIN' : 'Projector Grid, Web Access'}</small>
      </div>
    </div>
    <PinEntry
      label="Sign in"
      fieldLabel="PIN"
      help="Ask the person at the show PC"
      notice={session.notice}
      autofocus
      submit={(pin) => session.login(pin)}
    />
  </div>
</main>

<style>
  .wrap {
    min-height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px 16px;
    background: var(--app);
  }

  .card {
    width: 100%;
    max-width: 380px;
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding: 28px 28px 24px;
    border: 1px solid var(--line-strong);
    border-radius: 20px;
    background: var(--card);
    box-shadow: var(--sh-3);
  }

  .top {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    text-align: center;
  }

  .t b {
    display: block;
    font-size: 18px;
    font-weight: 600;
  }

  .t small {
    display: block;
    margin-top: 2px;
    color: var(--muted);
    font-size: 12.5px;
  }

  /* The PIN pad: logo beside the name, the pad centred under them. */
  .card.pad {
    align-items: center;
    padding: 26px 20px 18px;
  }

  .pad .top {
    flex-direction: row;
    align-self: stretch;
    gap: 14px;
    text-align: left;
  }

  .pad .t b {
    font-size: 17px;
  }
</style>
