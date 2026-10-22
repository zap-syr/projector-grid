export type ThemeChoice = 'system' | 'light' | 'dark';

const KEY = 'pg.theme.v1';

function read(): ThemeChoice {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'light' || v === 'dark' ? v : 'system';
  } catch {
    return 'system';
  }
}

/** tokens.css follows the system unless <html> carries a `data-theme`. */
function apply(choice: ThemeChoice): void {
  if (typeof document === 'undefined') return;
  if (choice === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = choice;
}

/**
 * The role menu's Theme switch (owner, 2026-10-21): System by default,
 * remembered per browser.
 */
class ThemeState {
  value = $state<ThemeChoice>(read());

  constructor() {
    apply(this.value);
  }

  set(choice: ThemeChoice): void {
    this.value = choice;
    apply(choice);
    try {
      if (choice === 'system') localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, choice);
    } catch {
      // No storage: the choice lasts until reload.
    }
  }
}

export const theme = new ThemeState();
