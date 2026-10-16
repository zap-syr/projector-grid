# Geometry measurement

Measures what a projector's Keystone and Curved Correction do to the image, with a
webcam, and fits the model the Geometry Correction preview draws
(`plan/GEOMETRY_PREVIEW_PLAN.md`). Python, not part of the app build or CI.

`data/pt-rq25k-2026-10-16/` holds the analysed result of the first run (PT-RQ25KE,
319 frames): `shapes.json` (corners and edge profiles per frame, in panel units) and
`log.json` (the commands sent and the values the projector read back). The camera
frames themselves (about 80 MB) are not kept; everything below except `capture.py`
and `overlay.py` runs on this data.

## Setup

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt     # macOS: .venv/bin/python
```

Windows only for capture (`camera.py` uses DirectShow). Analysis runs anywhere.

- `ntc.py`: set `HOST`. A protected projector needs `PGRID_LOGIN` and `PGRID_PASSWORD`
  in the environment; they are never written to a file.
- `camera.py`: `python camera.py list` prints the cameras, set `CAM_INDEX`. Set
  `EXPOSURE` so the white field doesn't clip (`python camera.py snap test.png`, look at it).

## Taking a series

1. Dark room. Camera on a tripod, the whole image in frame with a margin, as large as
   possible: corrections only shrink the image, so the uncorrected frame is the
   biggest it gets. **The camera must not move during a series.**
2. Projector on, white test pattern, nothing else on screen.
3. Run a plan. Each step sets every register of its mode, waits, and saves an
   average of 8 frames:

   ```bash
   python capture.py plans/keystone.py captures/keystone      # ~8 min
   python capture.py plans/curved.py   captures/curved        # ~11 min
   python capture.py plans/limits.py   captures/limits        # ~5 min
   ```

   The first step of every plan turns correction off: that frame is the baseline.
   The plans switch Quad Pixel Drive on (`QPDI1`), which Tier A / B models need for
   geometry modes. The projector is left in the last step's state.

4. Analyse (maps each frame into panel coordinates through the baseline):

   ```bash
   python analyze.py captures/keystone k_base_off
   python analyze.py captures/curved   c_base_off
   python analyze.py captures/limits   l_base_off
   ```

5. Copy `shapes.json` and `log.json` of each series to `data/<model>-<date>/<series>/`.

## Checking and refitting the model

`geo_model.py` is the reference model; the app's `domain/geometry_preview.dart` is
a port of it with the same constants.

```bash
python evaluate.py data/pt-rq25k-2026-10-16/keystone     # RMS per frame and summary
python fit.py data/<run>/keystone data/<run>/curved      # refit KS_F, BAL_*, CV_*
python limits.py data/<run>/limits                       # applied V and H per frame
python overlay.py captures/curved c_base_off out/        # model drawn on the frames
python export_fixture.py data/pt-rq25k-2026-10-16 ../../test/fixtures/geometry_preview_measured.json
```

- `fit.py` prints new constants; put them in `geo_model.py` and in the Dart port,
  then re-export the fixture.
- `limits.py`: where the applied V stops following the set V is `v_limit`; applied H
  over set H is `H_SCALE`.
- `export_fixture.py` prints the worst model error per fixture frame and flags any
  over the test tolerance (3 %).

Accuracy on the first run: median RMS 0.7 % of the panel width for Keystone, 0.4 %
for Curved; the measurement floor is about 0.4 %.
