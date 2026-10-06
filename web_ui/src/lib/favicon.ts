/**
 * The tab icon with a red dot while alerts wait to be acknowledged: the page's
 * own favicon drawn onto a canvas, so a background tab still shows it.
 */
let original: string | null = null;
let image: HTMLImageElement | null = null;
let wanted = false;

function link(): HTMLLinkElement | null {
  return document.querySelector<HTMLLinkElement>('link[rel="icon"]');
}

function draw(): void {
  const el = link();
  const ctx = document.createElement('canvas').getContext('2d');
  // No canvas (a test DOM) or no icon: the title's count still says it.
  if (!el || !ctx || !image) return;
  const canvas = ctx.canvas;
  canvas.width = canvas.height = 64;
  ctx.drawImage(image, 0, 0, 64, 64);
  ctx.beginPath();
  ctx.arc(48, 16, 14, 0, Math.PI * 2);
  ctx.fillStyle = '#ffffff';
  ctx.fill();
  ctx.beginPath();
  ctx.arc(48, 16, 11, 0, Math.PI * 2);
  ctx.fillStyle = '#f44336';
  ctx.fill();
  el.href = canvas.toDataURL('image/png');
}

export function setFavicon(dot: boolean): void {
  const el = link();
  if (!el) return;
  original ??= el.href;
  wanted = dot;
  if (!dot) {
    el.href = original;
    return;
  }
  if (image?.complete) {
    draw();
    return;
  }
  image = new Image();
  image.onload = () => {
    if (wanted) draw();
  };
  image.src = original;
}
