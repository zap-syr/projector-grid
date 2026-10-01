<!-- One table cell, drawn like the app's Monitoring cell builders. -->
<script lang="ts">
  import type { Config, DataColumn, Group, Projector } from '../../api/types';
  import { cellText, tempTint } from '../../logic/cells';
  import { isPatternActive, patternSwatch } from '../../logic/patterns';
  import Icon from '../Icon.svelte';

  let {
    column,
    p,
    groups,
    thresholds,
    patternLabel,
  }: {
    column: DataColumn;
    p: Projector;
    groups: ReadonlyMap<string, Group>;
    thresholds: Config['thresholds'];
    patternLabel: (code: string) => string;
  } = $props();

  const text = $derived(cellText(column, p, groups, patternLabel));
  const group = $derived(p.groupId ? groups.get(p.groupId) : undefined);
  const online = $derived(p.connection === 'connected' || p.connection === 'unprotected');
</script>

<span class="cv" title={text}>
  {#if column === 'connection'}
    <span class="dot" class:ok={online} class:warn={p.connection === 'unauthorized'}></span>
    <span
      class="t"
      class:ok={online}
      class:warn={p.connection === 'unauthorized'}
      class:err={p.connection === 'offline'}>{text}</span
    >
    {#if p.connection === 'unauthorized'}
      <span class="warn"><Icon name="lock" size={13} /></span>
    {:else if p.connection === 'unprotected'}
      <span class="acc"><Icon name="unlock" size={13} /></span>
    {/if}
  {:else if column === 'power'}
    {@const tone = p.power === 'on' ? 'ok' : p.power === 'standby' ? 'err' : 'warn'}
    <span class={tone}><Icon name="power" size={15} /></span>
    <span class="t {tone}">{text}</span>
  {:else if column === 'shutter'}
    {@const tone = p.shutter === 'open' ? 'ok' : 'err'}
    <span class={tone}><Icon name="eye" size={15} /></span>
    <span class="t {tone}">{text}</span>
  {:else if column === 'group' && group}
    <span class="gdot" style:background={group.color}></span>
    <span class="t">{text}</span>
  {:else if column === 'testPattern' && isPatternActive(p.testPattern)}
    <span class="sw" style:background={patternSwatch(p.testPattern) ?? 'var(--hover)'}></span>
    <span class="t">{text}</span>
  {:else if column === 'intake' || column === 'exhaust'}
    {@const tint = tempTint(text, thresholds[column])}
    <span class="t" class:warm={tint === 'warm'} class:hot={tint === 'hot'}>{text}</span>
  {:else if column === 'errors' && p.errors !== '-'}
    {@const ok = text === 'NO ERRORS'}
    <span class={ok ? 'ok' : 'err'}><Icon name={ok ? 'check' : 'error'} size={14} /></span>
    <span class="t" class:err={!ok}>{text}</span>
  {:else}
    <span class="t">{text}</span>
  {/if}
</span>

<style>
  .cv {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    max-width: 100%;
    overflow: hidden;
    vertical-align: middle;
  }

  .t {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ok {
    color: var(--ok);
  }

  .warn {
    color: var(--warn);
  }

  .err {
    color: var(--err);
  }

  .acc {
    color: var(--accent);
  }

  .t.ok,
  .t.warn,
  .t.err {
    font-weight: 550;
  }

  .warm {
    color: var(--warn);
    font-weight: 600;
  }

  .hot {
    color: var(--err);
    font-weight: 700;
  }

  .dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    flex: none;
    background: var(--err);
  }

  .dot.ok {
    background: var(--ok);
  }

  .dot.warn {
    background: var(--warn);
  }

  .gdot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex: none;
  }

  .sw {
    width: 20px;
    height: 13px;
    border-radius: 2px;
    box-shadow: inset 0 0 0 1px var(--line-strong);
    flex: none;
  }
</style>
