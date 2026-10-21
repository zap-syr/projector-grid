import type { Alert, AlertRule, AlertSeverity, Config } from '../api/types';
import { isRecovered } from './alerts';

/** One rule's thresholds from `/api/config` (`TempThreshold`). */
export type TempThreshold = Config['thresholds']['intake'];

/** The leading number of `25°C`; null for `-`, `Timeout` (`parseCelsius`). */
export function parseCelsius(display: string): number | null {
  const m = /^-?\d+(\.\d+)?/.exec(display);
  return m ? Number(m[0]) : null;
}

/** The bar's scale ends a quarter above the critical threshold (`temperatureScaleMax`). */
export const temperatureScaleMax = (t: TempThreshold): number => t.hot * 1.25;

/** How full a temperature bar is; null without a reading (`temperatureFraction`). */
export function temperatureFraction(display: string, t: TempThreshold): number | null {
  const c = parseCelsius(display);
  if (c === null) return null;
  return Math.min(1, Math.max(0, c / temperatureScaleMax(t)));
}

/** Where the warning threshold's mark sits on the bar (`thresholdFraction`). */
export const thresholdFraction = (t: TempThreshold): number => t.warm / temperatureScaleMax(t);

/**
 * The bar's colour level by the reading alone, without the alert's
 * hysteresis, so it follows the value even with the rule off
 * (`temperatureBarLevel`). Null below the warning threshold or without a
 * reading.
 */
export function temperatureBarLevel(display: string, t: TempThreshold): AlertSeverity | null {
  const c = parseCelsius(display);
  if (c === null) return null;
  if (c >= t.hot) return 'critical';
  return c >= t.warm ? 'warning' : null;
}

/**
 * The value's colour follows the rule's active alert, as the app's
 * (`MonitoringStatus.intake` / `exhaust`): its hysteresis and a switched-off
 * rule carry over. An alert that is over colours nothing.
 */
export function temperatureTextLevel(
  alerts: readonly Alert[],
  rule: Extract<AlertRule, 'intake-temp' | 'exhaust-temp'>,
): AlertSeverity | null {
  return alerts.find((a) => a.rule === rule && !isRecovered(a))?.severity ?? null;
}
