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

import type { Projector } from '../src/lib/api/types.ts';

const FIXTURES = resolve(import.meta.dirname, '../../test/fixtures/api');
const PIN = '1234';

const load = <T>(name: string): T =>
  JSON.parse(readFileSync(resolve(FIXTURES, `${name}.json`), 'utf8')) as T;

export function mockApi(): Plugin {
  const sessions = new Set<string>();
  const streams = new Set<ServerResponse>();
  const projectors = load<Projector[]>('projectors');

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
        return send(res, 200, load('groups'));
      case '/api/alerts':
        return send(res, 200, []);
      case '/api/events':
        res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' });
        res.write('retry: 3000\n\n');
        sse(res, 'snapshot', {
          projectName: 'Main Hall (mock)',
          projectors,
          groups: load('groups'),
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
