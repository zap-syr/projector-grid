"""Writes the fixture the Dart tests of the preview read
(test/fixtures/geometry_preview_measured.json):

- "measured": camera edge positions of selected frames. Each sample is
  (edge, position along the edge, edge position), all in panel units 0..1;
  the Dart model's edge at that position must be within TOLERANCE.
- "reference": outlines and centre lines of geo_model itself for a few
  settings, so the Dart port is checked apart from the camera noise.

    python export_fixture.py data/pt-rq25k-2026-10-16 ../../test/fixtures/geometry_preview_measured.json"""
import json
import os
import sys

import numpy as np

import geo_model as gm
from analyze import profiles
from series import Series, _arr, model_for, model_mask, val

TOLERANCE = 0.03
SAMPLE_INDEXES = (4, 8, 12, 16, 20, 24, 28)  # of the 33 profile samples, 0.14 to 0.86
CORNER_MARGIN = 0.05  # panel units kept clear of each edge's corners

MEASURED = {
    "keystone": ["k_trp0_7_vp20", "k_trp0_7_vm20", "k_trp1_5_vp40", "k_trp1_5_vm40", "k_trp3_vp30",
                 "k_trp8_vm20", "k_trp0_7_hp15", "k_trp1_5_hm10", "k_trp3_hp15", "k_tr1_5_vp20_hp15",
                 "k_tr1_5_vm40_hm15", "k_tr1_5_vm20_hp8", "k_tr1_5_v20_vbp60", "k_tr1_5_v20_vbm30",
                 "k_tr1_5_h10_vbp60", "k_tr1_5_h10_hbm30", "k_tr1_5_v20_hbp15", "k_tr1_5_vbp60"],
    "limits": ["l_trp0_7_vp40", "l_trp1_vp40", "l_trp1_2_v40_h15", "l_trp2_vp40"],
    "curved": ["c_trp0_7_a0_vap40", "c_trp0_7_a0_hap40", "c_trp0_7_a1_vam40", "c_trp0_7_a0_ham30",
               "c_trp1_5_a1_vap30", "c_trp1_5_a0_ham20", "c_trp3_a1_vap40", "c_trp3_a0_hap30",
               "c_tr1_5_a1_vap40_ham40", "c_tr1_5_a1_vam20_ham40", "c_tr1_5_a1_va30_vp30",
               "c_tr1_5_a1_ha30_hp15", "c_tr1_5_a1_va30_vbm30", "c_tr1_5_a1_h10_hbp15"],
}

REFERENCE = [
    ("keystone", dict(throwRatio=1.5, vertical=20.0, horizontal=8.0, verticalBalance=30, horizontalBalance=-15)),
    ("keystone", dict(throwRatio=0.7, vertical=40.0, horizontal=0.0, verticalBalance=0, horizontalBalance=0)),
    ("keystone", dict(throwRatio=8.0, vertical=-30.0, horizontal=-12.0, verticalBalance=0, horizontalBalance=0)),
    ("keystone", dict(throwRatio=1.5, vertical=20.0, horizontal=0.0, verticalBalance=60, horizontalBalance=0)),
    ("curved", dict(throwRatio=0.7, verticalArc=40, horizontalArc=0, vertical=0.0, horizontal=0.0,
                    verticalBalance=0, horizontalBalance=0, keepAspect=False)),
    ("curved", dict(throwRatio=1.5, verticalArc=-30, horizontalArc=25, vertical=0.0, horizontal=0.0,
                    verticalBalance=0, horizontalBalance=0, keepAspect=True)),
    ("curved", dict(throwRatio=1.5, verticalArc=30, horizontalArc=0, vertical=20.0, horizontal=-8.0,
                    verticalBalance=-30, horizontalBalance=15, keepAspect=True)),
    ("curved", dict(throwRatio=3.0, verticalArc=0, horizontalArc=-40, vertical=0.0, horizontal=0.0,
                    verticalBalance=0, horizontalBalance=0, keepAspect=False)),
]


def settings(actual):
    a = actual
    if "GMKS8" in a:
        return "keystone", dict(throwRatio=val(a, "GMKS0"), vertical=val(a, "GMKS8"), horizontal=val(a, "GMKS9"),
                                verticalBalance=int(val(a, "GMKI4")), horizontalBalance=int(val(a, "GMKI7")))
    return "curved", dict(throwRatio=val(a, "GMCS0"), verticalArc=int(val(a, "GMCI3")),
                          horizontalArc=int(val(a, "GMCI7")), vertical=val(a, "GMCS8"),
                          horizontal=val(a, "GMCS9"), verticalBalance=int(val(a, "GMCI2")),
                          horizontalBalance=int(val(a, "GMCI6")), keepAspect=val(a, "GMCIA") == 1)


def main():
    data, out_path = sys.argv[1], sys.argv[2]
    measured = []
    for series_name, names in MEASURED.items():
        s = Series(os.path.join(data, series_name))
        actual = dict(s.frames)
        for name in names:
            shape = s.shapes[name]
            model = profiles(model_mask(*model_for(actual[name]))[0])
            tl, tr, br, bl = shape["corners"]
            # Only samples well inside the edge's own span: near a corner a
            # sample column can hit the slanted neighbouring side instead.
            spans = {"top": (tl[0], tr[0]), "bottom": (bl[0], br[0]), "left": (tl[1], bl[1]), "right": (tr[1], br[1])}
            samples, worst = [], 0.0
            for edge, along in (("top", "xs"), ("bottom", "xs"), ("left", "ys"), ("right", "ys")):
                pos, mpos = _arr(shape[edge]), _arr(model[edge])
                lo, hi = sorted(spans[edge])
                for i in SAMPLE_INDEXES:
                    at = shape[along][i]
                    if not (s.good[edge][i] and lo + CORNER_MARGIN <= at <= hi - CORNER_MARGIN):
                        continue
                    if np.isnan(pos[i]) or np.isnan(mpos[i]):
                        continue
                    samples.append([edge, round(at, 4), round(float(pos[i]), 4)])
                    worst = max(worst, abs(float(mpos[i] - pos[i])))
            flag = "" if worst <= TOLERANCE else "  OVER TOLERANCE, drop it or loosen"
            print(f"{name:28s} {len(samples)} samples, reference model worst {worst:.4f}{flag}")
            mode, st = settings(actual[name])
            measured.append({"frame": name, "mode": mode, "settings": st, "samples": samples})

    reference = []
    for mode, st in REFERENCE:
        if mode == "keystone":
            geo, rect = gm.keystone(st["throwRatio"], st["vertical"], st["horizontal"],
                                    st["verticalBalance"], st["horizontalBalance"])
        else:
            geo, rect = gm.curved(st["throwRatio"], st["verticalArc"], st["horizontalArc"], st["vertical"],
                                  st["horizontal"], st["verticalBalance"], st["horizontalBalance"],
                                  st["keepAspect"])
        row, col = geo.center_lines(*rect, n=5)
        reference.append({"mode": mode, "settings": st,
                          "outline": np.round(geo.outline(*rect, n=5), 5).tolist(),
                          "centerRow": np.round(row, 5).tolist(), "centerColumn": np.round(col, 5).tolist()})

    fixture = {
        "source": "tool/geometry_measure, PT-RQ25K, 2026-10-16",
        "tolerance": TOLERANCE,
        "referenceTolerance": 0.002,
        "outlineOrder": "clockwise from the top-left corner, 5 points per edge, corners repeated",
        "measured": measured,
        "reference": reference,
    }
    with open(out_path, "w") as f:
        json.dump(fixture, f, indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
