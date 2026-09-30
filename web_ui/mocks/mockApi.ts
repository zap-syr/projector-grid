/**
 * Dev-only fake of the app's API (`npm run dev:mock`), built on the same
 * golden fixtures the contract test checks. Viewer PIN 1234, Operator PIN
 * 5678 (*Allow control* on). Every 2 s one online projector's intake
 * temperature drifts, so live updates are visible.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { resolve } from 'node:path';

import type { Plugin } from 'vite';

import type {
  Action,
  ActionRequest,
  Alignment,
  AlignmentPresetId,
  Group,
  Projector,
  Role,
} from '../src/lib/api/types.ts';

const FIXTURES = resolve(import.meta.dirname, '../../test/fixtures/api');
const VIEWER_PIN = '1234';
const OPERATOR_PIN = '5678';

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
    // The longest labels side by side, to check the cards' layout.
    if (i === 16) Object.assign(p, { power: 'standby', shutter: 'closed', signal: 'NO SIGNAL' });
    if (i === 17) Object.assign(p, { power: 'turningOn', shutter: 'closed', signal: 'NO SIGNAL' });
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

const CARD_W = 120;
const CARD_H = 100;

/** `neighbours()` from `card_layout.dart`: per side the nearest card ≤ 60 px away, overlapping ≥ 50 %. */
function neighbours(f: Projector, all: Projector[], diagonals: boolean): Set<string> {
  const best = new Map<string, [string, number]>();
  const offer = (key: string, id: string, d: number) => {
    const cur = best.get(key);
    if (!cur || d < cur[1]) best.set(key, [id, d]);
  };
  for (const n of all) {
    if (n.id === f.id) continue;
    const hGap = Math.max(n.x - (f.x + CARD_W), f.x - (n.x + CARD_W));
    const vGap = Math.max(n.y - (f.y + CARD_H), f.y - (n.y + CARD_H));
    const hOverlap = Math.min(n.x, f.x) + CARD_W - Math.max(n.x, f.x);
    const vOverlap = Math.min(n.y, f.y) + CARD_H - Math.max(n.y, f.y);
    const right = n.x > f.x;
    const below = n.y > f.y;
    if (hGap <= 60 && vOverlap >= CARD_H / 2 && hGap >= vGap) {
      offer(right ? 'r' : 'l', n.id, hGap);
    } else if (vGap <= 60 && hOverlap >= CARD_W / 2 && vGap > hGap) {
      offer(below ? 'b' : 't', n.id, vGap);
    } else if (diagonals && hGap >= 0 && vGap >= 0 && hGap <= 60 && vGap <= 60) {
      offer(`${below ? 'b' : 't'}${right ? 'r' : 'l'}`, n.id, hGap + vGap);
    }
  }
  return new Set([...best.values()].map(([id]) => id));
}

const PRESET_DEFAULTS: Record<AlignmentPresetId, [string | null, string | null]> = {
  geometry: ['OTS:07', 'OTS:70'],
  color: ['OTS:01', null],
  custom: [null, null],
};

export function mockApi(): Plugin {
  const sessions = new Map<string, Role>();
  const streams = new Set<ServerResponse>();
  const projectors = wall();

  // ── Alignment mode, like alignment_provider.dart ──────────────────────
  const alignment: Alignment = {
    active: false,
    busy: false,
    focusedId: null,
    roles: {},
    preset: 'geometry',
    focusedPattern: 'OTS:07',
    othersPattern: 'OTS:70',
    showNeighbours: false,
    includeDiagonals: false,
    showAll: false,
  };
  /** Shutter and pattern on entry, put back on exit. */
  const saved = new Map<string, [Projector['shutter'], string | null]>();

  function applyRoles() {
    if (alignment.active) {
      const scope = projectors.filter((p) => saved.has(p.id));
      const focused = scope.find((p) => p.id === alignment.focusedId);
      const open =
        focused && alignment.showNeighbours && !alignment.showAll
          ? neighbours(focused, scope, alignment.includeDiagonals)
          : new Set<string>();
      alignment.roles = Object.fromEntries(
        scope.map((p) => [
          p.id,
          p.id === alignment.focusedId
            ? 'focused'
            : alignment.showAll || open.has(p.id)
              ? 'shown'
              : 'closed',
        ]),
      );
      for (const p of scope) {
        const role = alignment.roles[p.id];
        if (role === 'closed') p.shutter = 'closed';
        else {
          p.shutter = 'open';
          p.testPattern =
            role === 'focused'
              ? alignment.focusedPattern
              : (alignment.othersPattern ?? alignment.focusedPattern);
        }
        for (const s of streams) sse(s, 'projector', p);
      }
    }
    for (const s of streams) sse(s, 'alignment', alignment);
  }

  async function alignmentOp(op: string, body: Record<string, unknown>) {
    const order = projectors.filter((p) => saved.has(p.id));
    const step = (d: number) => {
      const i = order.findIndex((p) => p.id === alignment.focusedId);
      alignment.focusedId = order[(i + d + order.length) % order.length]?.id ?? null;
    };
    switch (op) {
      case 'enter': {
        if (alignment.active) break;
        const targets = (body.targets as string[] | undefined) ?? [];
        const online = projectors.filter(
          (p) =>
            (p.connection === 'connected' || p.connection === 'unprotected') &&
            (targets.length < 2 || targets.includes(p.id)),
        );
        alignment.busy = true;
        applyRoles();
        await new Promise((r) => setTimeout(r, 900));
        for (const p of online) saved.set(p.id, [p.shutter, p.testPattern]);
        alignment.focusedId = (online.find((p) => targets.includes(p.id)) ?? online[0])?.id ?? null;
        Object.assign(alignment, { active: true, busy: false, showAll: false });
        break;
      }
      case 'exit':
        Object.assign(alignment, { active: false, busy: true, roles: {} });
        applyRoles();
        await new Promise((r) => setTimeout(r, 700));
        for (const p of projectors) {
          const s = saved.get(p.id);
          if (!s) continue;
          [p.shutter, p.testPattern] = s;
          for (const st of streams) sse(st, 'projector', p);
        }
        saved.clear();
        Object.assign(alignment, { busy: false, focusedId: null });
        break;
      case 'next':
        step(1);
        break;
      case 'prev':
        step(-1);
        break;
      case 'focus':
        if (saved.has(body.id as string)) alignment.focusedId = body.id as string;
        break;
      case 'neighbours':
        alignment.showNeighbours = !alignment.showNeighbours;
        break;
      case 'diagonals':
        alignment.includeDiagonals = !alignment.includeDiagonals;
        break;
      case 'showAll':
        if (alignment.active) alignment.showAll = !alignment.showAll;
        break;
      case 'preset': {
        const preset = body.preset as AlignmentPresetId;
        const [f, o] = PRESET_DEFAULTS[preset];
        alignment.preset = preset;
        alignment.focusedPattern = f ?? alignment.focusedPattern;
        if (preset !== 'custom') alignment.othersPattern = o;
        break;
      }
      case 'focusedPattern':
        alignment.focusedPattern = body.code as string;
        break;
      case 'othersPattern':
        alignment.othersPattern = body.code as string | null;
        break;
      default:
        return null;
    }
    applyRoles();
    return alignment;
  }

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

  /** Changes the mock projectors like a real command would and reports like the app. */
  function applyAction(action: Action, targets: Projector[]) {
    const reachable = targets.filter(
      (p) => p.connection === 'connected' || p.connection === 'unprotected',
    );
    const skipped = targets.filter((p) => !reachable.includes(p));
    let label = 'Lens Step';
    for (const p of reachable) {
      if ('power' in action) {
        label = action.power === 'on' ? 'Power On' : 'Power Standby';
        p.power = action.power === 'on' ? 'on' : 'standby';
      } else if ('shutter' in action) {
        label = action.shutter === 'open' ? 'Shutter Open' : 'Shutter Close';
        p.shutter = action.shutter === 'open' ? 'open' : 'closed';
      } else if ('testPattern' in action) {
        label = action.testPattern === 'OTS:00' ? 'Test Pattern Off' : 'Test Pattern';
        p.testPattern = action.testPattern;
      } else if ('osd' in action) {
        label = action.osd === 'on' ? 'OSD On' : 'OSD Off';
      } else if ('input' in action) {
        label = `Input: ${action.input.slice(4)}`;
        p.input = action.input.slice(4);
      } else if ('lensCalibration' in action) {
        label = 'Lens Calibration';
      } else if ('lensType' in action) {
        label = 'Lens Type';
      } else if (action.lens === 'home') {
        label = 'Lens Home';
      }
      for (const s of streams) sse(s, 'projector', p);
    }
    const ref = (p: Projector) => ({ id: p.id, name: p.name });
    const counts = [
      `${reachable.length}/${targets.length} OK`,
      ...(skipped.length ? [`${skipped.length} skipped`] : []),
    ].join(' · ');
    const skippedNames = skipped.length
      ? `. Skipped: ${skipped.map((p) => p.name).join(', ')}`
      : '';
    return {
      command: 'mock',
      label,
      ok: reachable.length,
      total: targets.length,
      failed: [],
      skipped: skipped.map(ref),
      summary: `${label} — ${counts}${skippedNames}`,
    };
  }

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = req.url?.split('?')[0];
    const t = token(req) ?? '';
    const role = sessions.get(t);
    const readPin = async () =>
      (JSON.parse((await readBody(req)) || '{}') as { pin?: unknown }).pin;

    if (req.method === 'POST' && path === '/api/login') {
      const pin = await readPin();
      const newRole = pin === OPERATOR_PIN ? 'operator' : pin === VIEWER_PIN ? 'viewer' : null;
      if (!newRole) return send(res, 401, { error: 'invalid_pin' });
      const newToken = randomUUID();
      sessions.set(newToken, newRole);
      return send(
        res,
        200,
        { token: newToken, role: newRole, controlAllowed: true },
        { 'set-cookie': `pg_session=${newToken}; Path=/; HttpOnly; SameSite=Strict` },
      );
    }
    if (path === '/api/session') {
      return send(res, 200, {
        projectName: 'Main Hall (mock)',
        authenticated: role !== undefined,
        ...(role ? { role } : {}),
        controlAllowed: true,
      });
    }
    if (!role) return send(res, 401, { error: 'unauthorized' });

    if (req.method === 'POST' && path?.startsWith('/api/alignment/')) {
      if (role !== 'operator') return send(res, 403, { error: 'forbidden' });
      const body = JSON.parse((await readBody(req)) || '{}') as Record<string, unknown>;
      const result = await alignmentOp(path.slice('/api/alignment/'.length), body);
      return result ? send(res, 200, result) : send(res, 400, { error: 'bad_request' });
    }

    switch (path) {
      case '/api/alignment':
        return send(res, 200, alignment);
      case '/api/unlock':
        if ((await readPin()) !== OPERATOR_PIN) return send(res, 401, { error: 'invalid_pin' });
        sessions.set(t, 'operator');
        return send(res, 200, { role: 'operator', controlAllowed: true });
      case '/api/lock':
        sessions.set(t, 'viewer');
        return send(res, 200, { role: 'viewer', controlAllowed: true });
      case '/api/actions': {
        if (role !== 'operator') return send(res, 403, { error: 'forbidden' });
        const body = JSON.parse((await readBody(req)) || '{}') as ActionRequest;
        const targets =
          body.targets === 'all'
            ? projectors
            : Array.isArray(body.targets)
              ? projectors.filter((p) => (body.targets as string[]).includes(p.id))
              : projectors.filter((p) => p.groupId === (body.targets as { group: string }).group);
        return send(res, 200, applyAction(body.action, targets));
      }
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
        sse(res, 'alignment', alignment);
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
