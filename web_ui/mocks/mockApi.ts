/**
 * Dev-only fake of the app's API (`npm run dev:mock`), built on the same
 * golden fixtures the contract test checks. PIN: 1234. Every 2 s one online
 * projector's intake temperature drifts, so live updates are visible.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { resolve } from 'node:path';

import type { Plugin } from 'vite';

import type { Group, Projector } from '../src/lib/api/types.ts';

const FIXTURES = resolve(import.meta.dirname, '../../test/fixtures/api');
const PIN = '1234';

const load = <T>(name: string): T =>
  JSON.parse(readFileSync(resolve(FIXTURES, `${name}.json`), 'utf8')) as T;

const GROUPS: Group[] = [...load<Group[]>('groups'), { id: 'g3', name: 'Lobby', color: '#12B5CB' }];

/**
 * A 6×4 wall of 24 projectors (Stage, Balcony, Lobby, one row ungrouped)
 * cloned from the fixture's healthy projector, with a spread of states so
 * sorting, filters and group summaries have something to show.
 */
function wall(): Projector[] {
  const template = load<Projector[]>('projectors').find((p) => p.id === 'n2') as Projector;
  const rowGroup = ['g1', 'g2', 'g3', null];
  return Array.from({ length: 24 }, (_, i) => {
    const row = Math.floor(i / 6);
    const n = String(i + 1).padStart(2, '0');
    const p: Projector = {
      ...template,
      id: `m${n}`,
      name: `PJ-${n}`,
      ip: `192.168.0.${110 + i}`,
      serial: `SH42130${n}`,
      groupId: rowGroup[row] ?? null,
      x: 20 + (i % 6) * 140,
      y: 40 + row * 140,
      runtime: `${8200 + i * 37}H`,
      lightRuntime: `${1400 + i * 11}H`,
      intakeTemp: `${30 + (i % 9)}°C`,
      exhaustTemp: `${42 + (i % 7) * 3}°C`,
      testPattern: ['OTS:07', 'OTS:00', 'OTS:70', 'OTS:00', 'OTS:01', 'OTS:87'][i % 6] ?? null,
    };
    if (i === 3) Object.assign(p, { power: 'cooling', shutter: 'closed' });
    if (i === 8) p.errors = '000100000000';
    if (i === 10)
      Object.assign(p, { connection: 'unauthorized', power: 'standby', shutter: 'closed' });
    if (i === 14) Object.assign(p, { shutter: 'closed', signal: 'NO SIGNAL' });
    if (i === 20 || i === 23) {
      Object.assign(p, {
        connection: 'offline',
        power: 'standby',
        shutter: 'closed',
        input: '-',
        signal: '-',
        testPattern: null,
        runtime: '-',
        lightRuntime: '-',
        intakeTemp: '-',
        exhaustTemp: '-',
        acVoltage: '-',
        errors: '-',
      });
    }
    return p;
  });
}

export function mockApi(): Plugin {
  const sessions = new Set<string>();
  const streams = new Set<ServerResponse>();
  const projectors = wall();

  const send = (res: ServerResponse, status: number, body?: unknown, headers = {}) => {
    res.writeHead(status, { 'content-type': 'application/json', ...headers });
    res.end(body === undefined ? undefined : JSON.stringify(body));
  };
  const sse = (res: ServerResponse, name: string, data: unknown) =>
    res.write(`event: ${name}\ndata: ${JSON.stringify(data)}\n\n`);

  const token = (req: IncomingMessage) =>
    /(?:^|;\s*)pg_session=([^;]+)/.exec(req.headers.cookie ?? '')?.[1] ?? null;

  const readBody = (req: IncomingMessage) =>
    new Promise<string>((done) => {
      let body = '';
      req.on('data', (chunk: Buffer) => (body += chunk.toString()));
      req.on('end', () => done(body));
    });

  function drift() {
    const online = projectors.filter((p) => p.connection !== 'offline');
    const p = online[Math.floor(Math.random() * online.length)];
    if (!p) return;
    const current = Number.parseInt(p.intakeTemp, 10);
    const base = Number.isNaN(current) ? 35 : current;
    p.intakeTemp = `${Math.max(28, Math.min(47, base + (Math.random() < 0.5 ? -1 : 1)))}°C`;
    for (const s of streams) sse(s, 'projector', p);
  }

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = req.url?.split('?')[0];
    const signedIn = sessions.has(token(req) ?? '');

    if (req.method === 'POST' && path === '/api/login') {
      const pin = (JSON.parse((await readBody(req)) || '{}') as { pin?: unknown }).pin;
      if (pin !== PIN) return send(res, 401, { error: 'invalid_pin' });
      const t = randomUUID();
      sessions.add(t);
      return send(
        res,
        200,
        { token: t, role: 'viewer' },
        { 'set-cookie': `pg_session=${t}; Path=/; HttpOnly; SameSite=Strict` },
      );
    }
    if (path === '/api/session') {
      return send(res, 200, {
        projectName: 'Main Hall (mock)',
        authenticated: signedIn,
        ...(signedIn ? { role: 'viewer' } : {}),
      });
    }
    if (!signedIn) return send(res, 401, { error: 'unauthorized' });

    switch (path) {
      case '/api/logout':
        sessions.delete(token(req) ?? '');
        return send(res, 204, undefined, { 'set-cookie': 'pg_session=; Path=/; Max-Age=0' });
      case '/api/config':
        return send(res, 200, { ...load<object>('config'), projectName: 'Main Hall (mock)' });
      case '/api/projectors':
        return send(res, 200, projectors);
      case '/api/groups':
        return send(res, 200, GROUPS);
      case '/api/alerts':
        return send(res, 200, []);
      case '/api/events':
        res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' });
        res.write('retry: 3000\n\n');
        sse(res, 'snapshot', {
          projectName: 'Main Hall (mock)',
          projectors,
          groups: GROUPS,
        });
        streams.add(res);
        req.on('close', () => streams.delete(res));
        return;
      default:
        return send(res, 404, { error: 'not_found' });
    }
  }

  return {
    name: 'projector-grid-mock-api',
    configureServer(server) {
      const timer = setInterval(drift, 2000);
      server.httpServer?.on('close', () => clearInterval(timer));
      server.middlewares.use((req, res, next) => {
        if (req.url?.startsWith('/api/')) void handle(req, res);
        else next();
      });
    },
  };
}
