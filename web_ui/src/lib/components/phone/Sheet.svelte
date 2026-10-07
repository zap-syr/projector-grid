<!--
  A touch-screen sheet over a scrim: from the bottom on phones and portrait
  tablets, from the right on a phone held sideways (too short for a bottom
  sheet). The scrim, the content's own close button and Esc close it. No drag
  handle: the sheet can't be swiped away, so a grabber would promise a gesture
  that does nothing.
-->
<script lang="ts">
  import type { Snippet } from 'svelte';

  import { control } from '../../state/control.svelte';

  let {
    label,
    placement,
    wide = false,
    fixed = false,
    onclose,
    children,
  }: {
    label: string;
    placement: 'bottom' | 'right';
    /** The right-hand sheet at 470 px (Alerts, whose rows need the room). */
    wide?: boolean;
    /**
     * A bottom sheet at its full height whatever the content, so folding or
     * regrouping the list doesn't make it jump (Alerts).
     */
    fixed?: boolean;
    onclose: () => void;
    children: Snippet;
  } = $props();
</script>

<svelte:window
  onkeydown={(e) => {
    // A confirm dialog opened from the sheet takes Esc first.
    if (e.key === 'Escape' && !e.defaultPrevented && !control.pending) {
      e.preventDefault();
      onclose();
    }
  }}
/>

<div class="wrap {placement}">
  <button class="scrim" aria-label="Close {label}" tabindex="-1" onclick={onclose}></button>
  <div class="sheet" class:wide class:fixed role="dialog" aria-modal="true" aria-label={label}>
    {@render children()}
  </div>
</div>

<style>
  .wrap {
    position: fixed;
    inset: 0;
    z-index: 40;
    display: flex;
  }

  .wrap.bottom {
    flex-direction: column;
    justify-content: flex-end;
  }

  .wrap.right {
    justify-content: flex-end;
  }

  .scrim {
    position: absolute;
    inset: 0;
    border: 0;
    background: var(--scrim);
    animation: fade 0.18s ease-out;
  }

  .sheet {
    position: relative;
    display: flex;
    flex-direction: column;
    background: var(--surface);
    box-shadow: var(--sh-3);
  }

  .bottom .sheet {
    max-height: 88dvh;
    padding-top: 10px;
    border-radius: 16px 16px 0 0;
    padding-bottom: env(safe-area-inset-bottom);
    animation: rise 0.22s ease-out;
  }

  .bottom .sheet.fixed {
    height: 88dvh;
  }

  /* A tablet keeps the cards above the sheet in view. */
  @media (min-width: 601px) {
    .bottom .sheet {
      max-height: 70dvh;
    }

    .bottom .sheet.fixed {
      height: 70dvh;
    }
  }

  .right .sheet {
    width: min(380px, 100%);
    height: 100%;
    padding-top: 10px;
    padding-right: env(safe-area-inset-right);
    border-radius: 16px 0 0 16px;
    animation: slide 0.22s ease-out;
  }

  .right .sheet.wide {
    width: min(470px, 100%);
  }

  @keyframes rise {
    from {
      transform: translateY(100%);
    }
  }

  @keyframes slide {
    from {
      transform: translateX(100%);
    }
  }

  @keyframes fade {
    from {
      opacity: 0;
    }
  }
</style>
