import type { Group, Projector } from '../api/types';

/**
 * Every status word the page shows, as the app's Monitoring view says it
 * (`monitoring_format.dart`, `ProjectorStatusStyle`, `ConnectionStatusBadge`):
 * sentence case, no upper-case states, no dashes for "nothing".
 */

export function powerLabel(power: Projector['power']): string {
  return { on: 'On', turningOn: 'Warming up', cooling: 'Cooling', standby: 'Standby' }[power];
}

export function shutterLabel(shutter: Projector['shutter']): string {
  return shutter === 'open' ? 'Open' : 'Closed';
}

export function connectionLabel(connection: Projector['connection']): string {
  return {
    connected: 'Online',
    unprotected: 'No login',
    unauthorized: 'Wrong login',
    offline: 'Offline',
  }[connection];
}

export function groupLabel(group: Group | undefined): string {
  return group?.name ?? 'None';
}

/**
 * The Errors column without a problem: *Unknown* while offline (its codes are
 * the last ones it sent), *None* otherwise.
 */
export function noErrorsLabel(p: Projector): string {
  return p.connection === 'offline' ? 'Unknown' : 'None';
}

/**
 * A telemetry value with a space before its unit and hours in lower case:
 * `1,644H` → `1,644 h`, `25°C` → `25 °C`, `230V` → `230 V` (`withUnit`).
 * Anything else (`-`, `Timeout`) as it is.
 */
export function withUnit(display: string): string {
  const m = /^(-?[\d,.]+)\s*(°C|H|V)$/.exec(display.trim());
  if (!m) return display;
  return `${m[1]} ${m[2] === 'H' ? 'h' : m[2]}`;
}
