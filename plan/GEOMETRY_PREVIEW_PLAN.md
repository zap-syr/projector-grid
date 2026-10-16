# Geometry Preview Plan (Keystone, Curved Correction)

Status: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not doing · `[later]` deferred

The preview card of the Geometry Correction dialog (`DIALOG_REDESIGN_PLAN.md` §7.3, §7.4)
draws the image shape for Keystone and Curved Correction. Today those modes show
"Preview not available", and the unused `_TrapezoidPainter` in
`geometry_correction_dialog.dart` was tuned by hand: it misses the height change of Keystone,
folds into a triangle at large V + H, and bows Curved edges the wrong way.

On 2026-10-16 the projector's own behaviour was measured with a webcam: 319 frames on a
PT-RQ25KE (white test pattern, Quad Pixel Drive on), each frame mapped into panel coordinates
through the uncorrected frame. Two physical models fit the frames to about 1 % of the panel
size. This plan replaces the earlier idea of drawing the modes the way VSS renders them:
VSS computes its own corrections, which differ from the projector's, and the owner decided
on 2026-10-16 that the preview follows the projector.

Report with the camera frames, the model and today's painter drawn on them:
https://claude.ai/artifact/6GuBBxC8z9QB5kNNVN7kt3 (*Geometry Preview Measurements*).

---

## 1. Measured behaviour

Panel coordinates below: `u`, `v` in 0..1 (left to right, top to bottom). Panel aspect
`A = 1200 / 1920` (16:10, every Tier A / B model in `geometry_values.dart`). Lens-centred
coordinates: `x = u − 0.5`, `y = (v − 0.5) · A`, in panel widths.

### 1.1 One model for both modes
The projector treats the settings as a description of the screen and pre-warps the panel so
the image lands as an undistorted rectangle on that screen:

1. **Screen.** A surface of circular arcs, curvature `kh` across and `kv` down (0 = flat),
   parametrised by arc lengths `(X, Y)`. A point bends to `(sin(kh·X)/kh, sin(kv·Y)/kv)`
   with depth `(1 − cos(kh·X))/kh + (1 − cos(kv·Y))/kv` toward the projector.
2. **Tilt.** The surface is rotated by the keystone angles, `R = Rx(−V) · Ry(H)` (rotation
   about the horizontal axis, then the vertical axis, in that order; the other order fits
   three times worse), and placed at distance `f` in front of the lens.
3. **Projection.** A point `P` lands on the panel at `u = 0.5 + ox + f·Px/Pz`,
   `v = 0.5 + (oy + f·Py/Pz) / A`. `(ox, oy)` is the optical axis shift set by Balance.
4. **Image.** The largest screen-space rectangle (`b / a = A` when the aspect is kept;
   `a`, `b` independent otherwise) whose projection stays inside the panel. Its centre is free
   (that is what moves the image toward the wide side of a keystone). The panel outline of
   that rectangle is the preview.

### 1.2 Constants (PT-RQ25K, measured 2026-10-16)

| | Value |
|---|---|
| Keystone focal length | `f = 1.0094 · TR^1.2111` (TR = Throw ratio, `GMKS0`) |
| Curved focal length | `f = TR^0.9858` (`GMCS0`) |
| Curvature per Arc step | `k = 0.01508 · arc` (Vertical Arc `GMCI3` → `kv`, Horizontal Arc `GMCI7` → `kh`) |
| Balance, axis shift per step | `oy = 0.00601 · VB`, `ox = −0.00907 · HB` |
| Horizontal angle | applied as `1.05 · H` (the projector runs about 5 % above the set value) |
| Sign | positive V narrows the top; positive H narrows the left side |

- **Vertical Arc** bends the left and right edges (the screen is curved top to bottom);
  **Horizontal Arc** bends the top and bottom. Positive = concave screen (edges bow inward),
  negative = convex (the image shrinks, edges bow outward).
- **Balance with no keystone changes nothing.** With keystone, Balance on the same axis moves
  the long side (how much the image is compressed), Balance on the other axis slides the short
  side along itself. Both follow from the axis shift.
- **Maintain aspect ratio** off: the image fills the panel at its corners. On: proportions of
  the screen-space rectangle are kept.

### 1.3 Limits the projector applies silently
The projector accepts and reads back up to ±40° Vertical Keystone at any throw ratio, but
applies at most:

| Throw ratio | Max V applied |
|---|---|
| below 0.85 | 27° |
| 0.85 to 1.25 | 33° |
| from 1.25 | 40° |

With H set too, the cap drops by about `0.13 · |H|` (V 40 + H 15 at TR 0.7 applies V 25).
H reaches ±15 at every throw ratio. The preview clamps V the same way, so it shows what the
projector does, not what the slider says. The slider keeps its full −40 to 40 range and
shows no hint when the value is capped: the drawing shows it (owner, 2026-10-16).

These limits and the H scale were measured in Keystone mode. Keystone inside Curved was
only measured up to V 30 at TR 1.5, so no limit or H scale is applied there.

### 1.4 Accuracy
RMS distance between the model edge and the camera edge, in panel widths (1 % ≈ 5 px on a
480 px preview), with the constants of §1.2 (`tool/geometry_measure/evaluate.py`).

| Series | Frames | RMS median | RMS worst | Frames over 2 % |
|---|---|---|---|---|
| Keystone (4 throw ratios, V, H, V × H, Balance) | 108 | 0.68 % | 3.2 % | 6 |
| Curved (3 throw ratios, arcs, aspect on / off, Keystone, Balance) | 146 | 0.32 % | 6.7 % | 7 |
| Keystone limits (8 throw ratios) | 65 | 0.72 % | 1.6 % | 0 |

The measurement floor is about 0.4 % (an uncorrected frame scores that against itself: the
projection surface has a dark print near its right edge). Known deviations, all under 3 %
except two frames:
- Keystone V ±40 at TR 3 and 8: 2.2 to 2.9 % (the focal length fits small throw ratios best).
- Convex arcs with Maintain aspect ratio on at TR 0.7: about 2.6 %, the image sits a little
  further left than the model.
- Arc 30 with Balance ±60 in Curved: 5 to 7 % RMS from a few edge points, about 2 % at the
  90th percentile; the shape itself matches.

### 1.5 Not covered
- Only one model was measured. The constants are assumed for every model until another one is
  measured; the preview card keeps its "approximate" note for that reason.
- Lens shift, image flip (ceiling / rear mounting) and inputs other than a 16:10 full-panel
  signal were not part of the test.

---

## 2. Implementation

### 2.1 `[x]` Pure model in `domain/geometry_preview.dart`
Done 2026-10-16. Plain Dart, no packages. `keystonePreview(...)` and `curvedPreview(...)`
take the register values and return a `GeometryPreview`: the image `outline` (clockwise
from the top-left corner, `samples` points per edge) and the `centerRow` / `centerColumn`
of the cross, all in panel coordinates 0..1. `appliedVerticalKeystone(...)` is the cap of
§1.3.

Steps, matching §1.1 and `tool/geometry_measure/geo_model.py` line for line:
- `panel(X, Y)`: bend, rotate, divide by depth, axis shift.
- `fits(...)`: 13 points per edge of the rectangle inside the panel.
- Largest scale for a centre: bisection, 22 steps.
- Centre: Newton's method finds the screen point that lands on the panel centre (with a
  large Balance the screen centre is off the panel), then Nelder-Mead maximises the scale
  with the same coefficients and stopping rule as scipy, so the port lands where the
  reference does. A compass search was the first idea but stalls on the diagonal ridges of
  this function.
- Aspect off: from that same centre, largest uniform scale first, then width and height
  widened in turn (4 rounds).

1.5 ms per call in the debug test runner; the test keeps an 8 ms guard.

### 2.2 `[~]` Painter `presentation/widgets/geometry_preview_painter.dart`
Painter done 2026-10-16 and shown in today's dialog under a *Preview* header;
`_TrapezoidPainter` and `_buildPreviewUnavailable` are gone. Left for step 6: the card
header (pill, **Reset**) and the legend. `tool/projector_simulator.dart` answers the
geometry registers, so the preview can be checked without a projector.
- Draws, inside the panel aspect box: the panel frame (legend *Panel*), the image fill and
  outline (legend *Image*), and the two centre lines crossing the image as in the mockup
  (no grid; owner, 2026-10-16).
- Takes the computed outline and centre lines, not the settings, so `paint` does no maths;
  `shouldRepaint` compares the lists. The dialog computes them in `build` from `_keystone` /
  `_curved` (already updated on every `onChanged`).
- Colours and stroke widths from the theme per the visual rules skill; the card layout,
  header (*Preview*, pill, **Reset**) and legend are §7.3 of the redesign plan.
- Delete `_TrapezoidPainter` and `_buildPreviewUnavailable`.

### 2.3 `[x]` Tests
Done 2026-10-16, `test/unit/geometry_preview_test.dart` (52 tests).
- `test/unit/geometry_preview_test.dart`:
  - zero settings → the full panel (corners within 0.001);
  - every outline point within `[0, 1]`;
  - mirror symmetry: `V` and `−V` mirror top to bottom, `H` and `−H` left to right, a positive
    and negative Balance likewise;
  - Balance alone → the full panel;
  - the clamp: TR 0.7 V 40 draws the same outline as V 27;
  - **measured cases**: 36 frames from `test/fixtures/geometry_preview_measured.json`. Each
    sample is (edge, position along it, camera edge position), taken well inside the edge's
    own span; the model's edge at that position must be within 0.03, which the reference
    model meets on every sample;
  - **reference cases**: 8 outlines and centre lines (5 points per edge) from the Python
    model, tolerance 0.002, so the port is checked apart from the measurement noise.
- The fixture is exported by `tool/geometry_measure/export_fixture.py` (§2.4), not typed by
  hand.

### 2.4 `[x]` Measurement tooling
Done 2026-10-16: `tool/geometry_measure/` (Python: OpenCV, SciPy) with a README. Capture
(`capture.py` + `plans/`), analysis (`analyze.py`), the reference model (`geo_model.py`),
scoring (`evaluate.py`), refitting (`fit.py`, `limits.py`), overlays and the test fixture
export. The analysed data of the first run is in `data/pt-rq25k-2026-10-16/` (camera frames
not kept). Not part of the app build and not run in CI. The projector login comes from the
environment, never a file.

### 2.5 Order
Lands with Geometry Correction, step 6 of the redesign (`DIALOG_REDESIGN_PLAN.md`): 2.1 and
2.3 first (pure, testable on their own), then 2.2 inside the new preview card.

---

## 3. Decisions (owner, 2026-10-16)
1. The preview draws what the projector does, not what VSS draws (VSS renders these modes
   differently from the projector).
2. The card keeps the *Schematic* pill and the note "The drawing is approximate, check the
   result on the screen." (one model measured).
3. No hint under the Vertical Keystone slider when the projector caps the angle; the
   drawing shows the capped shape.
4. The measurement scripts live in `tool/geometry_measure/` (§2.4).
5. No grid inside the image: only the two centre lines crossing it, as in the mockup.
