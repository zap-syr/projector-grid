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
| `@fontsource-variable/inter` + `@fontsource/ibm-plex-mono` | self-hosted fonts, the app's (bundled by Vite; Inter latin + cyrillic in `styles/fonts.css`, Plex Mono latin) |
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
- **Theming:** `tokens.css` holds the app's palette (`app_theme.dart`) for light and dark:
  `--win --bar --card --menu --field --soft`, text `--t1..3`, `--primary --pc`, status
  `--ok --warn --err`, `--align`; the older names (`--surface`, `--muted`, `--accent`, …)
  are aliases of them. It follows `prefers-color-scheme` unless the role menu's *Theme*
  pins one (`state/theme.svelte.ts`, `pg.theme.v1`, `data-theme` on `<html>`). Status
  colours come only from tokens, and only for status. Colours a canvas paints in JS read
  the tokens through `state/themeColors.svelte.ts`.
- **UI text** follows the app's visual rules (`projector-grid-visual-rules`): no `·` or
  dashes (commas, colons, parentheses), sentence case, projectors named by IP or
  model + IP (`RZ34K (192.168.0.41)`), never the model alone.
- **Layout stability:** buttons, cards and rows keep their size and place across states
  and roles: reserved slots (the card's error line, the Pre-show spinner), panels under
  the full-width toolbar, overlays instead of reflow. The bulk selector is sized
  for "999 selected" and grows only for the hidden count, with no room reserved for it
  (owner, 2026-10-22).
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
4. `[x]` **Alerts** (F5 is done; design decided 2026-10-06, ROADMAP §5 *Alerts*, mockup
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
     everywhere but upright phones and tablets (two rows by design). Checked against the
     real app with the simulator (2026-10-07, owner): error and signal-loss alerts, no
     bugs found.
   - `[x]` After that check (2026-10-07): the bottom alerts sheet keeps a fixed height
     (88dvh, 70dvh on tablets), so switching the grouping or folding everything no longer
     shrinks it; the sheets' drag handle is gone (they can't be swiped away, and both
     have a close button).
   - `[x]` Sound on iPhone (2026-10-07): it never played there, since iOS unlocks audio per
     element and each alert made a new `Audio`. Now one `AudioContext` with the two sounds
     decoded once, unlocked by the Sound tap or any tap after a reload; the button turns
     amber ("Tap for sound") while the browser still blocks it. Not done, by the owner's
     choice: playing through the silent switch (`audioSession`), sound with the screen
     off or the browser in the background.
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
    off page-wide, since it painted a tapped row over the dialog. Checked against a real
    projector (2026-10-07, owner).
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

12. `[x]` **Manual status refresh** (owner, 2026-10-07; ROADMAP §5 *Manual status
    refresh*): an operator-only header button beside *Alignment* (at the end of the
    filter row on upright phones) that polls every projector
    now through `POST /api/refresh` (the app's `refreshAll`); it spins until the cycle is
    done and ignores presses meanwhile, then shows a green check for 1.5 s instead of a
    toast (owner); a locked control still gets a toast. openapi, mock (1.5 s delay), route tests. Checked
    in Chrome with `dev:mock` on desktop and at 360 / 390 px phone width; not yet against
    the real app.

13. `[ ]` **Redesign to the app's look** (owner, 2026-10-21). After the app's dialog and
    Monitoring redesign (`DIALOG_REDESIGN_PLAN.md`) the page no longer matches it. The
    boards are in the *Web Access page* section of the design canvas
    https://claude.ai/artifact/AL2c8Kh9aoXrrv2eUmVdcJ; each phase names the boards it
    follows. The `projector-grid-visual-rules` skill applies to the page as it does to
    the app (UI text without `·` or dashes, projectors named by IP or model + IP, status
    colours only for status). This step supersedes these older notes: the step 8 note
    "the operator taps a card to select it, the viewer to open its details, the chevron
    does it for both… details as a full-width strip", the step 10 *Preview* column, and
    the step 7 note on the card summary.

    The shell, Alerts and Remote Preview are drawn on a second canvas,
    https://claude.ai/artifact/THMEEesSxnwzgrQVCYDwqi (*Projector Grid web redesign: shell*,
    approved by the owner 2026-10-21).

    **Decisions (owner, 2026-10-21), before implementation:**
    - **Status from the app:** each projector's JSON carries `status: {level, problems[]}`
      from `monitoringStatusOf` (`kind`, `level`, `badge`, `title`, `value`, `flag`,
      `since`), so the row stripe, *Attention*, *Needs attention* and the group summary
      can't drift from the app. No TS port of the status logic.
    - **Quick filters** replace the header's *All / Online / Offline / Alerts*: the *Alerts*
      filter goes. Select ▾ loses *All projectors* (the box does it) and becomes *Online*,
      *Attention* (was *Only with alerts*), *Standby*, *Invert*, then the groups. Presets pick
      from **all** projectors, not only the shown ones.
    - **Hidden selection (variant B):** selected projectors a search or filter hides stay
      selected and get every command. Desktop: a pill *4 hidden* inside the fixed-width bulk
      selector (tooltip lists the IPs; a click clears search and filter, the selection
      stays); the Control header reads *5 selected, 4 hidden*. Phone: a line under the
      filters, *4 selected are hidden* with *Show all*. While any selected projector is
      hidden, every command asks first, and the confirmation names the hidden ones:
      Power, Shutter, OSD, Input, Test pattern and Lens setup. Lens shift, Focus and Zoom
      steps go without a dialog (a burst of steps can't stop for one); the Lens card's
      header then reads *5 projectors, 4 hidden*. *Hidden* means removed from the table or
      the cards by the search or a quick filter only: tiles the Map dims stay on screen,
      and a collapsed group's box already shows its partial selection, so neither counts.
    - **Temperature text** follows the alert, as the app's; only the bars go by reading.
    - **Density** stays on the web with the app's two-line metrics
      (`monitoring_data_table.dart`): Compact row 46 / header 36 / group 38, Standard
      52 / 40 / 40, Comfortable 60 / 44 / 44. The Projector column is always shown and
      pinned.
    - **Errors column:** the first badge, *+N* and the popover of all codes.
    - **Viewer details:** the details open over the table or the cards, which keep their
      full width (owner, 2026-10-22; was: the table narrows by 344 px); a second click on
      the same row closes them (a card the same); the viewer's row action is Remote
      Preview only. The viewer's
      table has no checkbox column, bulk selector or Control toggle, as today.
    - **Cards stay the default** on every touch screen until the user picks a view.
    - **Fonts:** latin and cyrillic subsets.
    - **Logo:** wherever a board draws the blue tile with a projector glyph (the header's
      left edge, the sign-in card, the PIN pad), the page shows the app's own icon
      (`AppLogo`, `src/assets/app_icon.png`, §8), as it does today. The glyph is only a
      placeholder on the boards (both canvases); they are not redrawn.
    - **Theme switch:** System / Light / Dark (icon segmented control) in the role menu;
      stored per browser, System by default.

    **Phase 1: shared foundation.** Nothing changes in behaviour; every later phase
    builds on it.
    - Fonts Inter + IBM Plex Mono (self-hosted `@fontsource`, replacing Geist), tokens
      in `tokens.css` from the app's theme (dark values as on the boards: window
      `#191C20`, bar `#1D2024`, card `#212429`, primary `#AAC7FF`, …; light from
      `app_theme.dart`).
    - `lib/logic/labels.ts`, one module for every status word, mirroring
      `monitoring_format.dart` / `ProjectorStatusStyle`: power *On / Warming up / Cooling /
      Standby*, shutter *Open / Closed*, errors *None* (*Unknown* while offline),
      connection *Online / No login / Wrong login / Offline*, group *None*. Replaces the
      upper-case words, `Auth Error` and `—` in `logic/cells.ts`.
    - `lib/logic/signal.ts`: a port of `signalStateOf` (`domain/signal_state.dart`):
      green with the resolution; red *No signal* only while the projector is on; grey
      *No signal* / *Unknown* otherwise. Unit tests with the Dart cases.
    - Temperature **bars** by reading against `/api/config.thresholds` (amber over warm,
      red over hot), as the app's; the **value's colour** follows the active alert, as the
      app's (owner, 2026-10-21).
    - Shared components (`components/status/`), used by the table, cards, details and Map
      alike, never re-drawn per view:
      - `StatusPill` (22 px, fully rounded, 14 % fill, 35 % border, as `status_pill.dart`);
      - `SignalPill`, `ConnectionBadge` (Online green dot, No login blue unlock, Wrong
        login amber lock, Offline red), `GroupPill`;
      - `ProblemBadge`: the projector's codes only, amber *Warning H001*;
      - `PowerState`, `ShutterState`: the closed shutter has its own crossed-eye icon, the
        shutter is grey in standby, standby is red;
      - `TestPatternThumb` (+ name where the app shows it), `TemperatureLine` (value + bar
        with the threshold mark), `TemperatureText` (coloured value only).

    **Phase 2: API.**
    - The column catalogue becomes the app's two-line one
      (`monitoring_table_columns.dart`): Projector (IP, model under it), Group, Power,
      Shutter, Input and signal, Temperature, Runtime, AC, Errors, Connection, Test
      pattern. No Serial number column (the details show the serial), no Preview column
      (a row action now). `/api/config` columns, presets and defaults come from it; the
      old web catalogue (`monitoring_columns.dart`) goes. The table layout key moves to
      `pg.table.v2`, so stored v1 layouts are dropped, not migrated.
    - `lastSeen` on projectors (ISO, null while answering), for *RQ25K, last seen 16:41*.
    - `status` on projectors (see the decisions above); a projector event is sent when its
      status changes too.
    - `openapi.yaml`, `npm run gen:api`, golden fixtures, mocks.

    **Phase 3: desktop table and Control panel** (boards *Web: desktop 1440, table…*,
    *…table without groups, Columns menu open*, *Control panel states…*).
    - Data bar: bulk selector, search *Search IP, model, serial*, quick filters *All /
      Online / Attention / Offline / Standby* with counts (an empty one stays, dimmed;
      on phones and tablets the app's compact step, the mark and the count with the
      word in the tooltip, so all five fit without scrolling), the
      view switch as icons, Columns, the Control toggle. The filters leave the header in
      this phase (the header itself is restyled in Phase 8). The new Select ▾ presets and
      the hidden selection (variant B, with its confirmations) land here too.
    - Two-line rows, grouped or flat; the Columns menu with *Group by*, presets, column
      checkboxes and *Fit to width*. A row's left edge carries a 3 px stripe by level
      (amber warning, red error, grey offline); an offline row dims every cell but
      Projector and Errors. Temperature with bars on the desktop table only.
    - Row actions at the row's end: *Remote Preview*, then *Details* (ⓘ).
    - The column header row has no select-all checkbox: the bulk selector in the data
      bar does that (and the group headers' boxes for a group). A group header's box sits
      in the rows' checkbox column, right above the row boxes, as on the page today.
    - Selection as now (click, sweep, Shift range). A selected row: 8 % primary fill and the
      ticked box. The row whose details are open: 16 % fill and a filled ⓘ, **no
      outline**. Both can be true at once.
    - Control panel restyled as the app's control bar: Power / Shutter / OSD rows of
      outlined buttons (green icon for what turns the picture on, red for off); Input +
      *Set*; Lens shift cross with Home in the card header, Focus / Zoom; Lens setup
      folded; Test pattern: *Off*, thumbnails, dropdown + *Show*. Controls 36 px; with
      nothing selected they stay enabled and send nothing.
    - Control header in two lines (board *Web: Control header…*): *No projectors
      selected* / `RZ34K (192.168.0.44)` with ⓘ that opens its details / *3 selected*. The
      ⓘ keeps its place when hidden, so ✕ never moves.
    - Alerts rail: the bell with its badge, the ticks and the vertical *Alerts*.

    **Phase 4: one details panel for every view** (boards *…projector panel with the
    serial*, *…3 selected, details of .44 in place of Control*, *…viewer, a row click
    opens the details*, *Phone: the info button opens the details sheet*, *Tablet
    portrait 820: the info button opens the details sheet*).
    - `ProjectorDetails`, one component: header (status dot, IP in mono, `GroupPill`, then
      *RZ34K, serial SH4110044*, ✕); sections *Needs attention* (reading, limit, since),
      *Status* (power, shutter, input, signal pill, test pattern with thumbnail and
      name), *Temperature* (bars with the threshold mark), *Runtime and power*
      (projector, light source, AC, errors); *Preview* and *Web UI* (opens
      `http://<ip>`) as two tonal buttons of equal width. No *Find on canvas*.
    - **Desktop and tablet sideways:** the panel takes the Control panel's place at the
      same width, so the table doesn't reflow. The operator opens it with ⓘ (row, card,
      or the Control header with one projector selected); a strip *‹ Control, 3 selected*
      above it, ✕, Esc and ‹ bring Control back with the selection untouched; ⓘ on
      another projector switches the panel. The Control toggle stays on meanwhile.
    - **Viewer:** no Control and no strip; a click on a row or card opens the panel.
    - **Phone and tablet upright:** a bottom sheet (variant A, owner 2026-10-21; the inline
      strip of variant B was not chosen): one column on the phone, two on the tablet
      (*Needs attention* + *Status* | *Temperature* + *Runtime and power*). ⓘ on the
      card opens it; *Control* (the phone's bottom bar, the tablet's top bar) opens the
      Control sheet as now.
    - **Map:** the popover beside the tile keeps its place and triggers (operator: right
      click or long press; viewer: click) and shows the same sections.
    - `CardDetails.svelte` and the strip logic (`withDetails`) go.

    **Phase 5: tablet sideways table** (board *Web: tablet landscape 1180, touch, a row
    tap opens the details, the checkbox selects*).
    - A tap on the row opens the details in the Control's place; the checkbox column
      (52 px, set off by a hairline) is the only selection target. No ⓘ and no action
      column on touch rows; Preview is in the details.
    - Temperatures as coloured text, no bars.
    - **Large tablets** (owner, 2026-10-21; boards *iPad Pro 13 landscape 1366…*,
      *iPad Pro 13 portrait 1024…*): the touch table is offered wherever the screen is
      ≥ 1024 px wide, so on an iPad Pro 13" either way up. Sideways it is the table
      above with more columns. **Upright** (touch and `orientation: portrait`), the
      Control panel and the details open as bottom sheets whatever the width, so the
      table keeps the full width (a 340 px side panel would leave it ~630 px).
      `controlPlacement` in `device.svelte.ts` gains that rule. Upright screens under
      1024 px (iPad Pro 11", iPad Air) stay cards only.
    - **Owner's review (2026-10-22), done with Phase 5:**
      - The data bar runs the whole width above the list and the side panel; Control
        and the details start under it, so opening either never moves its buttons. The
        alerts rail keeps the full height.
      - With no Control beside the list (a viewer, or Control hidden) the details open
        over the table or the cards, as the app's projector panel does; with Control
        open they take its place as before. The Control button closes open details.
      - One group line for the table and the cards (`GroupHeader`: box, chevron,
        colour square, name, the app's summary); a click anywhere on it folds the group.
        A *Groups* toggle left of *Columns* serves both views (*Merge into groups* left
        the Columns menu); the phone keeps the last choice.
      - Cards are all one height (the error line is always reserved) and the whole card
        answers a click; a viewer's card has no room kept for ⓘ.
      - The bulk selector's hidden count is an amber eye-off icon with the number, no
        word. (Later the same day: the selector is sized for *999 selected* only, and
        the count widens it while selected projectors are hidden; no room reserved.)
      - On touch layouts the *Control* bar lies over the Map, so its tiles don't move;
        only the zoom buttons step up.
      - The Map's Phase 4 popover, the touch tables' Preview in the details and the
        phone's sheets are unchanged.

    **Phase 6: cards** (boards *Web: desktop 1440, cards with the info button…*, *Phone:
    cards, the info button and the Control button*, the tablet boards). The card's
    layout is replaced by step 14 (Extended and Compact).
    - Card: checkbox; IP in mono with the alert badge; model under it (*, last seen 16:41*
      while offline); power and shutter states; input + `SignalPill` (ellipsized when
      narrow); then *In 25 °C   Ex 39 °C* on its own line, coloured by the alert. Two lines
      for input / signal and temperatures, so nothing overflows; the card grows taller.
    - ⓘ in the top-right corner (32 px with a mouse, 44 px on touch) replaces the chevron.
      Operator: a tap on the card or the checkbox selects, ⓘ opens the details. Viewer:
      no ⓘ, a tap on the card opens the details.
    - Selected: 2 px primary border and tint. Open: a brighter fill and a filled ⓘ.
    - Offline (as the app's compact tile): dashed border, grey IP, no power / shutter, a
      grey *Offline* pill where the signal goes.
    - The test-pattern thumbnail stays as it is (no name; the app's Monitoring cards show
      none).
    - Touch Control sheets (and the sideways tablet's touch side panel) take the
      desktop panel's cards at finger size (boards *Phone: Control sheet*, *Tablet
      portrait 820*; done after the owner's review, 2026-10-22): Power / Shutter / OSD
      as 60 px rows with 44 px green / red icon buttons; Input card; Lens card with
      Home as a 44 px round button in its header, the speed switch, 64 px shift
      arrows, *Focus* / *Zoom* rows with 56 px buttons, *Lens setup* folded last (the
      phone's Alignment screen keeps a full-width *Home position* above it). The
      test pattern:
      - **Tablets** (upright and sideways; boards *Tablet landscape 1180: test pattern as
        on the desktop…*, the tablet upright Control sheet) take the desktop layout at
        44 px: *Off* (red crossed icon), four quick swatches (Color Bar Vert, Cross
        Hatch, White, Black), then a native `<select>` of every pattern (as `OptionRow`;
        the closed field shows the current swatch beside the name, the list itself is
        the system's: names only, the current one ticked) and *Show*. The tile grid made the upright sheet's
        left column far taller than the lens column (owner, 2026-10-21).
      - **Phone** (board *Phone: test pattern in the Control sheet…*): a full-width *Off*
        (52 px), 74 px tiles in 4 columns with the swatch and the name, the current
        pattern framed in primary when one projector is selected, *More patterns* /
        *Fewer patterns* under the grid.

    **Phase 7: Map tiles** (board *Web: desktop 1440, Map tiles as the app canvas card…*).
    - Tile drawn like `projector_card.dart`: the header tinted by `cardHeaderTone` (green
      on, amber warming / cooling / login failed, red standby; offline a stronger red with
      *Offline*, login failure with *Login failed*), power and shutter icons in
      `ProjectorStatusStyle` colours, the alert badge; model, IP, pattern thumbnail; the
      group as a band inside the tile (group colour mixed 55 % into the card, text colour
      by the band's brightness) instead of the chip below and the 15 % tint.

    **Phase 8: shell** (shell canvas: *Desktop header…*, *Phone header…*, *Alignment
    banner…*, *Phone Alignment screen…*, *Sign in…*, *Phone: sign in…*).
    - Header: logo, project name over *Projector Grid*, the *Live* pill (amber
      *Reconnecting* / *Connecting*); operator: *Alignment* (a pressed `primaryContainer`
      toggle while on) and Refresh, then the role pill *Operator ▾* with a menu: role line,
      *Lock control*, *Theme*, *Sign out*. Viewer: *Unlock control* as a tonal button
      (while *Allow control* is on), then *Viewer ▾* with *Theme* and *Sign out*. The bell
      stays in the rail on side-panel layouts.
    - Phone header: logo, name over *Live*, the Alignment icon (operator) or the *Unlock*
      icon (viewer, `primaryContainer`), the bell, ⋮ with *Refresh status* and *Lock
      control* (operator), *Theme*, *Sign out*. Refresh leaves the filter row.
    - Banner: one 52 px row, `Alignment`, ◀ *3 of 24* ▶, the toggles (on:
      `primaryContainer`), presets, Focused / Others swatches, *Exit alignment*. Viewer:
      "Alignment, 192.168.0.43 focused (3 of 24), Geometry patterns" and "An operator
      controls it". Busy: "Alignment, waiting for the projectors". No `·` or dashes.
      AlignScreen on touch: pinned step bar with IP and model, cards *Wall*, *Patterns*,
      *Lens, <IP>*.
    - Sign in: card with the logo, project name, *PIN* field and help line (the error
      replaces it), *Sign in*. The PIN pad keeps today's layout (round 66 px keys,
      *Delete*, *OK*), restyled only. *Unlock control* stays the centred dialog, in the
      app's title-bar frame. Lockout text "Too many attempts, try again in 30 s".
    - ConfirmDialog as the app's (§1.2 of the dialog plan); toasts take the tokens.

    **Phase 9: Alerts panel** (shell canvas: *Alerts on the desktop / phone / tablet…*),
    the app's §7m look: 52 px header with *Active alerts*, the count, project groups,
    *By projector* / *By alert*, *Fold all*, ✕ (labelled buttons on tablets); filter chips
    *All / Critical / Warning*; rows with the white message, severity edge and icon, start
    time (duration in the tooltip), quiet Acknowledge; *Acknowledged N* fold. Footer:
    *Sound* on the left (the web has no event log), filled *Acknowledge all* on the right;
    a viewer's footer is *Sound*, "Acknowledging needs control" and *Unlock*, on one line.
    Desktop: a 420 px panel beside the rail; phone and tablet: the bottom sheets of step 4.
    Severity colours from the status tokens (`--sev-*` goes).

    **Phase 10: Remote Preview** (shell canvas: *Remote Preview on the desktop / phone /
    tablet…*), the app's §7b look: title bar with the tile, *Remote Preview*, model + IP,
    group pill and power badge (on the phone under the title bar); the plane with the
    shutter frame and the app's tags; the *Pre-show mode* card (operators); footer with
    ◀ *3 of 24* ▶ on the left and the frame colour legend on the right (in place of the
    app's info line). Phone: full screen, big ◀ ▶ under the image, swipe kept.

    **Phase 11: checks.** `dev:mock` in Chrome at the widths of step 4 in both themes;
    the real app with the simulator; then the owner's review. Update §8 and ROADMAP §5
    where they describe the old behaviour.

    **Progress (2026-10-22):** phases 1 to 10 done, each checked in Chrome with
    `dev:mock` and committed after the owner's look. Phase 10 also: an unreachable
    projector shows its connection badge in the preview's title bar instead of its stale
    power; closing the window with Pre-show on says it stays on, as the app does. §8 and
    ROADMAP §5 updated. Width pass (phone 360 / 390 / 844 sideways, tablet 820 / 1180,
    desktop 1024 / 1440; dark everywhere, light on desktop and phones) found three things,
    fixed: the tablet's sideways alerts drawer keeps icon buttons (labels only in the
    upright sheet the board draws), the view switch drops its words below 1600 px so the
    1440 toolbar stays one row, and the alert toast names the projector by IP. Left: the
    real app with the simulator, the owner's review.

14. `[ ]` **Card redesign: Extended and Compact** (owner, 2026-10-23). The Phase 6 card's
    text and layout read as uneven and hard to scan. Boards: page *Projector card* of the
    shell canvas https://claude.ai/artifact/THMEEesSxnwzgrQVCYDwqi (*Extended card…*,
    *Compact card…*, desktop / tablet / phone boards of each). Supersedes the Phase 6
    card layout (its selection, open, offline and touch rules stay).

    **Two card sizes, different content** (owner): Compact is not just a smaller
    Extended; Extended adds labels, temperature bars, Runtime and AC.

    **Shared by both:**
    - Header: checkbox (operator), status dot, IP in mono, model; the active test
      pattern's thumbnail (tooltip with its name) before ⓘ; no thumbnail while the
      pattern is off. The viewer has no checkbox and no ⓘ, as now.
    - Status footer, always there so every card has one height: the projector's verdict
      in one line. *No problems* (grey, check icon), a warning in amber (*Exhaust hot,
      52 °C*, *Wrong login*), an error in red (*Error F305, +1 more*, *Signal lost on
      SDI 2*), offline in grey (*Offline, last seen 16:41*). The card outline takes the
      footer's tint; the problem badge beside the IP goes.
    - Selected, details open, offline (dashed, last readings dimmed), wrong login
      (*Unknown* in every value) and the touch sizes (22 px checkbox, 44 px ⓘ) as in
      Phase 6.

    **Extended** (desktop 320 px high, touch 352):
    - Under the header, Power and Shutter as two chips (icon + state in the status
      colour on a soft fill), no labels.
    - A two-column grid of label above value, rows split by hairlines: *Input* |
      *Signal* (pill); *Intake* | *Exhaust* with a bar against the alert threshold
      (mark at the limit, amber past it; the value's colour follows the alert);
      *Runtime* | *AC*.

    **Compact** (desktop 146 px high, touch 160):
    - Header in one row: IP and the model beside it.
    - A 3 × 2 grid without labels: power / input, shutter / signal, *In* / *Ex*
      temperatures, so related values stand in one column; names in tooltips. A long
      value ellipsizes in its own cell (*Warming up* on a 360 px phone is fine).

    **Card size switch:**
    - Desktop, tablet and sideways phone: an icon segmented control *Compact* /
      *Extended* left of the view switch, shown in the Cards view only.
    - Upright phone and upright tablet: *Card size* (Compact / Extended) in the header's
      menu (⋮ on the phone, the role menu on the tablet), no room in the bar (owner,
      2026-10-23: on an 820 iPad the switch squeezed the search and the filters).
    - Stored per browser; Compact by default on phones, Extended elsewhere. The grid's
      columns follow the card's minimum width as now (Compact on a 1440 desktop
      without Control: four columns).

    **Progress (2026-10-23):** `ProjectorCard.svelte` draws both sizes, the footer's text
    comes from `logic/cardStatus.ts` (tested), the choice lives in
    `state/cardSize.svelte.ts`; the switch is in `Toolbar.svelte` and the phone's ⋮ menu
    (`Header.svelte`); the cards list takes the boards' 12 px gap. Left: the owner's
    review in the app.

## 11. Open points

- ~~TanStack Table adapter~~ — not used; see §4.
- ~~Precompressed assets~~ — not doing: the bundle is small and it's a LAN.
