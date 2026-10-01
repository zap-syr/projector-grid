/**
 * The mock's Remote Preview (`/api/preview/{id}`): generated colour-bar
 * images with a moving bar, ~1 fps, and the statuses a real projector sends
 * — no signal, standby, unreachable — so the window can be tried without
 * the app. The images are PNGs: browsers sniff the format, so the page's
 * `data:image/jpeg` URL shows them all the same.
 */
import type { IncomingMessage, ServerResponse } from 'node:http';
import { deflateSync } from 'node:zlib';

import type { PreviewStatus, Projector } from '../src/lib/api/types.ts';

const W = 320;
const H = 180;
const BARS: [number, number, number][] = [
  [192, 192, 192],
  [192, 192, 0],
  [0, 192, 192],
  [0, 192, 0],
  [192, 0, 192],
  [192, 0, 0],
  [0, 0, 192],
];

const CRC = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buf: Buffer): number {
  let c = 0xffffffff;
  for (const b of buf) c = (CRC[(c ^ b) & 0xff] ?? 0) ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

/** Bars shifted per projector, a white bar sweeping across per frame. */
function frame(seed: number, tick: number): string {
  const raw = Buffer.alloc((W * 3 + 1) * H);
  const sweep = (tick * 23) % W;
  for (let y = 0; y < H; y++) {
    const row = y * (W * 3 + 1);
    for (let x = 0; x < W; x++) {
      const bar = BARS[(Math.floor((x * BARS.length) / W) + seed) % BARS.length] ?? [0, 0, 0];
      const lit = Math.abs(x - sweep) < 4 || y > H - 24;
      const [r, g, b] = lit ? [235, 235, 235] : bar;
      raw.set([r, g, b], row + 1 + x * 3);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(W, 0);
  header.writeUInt32BE(H, 4);
  header.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]).toString('base64');
}

interface Feed {
  clients: Set<ServerResponse>;
  status: PreviewStatus | null;
  /** Until this time the feed reads as connecting (open, Retry). */
  connectingUntil: number;
  timer: ReturnType<typeof setInterval>;
  tick: number;
}

export function mockPreview(projectors: Projector[]) {
  const feeds = new Map<string, Feed>();
  const preShow = new Map<string, { on: boolean; applying: boolean }>();
  const sse = (res: ServerResponse, name: string, data: unknown) =>
    res.write(`event: ${name}\ndata: ${JSON.stringify(data)}\n\n`);

  function statusOf(p: Projector, feed: Feed): PreviewStatus {
    const ps = preShow.get(p.id) ?? { on: false, applying: false };
    const base = { notice: null, overlay: null, preShow: ps.on, preShowApplying: ps.applying };
    const signal = p.signal === 'NO SIGNAL' ? 'No signal' : `${p.input} · ${p.signal}`;
    if (Date.now() < feed.connectingUntil) return { ...base, state: 'connecting', signal: null };
    if (p.connection === 'offline') return { ...base, state: 'unavailable', signal: null };
    if (p.power !== 'on' && !ps.on) return { ...base, state: 'notice', notice: 'noSignal', signal };
    if (p.signal === 'NO SIGNAL') return { ...base, state: 'notice', notice: 'noSignal', signal };
    const pattern = p.testPattern !== null && p.testPattern !== 'OTS:00';
    return { ...base, state: 'live', overlay: pattern ? 'testPattern' : null, signal };
  }

  function beat(id: string) {
    const feed = feeds.get(id);
    const p = projectors.find((x) => x.id === id);
    if (!feed || !p) return;
    const status = statusOf(p, feed);
    if (JSON.stringify(status) !== JSON.stringify(feed.status)) {
      feed.status = status;
      for (const c of feed.clients) sse(c, 'status', status);
    }
    if (status.state === 'live') {
      const jpeg = frame(projectors.indexOf(p), feed.tick++);
      for (const c of feed.clients) sse(c, 'frame', { jpeg });
    }
  }

  return {
    stream(req: IncomingMessage, res: ServerResponse, id: string): boolean {
      if (!projectors.some((p) => p.id === id)) return false;
      res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' });
      res.write('retry: 3000\n\n');
      let feed = feeds.get(id);
      if (!feed) {
        feed = {
          clients: new Set(),
          status: null,
          connectingUntil: Date.now() + 700,
          timer: setInterval(() => beat(id), 1000),
          tick: 0,
        };
        feeds.set(id, feed);
      }
      const f = feed;
      f.clients.add(res);
      if (f.status) sse(res, 'status', f.status);
      else beat(id);
      req.on('close', () => {
        f.clients.delete(res);
        if (f.clients.size === 0) {
          clearInterval(f.timer);
          feeds.delete(id);
        }
      });
      return true;
    },

    retry(id: string): boolean {
      const feed = feeds.get(id);
      if (!feed) return false;
      feed.connectingUntil = Date.now() + 900;
      beat(id);
      return true;
    },

    /** As in the app: Standby with the feed up, confirmed a few seconds later. */
    preShow(id: string, on: boolean): boolean {
      const p = projectors.find((x) => x.id === id);
      const s = feeds.get(id)?.status;
      if (!p || p.power !== 'standby' || (s?.state !== 'live' && s?.state !== 'notice')) {
        return false;
      }
      preShow.set(id, { on, applying: true });
      beat(id);
      setTimeout(() => {
        preShow.set(id, { on, applying: false });
        beat(id);
      }, 3000);
      return true;
    },
  };
}
