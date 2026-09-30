/** Upper bound for resize and auto-fit, as in the app. */
export const MAX_COLUMN_WIDTH = 600;

const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

export interface Layout {
  widths: number[];
  tableWidth: number;
  /** Fit-to-width is stretching the columns to the viewport. */
  scaling: boolean;
}

/**
 * On-screen widths: with fit-to-width on and room to spare, the stored (base)
 * widths are scaled up proportionally to fill the viewport; otherwise they're
 * used as is and the table scrolls sideways.
 */
export function layoutWidths(
  base: readonly number[],
  viewport: number,
  fitToWidth: boolean,
): Layout {
  const total = base.reduce((a, b) => a + b, 0);
  const scaling = fitToWidth && viewport > total;
  return scaling
    ? { widths: base.map((w) => (w * viewport) / total), tableWidth: viewport, scaling }
    : { widths: [...base], tableWidth: total, scaling };
}

export interface ResizeStart {
  /** On-screen width of the column when the drag started. */
  startWidth: number;
  /** Summed base width of every other column. */
  otherBase: number;
  viewport: number;
  scaling: boolean;
}

/**
 * The base width to store for a resize drag of [dx] px — the app's
 * `_resizeBaseFor`. While fit-to-width is scaling, a base width `b` renders at
 * `b·V/(B+b)`; solving for the desired on-screen width `e` gives
 * `b = e·B/(V−e)`, so the header edge tracks the pointer. Past `e ≥ V−B`
 * nothing scales and base = on-screen width; the branches meet there.
 */
export function resizeBase(start: ResizeStart, dx: number, minWidth: number): number {
  const desired = start.startWidth + dx;
  const limit = start.viewport - start.otherBase;
  const base =
    start.scaling && start.otherBase > 0 && desired < limit
      ? (desired * start.otherBase) / (start.viewport - desired)
      : desired;
  return clamp(base, minWidth, MAX_COLUMN_WIDTH);
}

/** Auto-fit: widest of header label and cells, plus padding (`_autoFitColumn`). */
export function autoFitWidth(
  labelWidth: number,
  cellWidths: readonly number[],
  horizontalPadding: number,
  minWidth: number,
): number {
  const widest = Math.max(labelWidth, ...cellWidths);
  return clamp(widest + horizontalPadding + 6, minWidth, MAX_COLUMN_WIDTH);
}
