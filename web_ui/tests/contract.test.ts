/**
 * The Dart side writes sample payloads to test/fixtures/api/ (see
 * test/unit/web_api_dto_test.dart); they must match api/openapi.yaml. A field
 * renamed on one side only fails here.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { Ajv2020 } from 'ajv/dist/2020.js';
import { describe, expect, test } from 'vitest';
import { parse } from 'yaml';

import { act } from '../src/lib/logic/actions';

const FIXTURES = resolve(import.meta.dirname, '../../test/fixtures/api');
const spec = parse(readFileSync(resolve(import.meta.dirname, '../api/openapi.yaml'), 'utf8'));

// Fixture file → the schema it's an instance of.
const schemaFor: Record<string, string> = {
  projectors: 'Projectors',
  groups: 'Groups',
  config: 'Config',
  'session-signed-in': 'Session',
  'session-signed-out': 'Session',
  login: 'LoginResponse',
  access: 'Access',
  'dispatch-result': 'DispatchResult',
  error: 'Error',
  'error-locked-out': 'Error',
  'event-snapshot': 'SnapshotEvent',
  'event-project': 'ProjectEvent',
  alignment: 'Alignment',
  'alignment-off': 'Alignment',
  'preview-status': 'PreviewStatus',
  'preview-status-notice': 'PreviewStatus',
  'preview-frame': 'PreviewFrame',
};

// OpenAPI keywords (description, enum on $ref siblings…) aren't all JSON Schema.
const ajv = new Ajv2020({ strict: false, allErrors: true });
ajv.addSchema({ $id: 'openapi.json', components: spec.components });

describe('fixtures match openapi.yaml', () => {
  for (const [fixture, schema] of Object.entries(schemaFor)) {
    test(`${fixture}.json is a ${schema}`, () => {
      const validate = ajv.compile({ $ref: `openapi.json#/components/schemas/${schema}` });
      const data: unknown = JSON.parse(readFileSync(resolve(FIXTURES, `${fixture}.json`), 'utf8'));
      const ok = validate(data);
      expect(validate.errors ?? [], JSON.stringify(validate.errors, null, 2)).toEqual([]);
      expect(ok).toBe(true);
    });
  }

  test('every fixture is checked', () => {
    const files = readdirSync(FIXTURES).map((f) => f.replace(/\.json$/, ''));
    expect(files.sort()).toEqual(Object.keys(schemaFor).sort());
  });

  test('every action the page builds is a valid ActionRequest', () => {
    const validate = ajv.compile({ $ref: 'openapi.json#/components/schemas/ActionRequest' });
    const actions = [
      act.power(true),
      act.power(false),
      act.shutter(true),
      act.shutter(false),
      act.testPattern('OTS:07'),
      act.lensHome(),
      act.osd(true),
      act.input('IIS:HD1'),
      act.lensCalibration('VXX:LNSI0=+00001'),
      act.lensType('VXX:LNEI1=+00001'),
      act.lensStep('shiftH', true, 'slow'),
      act.lensStep('zoom', false, 'fast'),
    ];
    for (const action of actions) {
      for (const targets of [['a', 'b'], { group: 'g1' }, 'all']) {
        expect(validate({ targets, action }), JSON.stringify(validate.errors)).toBe(true);
      }
    }
    expect(validate({ targets: [], action: act.power(true) })).toBe(false);
    expect(validate({ targets: 'all', action: { raw: 'VXX:RSTS1=+00001' } })).toBe(false);
  });

  test('extra fields are rejected', () => {
    const validate = ajv.compile({ $ref: 'openapi.json#/components/schemas/Group' });
    expect(validate({ id: 'g', name: 'Stage', color: '#FFFFFF', extra: 1 })).toBe(false);
  });
});
