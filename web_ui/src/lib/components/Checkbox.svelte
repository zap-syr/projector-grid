<!-- Tri-state checkbox (role="checkbox", aria-checked="mixed" for some). -->
<script lang="ts">
  import type { TriState } from '../logic/selection';

  let {
    state,
    label,
    disabled = false,
    onclick,
  }: {
    state: TriState | boolean;
    label: string;
    disabled?: boolean;
    onclick: (e: MouseEvent) => void;
  } = $props();

  const value = $derived(
    state === true || state === 'all' ? 'all' : state === 'some' ? 'some' : 'none',
  );
</script>

<button
  type="button"
  class="cb {value}"
  role="checkbox"
  aria-checked={value === 'all' ? 'true' : value === 'some' ? 'mixed' : 'false'}
  aria-label={label}
  {disabled}
  onclick={(e) => {
    e.stopPropagation();
    onclick(e);
  }}
></button>

<style>
  .cb {
    width: 16px;
    height: 16px;
    padding: 0;
    flex: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 4.5px;
    border: 1.5px solid var(--line-strong);
    background: var(--surface);
    cursor: pointer;
    vertical-align: middle;
  }

  .cb:hover {
    border-color: var(--accent);
  }

  /* A finger needs ~40 px; the box stays small, the hit area grows. */
  @media (pointer: coarse) {
    .cb {
      position: relative;
    }

    .cb::before {
      content: '';
      position: absolute;
      inset: -12px;
    }
  }

  .cb.all,
  .cb.some {
    background: var(--accent);
    border-color: var(--accent);
  }

  .cb.all::after {
    content: '';
    width: 8px;
    height: 4.5px;
    border-left: 2px solid var(--on-accent);
    border-bottom: 2px solid var(--on-accent);
    transform: translateY(-1px) rotate(-45deg);
  }

  .cb.some::after {
    content: '';
    width: 8px;
    height: 2px;
    border-radius: 1px;
    background: var(--on-accent);
  }

  .cb:disabled {
    opacity: 0.35;
    cursor: default;
  }
</style>
