import { render, screen } from '@testing-library/svelte';
import { afterEach, expect, test, vi } from 'vitest';

import App from '../src/App.svelte';

afterEach(() => vi.unstubAllGlobals());

test('signed out → the PIN page with the project name', async () => {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => Response.json({ projectName: 'Main Hall', authenticated: false })),
  );
  render(App);
  expect(await screen.findByText('Main Hall')).toBeTruthy();
  expect(screen.getByLabelText('PIN')).toBeTruthy();
});
