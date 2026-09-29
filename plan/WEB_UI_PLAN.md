# Web UI — Development Plan (Svelte 5 + Vite + TypeScript)

Status: `[ ]` pending · `[~]` in progress · `[x]` done

The browser page for **F7 — Local Web Monitor & HTTP API** (`ROADMAP_PLAN.md` §5). The
roadmap holds *what* the page does (access model, table, controls, alignment, API). This file
holds *how* the page is built, shipped and developed.

Design reference: artifact *Projector Grid Web Monitor*
(https://claude.ai/artifact/W5t59BABLdayaHUmaVkZu5). It's a clickable mockup (HTML + vanilla
JS) and the source for layout, tokens and behaviour. Don't copy its code as-is.

Decision (2026-09-28): **Svelte 5 + Vite + TypeScript**, a plain single-page app (no SvelteKit).

---

## 1. How the page ships

```
Phone / laptop ──HTTP──▶  PC running Projector Grid (:8080)  ──NTCONTROL/TCP──▶  projectors
   (browser)              ├─ HTTP server inside the app (shelf)
                          ├─ serves the built page from Flutter assets (assets/web/)
                          └─ /api/* + /api/events (SSE) over the existing providers
```

- The page is **part of the app build**. The Svelte build writes static files (`index.html`,
  hashed JS/CSS, fonts) into `assets/web/`. Flutter bundles them like any other asset, and the
  app's web server reads them through `rootBundle`.
- Nothing runs on the projectors, and nothing extra is installed on the show PC. Node.js is
  needed only by developers and CI.
- The page and the API always come from the same app build, so there are no version-skew
  problems between them.
- **Fully offline:** fonts, icons and everything else are bundled. No CDN, no Google Fonts,
  no analytics. Show networks are often closed.

## 2. Why this stack

| Option | Verdict |
|---|---|
| Flutter Web | ❌ 2–5 MB download and slow first paint on phones; weak tables, text selection and a11y; a second build target for a desktop app |
| Vanilla JS (like the mockup) | ❌ fine for a mockup; the real page has too much state (table layout, selection, SSE, alignment, auth) |
| React | ⚠️ works, but heavier and more boilerplate than needed |
| **Svelte 5 + Vite + TS** | ✅ small bundle (target < 150 KB gzip total), runes give fine-grained reactivity that suits live telemetry, little code per component |

No SvelteKit: there's nothing to route or server-render, which matches the app's own
"no routing" rule (CLAUDE.md). Plain `npm create vite@latest -- --template svelte-ts`.

## 3. Repository layout

```
web_ui/                         # the Svelte project (own package.json)
  package.json  package-lock.json  .nvmrc
  vite.config.ts  tsconfig.json  svelte.config.js
  eslint.config.js  .prettierrc
  index.html
  api/openapi.yaml              # the HTTP contract (source of truth for TS types)
  src/
    main.ts  App.svelte
    lib/api/                    # client.ts (fetch + auth), events.ts (SSE), types.gen.ts (generated)
    lib/state/                  # *.svelte.ts rune modules: session, projectors, alerts,
                                #   selection, tableLayout, alignment
    lib/logic/                  # pure TS, unit-tested: columns, sort, fitWidths (port of
                                #   _resizeBaseFor), selection tri-state, confirm rules, lens encoding
    lib/components/
      shell/                    # Header, Toolbar, AlertsRail, Toast, ConfirmDialog
      table/                    # DataTable, HeaderCell (sort/drag/resize), ColumnsMenu, cells/
      control/                  # ControlPanel, PowerShutter, PatternGrid, LensBlock
      alignment/                # Banner, PatternPicker, WallMap
      phone/                    # CardList, ProjectorCard, BottomSheet, PinPad
    styles/tokens.css           # colour/type/spacing tokens from the mockup (light + dark)
  public/                       # favicon + the .gitkeep placeholders (see §5)
  mocks/                        # dev-only fake API: fixtures + Vite middleware
  tests/                        # Vitest unit + component tests
assets/web/                     # BUILD OUTPUT, git-ignored (only the .gitkeep files committed)
  assets/                       # Vite's hashed JS/CSS/fonts
test/fixtures/api/              # golden JSON written by Dart tests, read by web tests
```

## 4. Tooling

| Tool | Use |
|---|---|
| Node.js LTS (24, pinned in `.nvmrc` + `engines`), **npm** | package manager; lockfile committed |
| Svelte 5 (runes only: `$state`, `$derived`, `$effect`, `$props`) | components; no legacy `writable` stores or `export let` |
| Vite | dev server, proxy, production build |
| TypeScript `strict` + `svelte-check` | types; no `any`. Pinned to 5.9: `svelte-check`, `typescript-eslint` and `openapi-typescript` don't accept TS 7 yet |
| `openapi-typescript` | generates `types.gen.ts` from `api/openapi.yaml` |
| TanStack Table (`@tanstack/svelte-table` 9, the official Svelte 5 adapter) | headless column visibility / order / sizing / sorting / grouping; installed at step 3 |
| Vitest + `@testing-library/svelte` | unit + component tests |
| ESLint (`eslint-plugin-svelte`) + Prettier (`prettier-plugin-svelte`) | lint / format |
| `@fontsource-variable/geist` + `geist-mono` | self-hosted fonts (bundled by Vite; no `src/fonts/`) |
| Playwright | later: e2e against the mock API |

No CSS framework: port the mockup's CSS as component-scoped styles on top of `tokens.css`.

## 5. Everyday commands

```bash
cd web_ui
npm ci                 # first time / after pulling
npm run dev            # Vite on :5173, /api proxied to the running app on :8080
npm run dev:mock       # same, but /api served by mocks/ (no app, no projectors needed)
npm run check          # svelte-check + tsc
npm run lint           # eslint + prettier --check
npm test               # vitest
npm run gen:api        # regenerate src/lib/api/types.gen.ts from api/openapi.yaml
npm run build          # production build → ../assets/web/
```

Then `flutter run -d windows` / `flutter build …` as usual. If `assets/web/` holds only
`.gitkeep`, the app serves a one-line "Web UI not built — run `npm run build` in web_ui/"
page instead of failing.

`vite.config.ts` essentials:
```ts
export default defineConfig({
  plugins: [svelte()],
  base: './',
  build: { outDir: '../assets/web', emptyOutDir: true, sourcemap: false },
  server: { proxy: { '/api': { target: 'http://localhost:8080', changeOrigin: true } } },
});
```
SSE works through the Vite proxy. If it buffers, set `proxy['/api'].configure` to disable
compression for `text/event-stream`.

**Keeping `assets/web/` buildable on a fresh clone.** Flutter asset directories aren't
recursive, so `pubspec.yaml` lists both `assets/web/` and `assets/web/assets/`, and
`flutter build` fails if either folder is missing. `emptyOutDir` would delete a committed
`.gitkeep`, so the `.gitkeep` files live in `web_ui/public/` and `web_ui/public/assets/`:
Vite copies `public/` into the output on every build, and the committed copies in
`assets/web/` keep a clone without Node building.

## 6. The API contract

- `web_ui/api/openapi.yaml` is the single description of every endpoint and JSON shape from
  ROADMAP §5 (`/api/login`, `/api/config`, `/api/projectors`, `/api/actions`,
  `/api/alignment/*`, `/api/events` event types).
- **TS side:** `npm run gen:api` generates the types, so components never hand-write response
  shapes.
- **Dart side:** hand-written `toJson` (project convention: plain Dart for DTOs, no codegen
  needed). A Dart test serialises sample nodes, config and alignment state into
  `test/fixtures/api/*.json` (golden files, fail on diff).
- **Web side:** a Vitest test validates the same fixtures against `openapi.yaml`. A field
  renamed on one side without the other fails CI.
- **One catalogue:** `/api/config` delivers the Monitoring column catalogue, status
  thresholds, test-pattern list and alignment presets. The page never hard-codes them (see
  ROADMAP §5 *Code*).

## 7. App-side serving (Dart)

- `lib/core/services/web_server_service.dart` uses **`shelf` + `shelf_router`** (Dart team
  packages). Once static files, auth middleware, JSON routes and SSE are all needed, a raw
  `HttpServer` router is more code than it's worth.
- **Static handler:** it maps `/` → `assets/web/index.html` and `/assets/*` →
  `assets/web/assets/*`, and reads them via `rootBundle.load`. Headers:
  - `Content-Type` from the extension;
  - `Cache-Control: no-cache` for `index.html`;
  - `Cache-Control: public, max-age=31536000, immutable` for the hashed files.
- **Security headers:** `Content-Security-Policy: default-src 'self'; img-src 'self' data:;
  style-src 'self' 'unsafe-inline'`, `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: no-referrer`.
- **Auth** (PIN → session cookie / bearer) is shelf middleware in front of `/api/*` except
  `/api/login`. The rules are in ROADMAP §5 *Access model*.
- **SSE:** one `StreamController` per client, fed from `ref.listen(...)` in
  `web_server_provider.dart`, with a 15 s heartbeat comment line so proxies and phones keep
  the connection open.

## 8. Front-end conventions

- **One app, two layouts:** the desktop table vs the phone cards, switched by a width
  breakpoint (≈ 900 px) with media/container queries. Same state underneath.
- **State:** `lib/state/*.svelte.ts` modules export rune-based classes/objects.
  - The SSE handler is the only writer of server data.
  - Components read from state modules and call `api.*` for actions. They never `fetch`
    directly.
- **Pure logic in `lib/logic/`** with unit tests: fit-to-width + `_resizeBaseFor` maths,
  sorting per column, tri-state selection, confirmation rules (power/home always; shutter/tp
  when > 1), lens command encoding. These mirror Dart code, so the tests use the same cases
  as the Dart tests.
- **Table layout** is persisted in `localStorage` under a versioned key
  (`pg.table.v1`). The first load seeds it from `/api/config`. Wrap every access in
  try/catch.
- **Theming:** `tokens.css` defines light and dark tokens. It follows
  `prefers-color-scheme` with a manual override stored locally. Status colours come only
  from tokens.
- **Accessibility:**
  - real `<button>`s;
  - `aria-sort` on sorted headers;
  - `role="checkbox"` + `aria-checked="mixed"` for tri-state;
  - focus-visible rings;
  - `prefers-reduced-motion`.
- **Browser support:** current Chrome / Edge / Firefox / Safari, iOS Safari 16+.
- **Commits:** same prefixes as the app (`feat(web): …`, `fix(web): …`).

## 9. CI

Add to the workflow planned in ROADMAP §7.4, before the Flutter steps:
```
cd web_ui && npm ci && npm run gen:api && git diff --exit-code src/lib/api/types.gen.ts
npm run check && npm run lint && npm test && npm run build
```
Then the existing `build_runner → format → analyze → flutter test`. The release build runs
`npm run build` first, so `assets/web/` is always filled in shipped installers.

## 10. Implementation order

1. `[x]` **Scaffold:**
   - Vite `svelte-ts` template in `web_ui/`, tooling from §4, `tokens.css` + fonts;
   - `assets/web/.gitkeep` + `.gitignore`; `pubspec.yaml` asset entry;
   - `web_server_service.dart` serving the built page;
   - Preferences → Web Access tab with enable + port.
   - No `/api/*` yet, so nothing but the static page is exposed before auth exists.
   - **Done when:** a phone opens the page from the app.
2. `[ ]` **Contract + auth + read-only data** (auth moved here from step 5, owner
   2026-09-29 — the API must never be reachable without a PIN):
   - `openapi.yaml`, generated types, golden fixtures;
   - server auth: Viewer PIN (salted hash in settings), `/api/login` / `/api/logout`,
     session cookie + bearer, 12 h idle expiry, lockout, *Sign out all clients*;
     Web Access tab gets the Viewer PIN field;
   - a plain login page (single PIN field + project name); the phone PIN pad stays in step 5;
   - `/api/config`, `/api/projectors`, `/api/groups`, `/api/alerts` (returns `[]` until
     ROADMAP §4), `/api/events`;
   - `mocks/` + `dev:mock`.
3. `[ ]` **Viewer desktop table:** columns, sort, show/hide, presets, reorder, resize,
   auto-fit, fit-to-width, density, group-by; status colours; filters + search.
4. `[ ]` **Alerts rail / drawer** (needs ROADMAP §4 alerts provider; show an empty rail until
   then).
5. `[ ]` **Operator auth:** *Allow control* + Operator PIN, operator role on sessions,
   *Unlock control* / *Lock*, phone PIN pad.
6. `[ ]` **Operator controls:** selection model, control panel, confirmations, toasts with
   the §10 result summary, `/api/actions`.
7. `[ ]` **Alignment on the web:** banner, presets Geometry / Color / Custom, pattern
   pickers, read-only banner for viewers. No Identify until ROADMAP §3.1 exists in the app.
8. `[ ]` **Phone layout:** cards, expand, select bar, control / alerts / pattern sheets,
   wall map.
9. `[ ]` **CI + docs:** workflow steps; add the `web_ui` commands to `DEVELOPMENT.md`
   and CLAUDE.md *Commands*.

## 11. Open points

- ~~TanStack Table adapter~~ — decided at step 1: the official `@tanstack/svelte-table` 9
  (stable, Svelte 5).
- ~~Precompressed assets~~ — not doing: the bundle is small and it's a LAN.
