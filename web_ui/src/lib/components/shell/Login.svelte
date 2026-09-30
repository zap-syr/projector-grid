<script lang="ts">
  import { session } from '../../state/session.svelte';
  import AppLogo from './AppLogo.svelte';
  import PinEntry from './PinEntry.svelte';
</script>

<main class="wrap">
  <div class="card">
    <div class="logo"><AppLogo size={56} /></div>
    <div class="t">
      <b>{session.projectName}</b>
      <span>Enter your PIN</span>
    </div>
    <PinEntry
      label="Sign in"
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
  }

  .card {
    width: 100%;
    max-width: 340px;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 18px;
    padding: 28px 24px 14px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 16px;
    box-shadow: var(--sh-2);
  }

  .logo {
    align-self: center;
  }

  .t {
    text-align: center;
  }

  .t b {
    display: block;
    font-size: 21px;
    font-weight: 650;
    letter-spacing: -0.01em;
  }

  .t span {
    color: var(--muted);
  }

  /* Phones: full screen, no card, like the mockup's PIN screen. */
  @media (max-width: 600px) {
    .wrap {
      padding: 0;
      background: var(--surface);
    }

    .card {
      max-width: none;
      border: 0;
      box-shadow: none;
    }
  }
</style>
