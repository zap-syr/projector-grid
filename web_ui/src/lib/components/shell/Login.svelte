<script lang="ts">
  import { session } from '../../state/session.svelte';
  import AppLogo from './AppLogo.svelte';

  let pin = $state('');
  let error = $state<string | null>(null);
  let busy = $state(false);

  async function submit(e: SubmitEvent) {
    e.preventDefault();
    if (!pin || busy) return;
    busy = true;
    error = await session.login(pin);
    busy = false;
    if (error) pin = '';
  }
</script>

<main class="wrap">
  <form class="card" onsubmit={submit}>
    <div class="logo"><AppLogo size={56} /></div>
    <div class="t">
      <b>{session.projectName}</b>
      <span>Enter your PIN</span>
    </div>
    <input
      type="password"
      inputmode="numeric"
      autocomplete="current-password"
      maxlength="8"
      aria-label="PIN"
      aria-invalid={error !== null}
      bind:value={pin}
      oninput={() => (pin = pin.replace(/\D/g, ''))}
    />
    <button class="btn primary" type="submit" disabled={!pin || busy}>Sign in</button>
    <p class="msg" role="alert">{error ?? session.notice ?? ''}</p>
  </form>
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
    gap: 14px;
    padding: 28px 24px 18px;
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

  input {
    height: 44px;
    padding: 0 12px;
    border-radius: var(--r-sm);
    border: 1px solid var(--line-strong);
    background: var(--app);
    font-family: var(--mono);
    font-size: 20px;
    letter-spacing: 0.3em;
    text-align: center;
  }

  input:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }

  input[aria-invalid='true'] {
    border-color: var(--err);
  }

  .btn {
    height: 44px;
    border-radius: var(--r-sm);
    border: 1px solid var(--accent);
    background: var(--accent);
    color: var(--on-accent);
    font-weight: 600;
    font-size: 14.5px;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--accent-hover);
  }

  .btn:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .msg {
    margin: 0;
    min-height: 1.45em;
    text-align: center;
    font-size: 13px;
    color: var(--err);
  }
</style>
