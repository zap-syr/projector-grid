import { describe, expect, test } from 'vitest';

import type { Alert, Projector } from '../src/lib/api/types';
import { errorBadge, sortedErrors } from '../src/lib/logic/cells';
import { connectionLabel, powerLabel, shutterLabel, withUnit } from '../src/lib/logic/labels';
import { signalState } from '../src/lib/logic/signal';
import {
  parseCelsius,
  temperatureBarLevel,
  temperatureFraction,
  temperatureTextLevel,
  thresholdFraction,
} from '../src/lib/logic/temperature';

const node = (o: Partial<Projector>): Projector =>
  ({
    id: '1',
    name: 'PT-RQ35K',
    ip: '10.0.0.1',
    connection: 'connected',
    power: 'on',
    shutter: 'open',
    signal: '-',
    ...o,
  }) as Projector;

// The cases of test/unit/signal_state_test.dart.
describe('signalState', () => {
  test('a real signal is green with its resolution', () => {
    expect(signalState(node({ signal: '1080/60p' }))).toEqual({ label: '1080/60p', tone: 'good' });
  });

  test('no signal is red only while the projector is on', () => {
    expect(signalState(node({ signal: 'NO SIGNAL' })).tone).toBe('missing');
    for (const power of ['standby', 'turningOn', 'cooling'] as const) {
      expect(signalState(node({ signal: 'NO SIGNAL', power }))).toEqual({
        label: 'No signal',
        tone: 'unknown',
      });
    }
  });

  test('unknown when offline, on a failed login or before a reading', () => {
    for (const connection of ['offline', 'unauthorized'] as const) {
      expect(signalState(node({ signal: '1080/60p', connection }))).toEqual({
        label: 'Unknown',
        tone: 'unknown',
      });
    }
    for (const signal of ['-', 'ER401', 'Timeout', '']) {
      expect(signalState(node({ signal })).tone).toBe('unknown');
    }
  });

  test('a projector without a password reads like a connected one', () => {
    expect(signalState(node({ signal: '1080/60p', connection: 'unprotected' })).tone).toBe('good');
  });
});

describe('labels', () => {
  test('sentence case, as the app', () => {
    expect(powerLabel('turningOn')).toBe('Warming up');
    expect(powerLabel('standby')).toBe('Standby');
    expect(shutterLabel('closed')).toBe('Closed');
    expect(connectionLabel('unprotected')).toBe('No login');
    expect(connectionLabel('unauthorized')).toBe('Wrong login');
  });

  test('withUnit spaces the unit and lowers hours', () => {
    expect(withUnit('1,644H')).toBe('1,644 h');
    expect(withUnit('25°C')).toBe('25 °C');
    expect(withUnit('230V')).toBe('230 V');
    expect(withUnit('-')).toBe('-');
    expect(withUnit('Timeout')).toBe('Timeout');
  });

  test('error badges: critical first, an amber code is a warning', () => {
    const items = [
      { code: 'H001', name: null, severity: 'warning' as const },
      { code: 'F305', name: 'Fan error', severity: 'critical' as const },
    ];
    expect(sortedErrors(items).map(errorBadge)).toEqual(['Error F305', 'Warning H001']);
  });
});

describe('temperature', () => {
  const t = { warm: 50, hot: 55 };

  test('the bar goes by the reading alone', () => {
    expect(temperatureBarLevel('49°C', t)).toBeNull();
    expect(temperatureBarLevel('50°C', t)).toBe('warning');
    expect(temperatureBarLevel('55°C', t)).toBe('critical');
    expect(temperatureBarLevel('-', t)).toBeNull();
  });

  test('scale ends a quarter above hot, the mark at warm', () => {
    expect(temperatureFraction('0°C', t)).toBe(0);
    expect(temperatureFraction('100°C', t)).toBe(1);
    expect(temperatureFraction('Timeout', t)).toBeNull();
    expect(thresholdFraction(t)).toBeCloseTo(50 / 68.75);
    expect(parseCelsius('41.5°C')).toBe(41.5);
  });

  test("the value follows the rule's active alert, not one that is over", () => {
    const alert = (o: Partial<Alert>): Alert =>
      ({ rule: 'exhaust-temp', severity: 'warning', restoredAt: null, ...o }) as Alert;
    expect(temperatureTextLevel([alert({})], 'exhaust-temp')).toBe('warning');
    expect(temperatureTextLevel([alert({})], 'intake-temp')).toBeNull();
    expect(
      temperatureTextLevel([alert({ restoredAt: '2026-10-21T21:03:00Z' })], 'exhaust-temp'),
    ).toBeNull();
  });
});
