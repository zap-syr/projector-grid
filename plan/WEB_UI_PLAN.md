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
      map/                      # MapView, MapTile (Map view; tiles reused by WallMap)
      preview/                  # PreviewDialog (Remote Preview)
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
| ~~TanStack Table~~ | dropped at step 3 (owner, 2026-09-30): the table must match the app's Dart logic exactly (sort keys, `_resizeBaseFor`, group sections, reorder rule), so it's ported as small pure functions in `lib/logic/` instead of wrapped in a table library |
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
  `/api/alignment/*`, `/api/preview/{id}`, `/api/events` event types).
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

- **One app, three views:** the table, the cards and the Map, offered per screen (width,
  height and touch, `state/device.svelte.ts`; see steps 8 and 9). Same state underneath.
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
- **Logo:** the app's own icon (`src/assets/app_icon.png`, copied from the macOS
  AppIcon set; favicon `public/favicon.png`), not a generic projector glyph (owner,
  2026-09-29).
- **Theming:** `tokens.css` defines light and dark tokens. It follows
  `prefers-color-scheme` with a manual override stored locally. Status colours come only
  from tokens.
- **Accessibility:**
  - real `<button>`s;
  - `aria-sort` on sorted headers;
  - `role="checkbox"` + `aria-checked="mixed"` for tri-state;
  - focus-visible rings;
  - `prefers-reduced-motion`.
- **Browser support:** current Chrome / Edge / Firefox / Safari; the floor is `color-mix()` —
  iPadOS / iOS Safari 16.2+, Chrome / Edge 111+, Firefox 113+, Samsung Internet 22+. Older
  iPads (e.g. iPad Air 1, iOS 12) aren't supported, and there's no fallback page (owner,
  2026-09-30).
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
2. `[x]` **Contract + auth + read-only data** (auth moved here from step 5, owner
   2026-09-29 — the API must never be reachable without a PIN). Notes: the page shows a
   temporary `InterimTable` until step 3; `/api/session` (no auth) gives the login page the
   project name; sessions live in memory (an app restart signs everyone out); lockout
   doubling stops at 1 h; fixtures regenerate with
   `flutter test --update-goldens test/unit/web_api_dto_test.dart`.
   - `openapi.yaml`, generated types, golden fixtures;
   - server auth: Viewer PIN (salted hash in settings), `/api/login` / `/api/logout`,
     session cookie + bearer, 12 h idle expiry, lockout, *Sign out all clients*;
     Web Access tab gets the Viewer PIN field;
   - a plain login page (single PIN field + project name); the phone PIN pad stays in step 5;
   - `/api/config`, `/api/projectors`, `/api/groups`, `/api/alerts` (returns `[]` until
     ROADMAP §4), `/api/events`;
   - `mocks/` + `dev:mock`.
3. `[x]` **Viewer desktop table:** columns, sort, show/hide, presets, reorder, resize,
   auto-fit, fit-to-width, density, group-by; status colours; filters + search. Reorder is by dragging headers
   only, like the app — the Columns popover has no drag list. Group sections collapse and
   show the app's worst-status pill.
4. `[~]` **Alerts** (F5 is done; design decided 2026-10-06, ROADMAP §5 *Alerts*, mockup
   https://claude.ai/artifact/N6goiSv7DuMTYT15rophYT). Order:
   - `[x]` API (2026-10-06): `GET /api/alerts` (`{now, alerts}`, the app's clock so a
     phone with a wrong clock shows right durations), SSE `alerts`,
     `POST /api/alerts/acknowledge` (`ids` / `projectorId` / `rule` / `all`, operators
     only; the Event Log line names the web source), `errorItems` on projectors (decoded
     by the app's code table); openapi, golden fixture, mocks (`dev:mock` has alerts of
     every rule and PJ-03 dropping its signal every 20 s).
   - `[x]` Rail + drawer / sheets with the Active alerts panel (`AlertsPanel`, one
     component, desktop and touch layouts; placement from `device.control`), viewer
     line, sound switch (the app's `assets/sounds/*.wav`, imported by Vite).
   - `[x]` Header *Alerts* filter (drops the word below 1280 px and on phones so the
     header stays one row), card / tile badge, Errors tags, alert tints, group pills
     (icon + number on phones), *Only with alerts* in Select ▾.
   - `[x]` New-alert cues: tab title count, favicon dot, toast with *Show*, tick pulse,
     sound; the first `alerts` after a (re)connect raises none.
   - Checked in Chrome with `dev:mock` at phone 360/390/430 and 740/844/932 wide,
     tablet 768/820/1024 upright and 1024/1180/1366 sideways (touch emulated), desktop
     1024–1920: no clipped button text in the alerts UI; the header stays one row
     everywhere but upright phones and tablets (two rows by design). Still to do: a
     check against the real app.
5. `[x]` **Operator auth:** *Allow control* + Operator PIN, operator role on sessions,
   *Unlock control* / *Lock*, phone PIN pad. `dev:mock`: Viewer PIN 1234, Operator PIN
   5678. Notes: `POST /api/unlock` / `/api/lock` return
   404 while *Allow control* is off; an `access` SSE event tells a session's other tabs
   about unlock / lock and every page when *Allow control* is switched; switching it off
   drops operators to viewer without signing anyone out; the PIN pad shows at ≤ 600 px or
   on touch screens.
6. `[x]` **Operator controls:** selection model, control panel, confirmations, toasts with
   the §10 result summary, `/api/actions`. Notes: auth-error projectors can't be selected either (they'd only be skipped), so the
   Select ▾ menu has no separate *All online*; lens steps only toast on failure; the lens
   encoding moved to `domain/lens_commands.dart` and the control bar uses it too; web
   commands carry "(Web · IP · operator)" in the Event Log. After the owner's review
   (2026-09-30): press-and-drag across rows sweeps them in (or out, if the press was on a
   selected row); the panel follows the app's order and adds OSD, Input, Lens calibration
   and Lens type (lists from `domain/control_options.dart` via `/api/config`); input asks
   for >1 projector, calibration and lens type always; the panel can be hidden (per
   browser); no "moves N lenses" warning. Second review: block titles styled like the app's
   group headers; desktop lens controls are the app's (Lens shift D-pad and separate Focus /
   Zoom rows with fast / normal / slow buttons, its lens_shift icons), the phone width keeps
   a speed switch with single-step buttons; confirm dialogs ask a question ("Close the
   shutter on 5 projectors?") instead of listing names; group names stay pinned when the
   table scrolls sideways.
7. `[x]` **Alignment on the web:** banner, presets Geometry / Color / Custom, pattern
   pickers, read-only banner for viewers; on the phone the pattern sheets and the wall
   mini-map. No Identify until ROADMAP §3.1 exists in the app. Skipped for now (owner,
   2026-09-30) — done after steps 8 and 9; the phone wall mini-map reuses step 9's Map tiles.
   Step 10 (Remote Preview) follows it.
   - **API:**
     - `GET /api/alignment`, `POST /api/alignment/{op}` (operator only, 404 without
       *Allow control*);
     - an `alignment` SSE event after the snapshot and on every change;
     - `Config.alignmentPresets`;
     - each op calls `AlignmentNotifier`;
     - `enter` takes the page's selection (`enter({selection})`), so a web entry scopes
       like the app.
   - **Screens:**
     - Where the side panel lives (desktop, sideways tablet): the orange banner under the
       header, the toolbar's bulk selector turns into a role legend, and the table / cards /
       Map show the app's rings and markers.
     - On touch layouts (phone, upright tablet) the list gives way to an Alignment screen:
       big ◀ ▶, the toggles, the wall mini-map, the preset switch, Focused / Others rows with
       swatch sheets, the lens and *Exit alignment*.
     - Viewers get the same screens read-only.
   - **Operator:**
     - A click or tap on a projector in the mode focuses it.
     - The selection is pinned to the focused projector, so the Control panel turns into
       *Lens · PJ-xx*.
     - Keys: `,` / `.` (`<` / `>`) step, `A` Show all, `N` Neighbours.
     - Deliberately **no Esc to exit** on the web: Esc already closes popovers and sheets, and
       a stray one would restore the whole wall.
   - The app's *Ctrl+click* manual neighbours and *Adjust ▾* stay app-only.
   - **Owner's review (2026-09-30):**
     - The banner has no projector name (the ring names it), and the pattern pickers show
       only the swatch. The lens panel is titled with the IP.
     - A toggle that's on keeps its dark pill (hover only with a mouse). The phone's ◀ ▶
       bar is pinned while the lens is scrolled to.
     - Touch screens get a 60 px banner and toolbar with 44–48 px controls in one row.
       Below 1280 px, Columns and Control turn into icons, and the Control icon is in the
       accent colour.
     - Cards keep a fixed two-line summary (power · shutter + pattern, then signal ·
       temperatures), with the chevron in the top-right corner. The touch minimum width is
       280 px (upright iPads get 2 columns), so no status reflows or overflows.
8. `[x]` **Phone and tablet layouts:** cards, expand, select bar, control sheet, Table /
   Cards switch. Layout per screen (owner, 2026-09-30; `device.svelte.ts`):

   | Screen | List | Control |
   |---|---|---|
   | Phone upright (≤ 600 px) | cards, 1 column | bottom sheet |
   | Phone sideways (touch, height ≤ 500 px) | cards, up to 3 columns | right-hand sheet |
   | Tablet upright (touch, < 1024 px) | cards, 2 columns | bottom sheet, lens in a second column |
   | Tablet sideways (touch, ≥ 1024 px) | Table / Cards switch, cards by default (3 columns) | side panel |
   | Desktop (mouse) | Table / Cards switch, table by default | side panel |

   Notes: the switch is remembered per browser (`pg.listMode.v1`), apart from the table
   layout; a narrow desktop window keeps its choice. Cards are sorted by IP (owner,
   2026-10-02; was layout order) in one section per group (collapse shared with the table), a plain grid without groups; the
   operator taps a card to select it, the viewer to open its details, the chevron does it
   for both. Details open one at a time as a full-width strip under the card's row
   (sliding in, with a pointer at the card), so the grid never goes ragged
   (`withDetails` in `logic/rows.ts`). Selection follows PatternFly's bulk selector on
   every screen (owner, 2026-09-30): one fixed-width control first in the toolbar —
   `[box │ "3 selected" ▾]` — whose box selects all shown when none are, and clears
   the selection when some or all are (touch screens have no Esc; group-header boxes
   act the same within the group). No separate count or *Clear* anywhere else: the
   Select ▾ menu keeps only the presets, the Control panel header shows no count, and
   the touch layouts' bar under the list is just the *Control* button. *Columns* sits
   left of the Table / Cards switch so the switch doesn't move. Touch screens get the big lens block — 64 px shift arrows 10 px apart around an
   inert centre, a speed switch, separate Focus / Zoom blocks with 56 px Near / Far and
   Out / In buttons, Lens settings (Home, calibration, type) last — plus comfortable rows
   on the first visit and 40 px checkbox hit areas; the app's fast / normal / slow buttons
   stay for the mouse. Phones and upright tablets fold the header (icons, short labels).
   Esc closes the confirm dialog, then the sheet, then clears the selection. The alerts
   sheet waits for step 4, the pattern sheets and wall map moved to step 7.
9. `[x]` **Map view** (owner, 2026-09-30; ROADMAP §5 *Map*): the project's card layout as
   a third view, on tablets and desktop only.
   - **Switch:** `listMode` gains `'map'`. The switch shows *Table / Cards / Map*, or
     *Cards / Map* on upright tablets. On a phone a stored `'map'` falls back to cards.
   - **Data:** no API change, because `x` / `y` are already in `/api/projectors`.
   - **Logic in `lib/logic/map.ts`,** unit-tested:
     - the layout bounds;
     - the fit scale;
     - the tile rectangle at a zoom;
     - the marquee hit test.
   - **Components in `components/map/`:** `MapView` with absolutely positioned HTML tiles
     (clicks, focus and a11y come for free), and `MapTile`, which the step 7 wall mini-map
     reuses.
   - **Zoom:** *− / + / Fit*, a two-finger pan and pinch on touch, Ctrl + wheel with the
     mouse. Zoomed far out, tiles show only the dot and name.
   - **Filters and search** dim the tiles that don't match.
   - **Selection:** as ROADMAP §5 *Map* describes. The mouse behaves like the app's canvas,
     and on touch one finger draws the marquee and two fingers move the map. Details open in
     a popover: the viewer taps a tile; the operator right-clicks it or long-presses it.
10. `[x]` **Remote Preview** (owner, 2026-09-30; ROADMAP §5 *Remote Preview on the web*),
    done after step 7. One projector, for both roles; Pre-show for operators only.
    Owner's review (2026-10-01): power moved into the header after the IP, no shutter
    status under the image (the frame's colour says it); the browser's tap highlight is
    off page-wide, since it painted a tapped row over the dialog. Not yet tried against a
    real projector's image.
    - **App side:**
      - `GET /api/preview/{id}` as SSE, with `frame` (base64 JPEG) and `status` events;
      - one shared `RemotePreviewController` per projector, via the existing
        `remotePreviewProvider`, kept alive while a web or app watcher exists, and closed a
        few seconds after the last one leaves;
      - Pre-show as `POST /api/preview/{id}/preshow` (operators only) and *Retry* as
        `POST /api/preview/{id}/retry` (anyone watching). Not an `/api/actions` action: it
        goes over the shared preview socket, not NTCONTROL, and needs that feed open. Its
        state moved from the app's dialog into `preShowProvider`, so the app and the pages
        show the same pre-show;
      - the contract in `openapi.yaml`, with golden fixtures for the events.
    - **Web side:** `components/preview/PreviewDialog` (a dialog on desktop, a full-screen
      sheet on phones).
      - The shutter-coloured frame and the overlays match the app's `preview_viewport.dart`.
      - *Retry*, and *Pre-show* (Standby only).
      - Entry points (owner, 2026-10-01): the card details strip, the Map popover (tap,
        right-click, long press), and a *Preview* column in the table with an icon button
        per row (hideable and draggable like any other column). Not in the Control panel,
        not in Alignment mode.
      - ◀ ▶ in the window step to the neighbouring projector, in the order of the view it
        was opened from: the table's / cards' sort, filters and search; the Map in reading
        order (left to right, top to bottom). Filtered-out projectors are skipped, offline
        ones stay. The order is frozen when the window opens (a temperature sort mustn't
        reshuffle it), wraps at the ends, and shows "3 / 24". Selection doesn't change.
        Keys ← → and Esc; a swipe on phones. Only one stream at a time.
    - **Mock:** `dev:mock` streams generated frames.
    - Multiview is left for later.
11. `[x]` **CI + docs:** workflow steps; add the `web_ui` commands to `DEVELOPMENT.md`
   and CLAUDE.md *Commands*.
   - `ci.yml`: a `web` job (Node 24, Ubuntu) — `types.gen.ts` regenerated and diffed
     against the committed one, then `check`, `lint`, `test`, `build`.
   - `release.yml`: both platforms build `web_ui/` before the Flutter build, since
     `assets/web/` isn't in git and a release would otherwise ship without the page.

## 11. Open points

- ~~TanStack Table adapter~~ — not used; see §4.
- ~~Precompressed assets~~ — not doing: the bundle is small and it's a LAN.
