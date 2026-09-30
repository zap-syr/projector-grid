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
  error: 'Error',
  'error-locked-out': 'Error',
  'event-snapshot': 'SnapshotEvent',
  'event-project': 'ProjectEvent',
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

  test('extra fields are rejected', () => {
    const validate = ajv.compile({ $ref: 'openapi.json#/components/schemas/Group' });
    expect(validate({ id: 'g', name: 'Stage', color: '#FFFFFF', extra: 1 })).toBe(false);
  });
});
