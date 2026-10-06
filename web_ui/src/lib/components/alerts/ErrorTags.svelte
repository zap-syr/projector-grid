<!--
  The projector's errors as code tags in their severity colour, critical
  first, up to 4 then +N (`MonitoringErrorsCell`). Hover (a tap on touch)
  opens each error's name and how long its alert has been active.
-->
<script lang="ts">
  import type { ErrorItem, Projector } from '../../api/types';
  import { formatDuration } from '../../logic/alerts';
  import { alerts } from '../../state/alerts.svelte';
  import AlertIcon, { severityIcon } from './AlertIcon.svelte';

  let { p, max = 4 }: { p: Projector; max?: number } = $props();

  let open = $state(false);
  let wrap = $state<HTMLElement>();

  /** When each error's alert started; none while the rule is off. */
  const since = $derived(
    new Map(
      alerts
        .of(p.id)
        .filter((a) => a.rule === 'error')
        .map((a) => [a.item, Date.parse(a.since)]),
    ),
  );
  // `sortProjectorErrors`: critical first, then newest, errors without an alert last.
  const items = $derived(
    [...p.errorItems].sort((a: ErrorItem, b: ErrorItem) => {
      if (a.severity !== b.severity) return a.severity === 'critical' ? -1 : 1;
      const sa = since.get(a.code);
      const sb = since.get(b.code);
      if (sa === undefined || sb === undefined)
        return (sa === undefined ? 1 : 0) - (sb === undefined ? 1 : 0);
      return sb - sa;
    }),
  );
  const top = $derived(items[0]?.severity ?? 'critical');

  /** Fixed to the viewport: table cells and cards clip their overflow. */
  let at = $state({ left: 0, top: 0, above: false });
  const POP_W = 340;

  function show() {
    if (!wrap) return;
    const r = wrap.getBoundingClientRect();
    const width = Math.min(POP_W, innerWidth - 32);
    const height = 16 + items.length * 47;
    const above = r.bottom + 6 + height > innerHeight && r.top - 6 - height > 0;
    at = {
      left: Math.max(16, Math.min(r.left, innerWidth - width - 16)),
      top: above ? r.top - 6 : r.bottom + 6,
      above,
    };
    open = true;
  }

  function onWindowPointer(e: PointerEvent) {
    if (open && wrap && !wrap.contains(e.target as Node)) open = false;
  }

  // Pinned to where the tags were: any scroll (the table's, the list's) leaves it behind.
  $effect(() => {
    if (!open) return;
    const close = () => (open = false);
    addEventListener('scroll', close, true);
    return () => removeEventListener('scroll', close, true);
  });
</script>

<svelte:window onpointerdown={onWindowPointer} />

<!-- A tap opens it (closing is a tap elsewhere); a mouse just hovers. -->
<span
  class="errs"
  bind:this={wrap}
  role="button"
  tabindex="0"
  aria-expanded={open}
  aria-label="{items.length} {items.length === 1 ? 'error' : 'errors'}"
  onclick={(e) => {
    e.stopPropagation();
    show();
  }}
  onkeydown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      e.stopPropagation();
      if (open) open = false;
      else show();
    }
  }}
  onpointerenter={(e) => {
    if (e.pointerType === 'mouse') show();
  }}
  onpointerleave={(e) => {
    if (e.pointerType === 'mouse') open = false;
  }}
>
  <span class={top === 'critical' ? 'crit' : 'warn'}
    ><AlertIcon name={severityIcon(top)} size={13} /></span
  >
  {#each items.slice(0, max) as e (e.code)}
    <span class="tag {e.severity}">{e.code}</span>
  {/each}
  {#if items.length > max}<span class="more">+{items.length - max}</span>{/if}
  {#if open}
    <span
      class="pop"
      class:above={at.above}
      role="tooltip"
      style:left="{at.left}px"
      style:top="{at.top}px"
      style:width="{Math.min(POP_W, innerWidth - 32)}px"
    >
      {#each items as e (e.code)}
        {@const s = since.get(e.code)}
        <span class="erow">
          <span class="chip {e.severity}"
            ><AlertIcon name={severityIcon(e.severity)} size={14} /></span
          >
          <span class="nm {e.severity}">{e.name ?? 'Unknown error'}</span>
          <span class="code">{e.code}</span>
          <span class="d">{s === undefined ? '' : formatDuration(alerts.now.getTime() - s)}</span>
        </span>
      {/each}
    </span>
  {/if}
</span>

<style>
  .errs {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    max-width: 100%;
    padding: 3px 6px;
    margin-left: -6px;
    border-radius: 6px;
    cursor: default;
    vertical-align: middle;
  }

  .errs:hover,
  .errs[aria-expanded='true'] {
    background: var(--hover);
  }

  .crit,
  .warn {
    display: inline-flex;
    margin-right: 2px;
  }

  .crit {
    color: var(--sev-crit);
  }

  .warn {
    color: var(--sev-warn);
  }

  .tag {
    flex: none;
    padding: 1px 5px;
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 11.5px;
    font-weight: 600;
  }

  .tag.critical {
    background: var(--err-soft);
    color: var(--err);
  }

  .tag.warning {
    background: var(--warn-soft);
    color: var(--warn);
  }

  .more {
    font-size: 11px;
    font-weight: 700;
    color: var(--muted);
  }

  .pop {
    position: fixed;
    z-index: 45;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding: 8px;
    border: 1px solid var(--line);
    border-radius: 12px;
    background: var(--surface);
    box-shadow: var(--sh-2);
    white-space: normal;
    cursor: auto;
  }

  .pop.above {
    transform: translateY(-100%);
  }

  .erow {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 36px;
    padding: 0 10px 0 7px;
    border-radius: 8px;
    background: var(--item);
  }

  .chip {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    flex: none;
    border-radius: 6px;
  }

  .chip.critical {
    background: color-mix(in srgb, var(--sev-crit) 17%, var(--item));
    color: var(--sev-crit);
  }

  .chip.warning {
    background: color-mix(in srgb, var(--sev-warn) 17%, var(--item));
    color: var(--sev-warn);
  }

  .nm {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 13px;
    font-weight: 600;
  }

  .nm.critical {
    color: var(--err);
  }

  .nm.warning {
    color: var(--warn);
  }

  .code {
    flex: none;
    padding: 1px 5px;
    border-radius: 4px;
    background: var(--hover);
    font-family: var(--mono);
    font-size: 11px;
    color: var(--muted);
  }

  .d {
    width: 52px;
    flex: none;
    text-align: right;
    font-size: 11px;
    color: var(--faint);
    font-variant-numeric: tabular-nums;
  }

  @media (pointer: coarse) {
    .tag {
      padding: 2px 6px;
      font-size: 12.5px;
    }

    .erow {
      min-height: 44px;
    }

    .nm {
      font-size: 14px;
    }
  }
</style>
