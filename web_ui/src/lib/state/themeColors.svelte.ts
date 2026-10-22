/**
 * Token colours that script has to compute with (the Map's group bands mix
 * into the card colour), read from tokens.css and re-read whenever the theme
 * flips: the system's light / dark, or a `data-theme` set on <html>.
 */
class ThemeColors {
  card = $state(read('--card'));

  constructor() {
    if (typeof document === 'undefined' || typeof matchMedia === 'undefined') return;
    const update = () => (this.card = read('--card'));
    matchMedia('(prefers-color-scheme: dark)').addEventListener('change', update);
    new MutationObserver(update).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme'],
    });
  }
}

function read(token: string): string {
  if (typeof document === 'undefined') return '';
  return getComputedStyle(document.documentElement).getPropertyValue(token).trim();
}

export const themeColors = new ThemeColors();
