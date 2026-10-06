import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { fireEvent, render, screen } from '@testing-library/svelte';
import { expect, test } from 'vitest';

import type { Alerts, Group, Projector } from '../src/lib/api/types';
import AlertsPanel from '../src/lib/components/alerts/AlertsPanel.svelte';
import { alerts } from '../src/lib/state/alerts.svelte';
import { live } from '../src/lib/state/live.svelte';

const fixture = <T>(name: string): T =>
  JSON.parse(
    readFileSync(resolve(import.meta.dirname, `../../test/fixtures/api/${name}.json`), 'utf8'),
  ) as T;

test('fold / unfold all reaches a single rule group and its subsections', async () => {
  live.projectors = fixture<Projector[]>('projectors');
  live.groups = fixture<Group[]>('groups');
  const all = fixture<Alerts>('alerts');
  // Only the error: one rule group, one Stage subsection.
  alerts.apply({ ...all, alerts: all.alerts.filter((a) => a.rule === 'error') });
  alerts.setPref('grouping', 'alert');
  alerts.setPref('byProjectGroups', true);

  render(AlertsPanel, { operator: true, onclose: () => {} });
  expect(screen.getByText('Shutter error (F011)')).toBeTruthy();

  await fireEvent.click(screen.getByRole('button', { name: 'Fold all' }));
  expect(screen.queryByText('Shutter error (F011)')).toBeNull();

  await fireEvent.click(screen.getByRole('button', { name: 'Unfold all' }));
  expect(screen.getByText('Shutter error (F011)')).toBeTruthy();
});
