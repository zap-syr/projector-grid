import { render, screen } from '@testing-library/svelte';
import { expect, test } from 'vitest';

import App from '../src/App.svelte';

test('renders the app shell', () => {
  render(App);
  expect(screen.getByText('Projector Grid')).toBeTruthy();
});
