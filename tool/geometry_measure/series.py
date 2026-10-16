"""Loads an analysed series (shapes.json + log.json) and scores geo_model on it."""
import json
import os

import cv2
import numpy as np

import geo_model as gm
from analyze import PH, PW, profiles

EDGES = ("top", "bottom", "left", "right")


def val(actual, key):
    return float(actual[key].replace("+", "")) if key in actual else 0.0


def _arr(p):
    return np.array([np.nan if v is None else v for v in p], float)


class Series:
    """Frames of one series with the settings the projector read back."""

    def __init__(self, d):
        self.dir = d
        self.shapes = json.load(open(os.path.join(d, "shapes.json")))["shapes"]
        rows = [json.loads(line) for line in open(os.path.join(d, "log.json"))]
        self.frames = [(r["name"], r["actual"]) for r in rows
                       if r["name"] in self.shapes and ("GMKS8" in r["actual"] or "GMCI3" in r["actual"])]
        # Profile samples where the corrected-to-zero frame isn't on the panel
        # edge are spoiled (dark print on the projection surface); skip them.
        zero = self.shapes[next(n for n in self.shapes if n.endswith("_zero"))]
        self.good = {e: np.abs(_arr(zero[e]) - (0 if e in ("top", "left") else 1)) < 0.006 for e in EDGES}

    def select(self, pred):
        return [(n, a) for n, a in self.frames if pred(a)]


def model_for(actual):
    """(Geo, rect) for the settings of one frame."""
    a = actual
    if "GMKS8" in a:
        return gm.keystone(val(a, "GMKS0"), val(a, "GMKS8"), val(a, "GMKS9"), val(a, "GMKI4"), val(a, "GMKI7"))
    return gm.curved(val(a, "GMCS0"), val(a, "GMCI3"), val(a, "GMCI7"), val(a, "GMCS8"), val(a, "GMCS9"),
                     val(a, "GMCI2"), val(a, "GMCI6"), keep_aspect=val(a, "GMCIA") == 1)


def model_mask(geo, rect):
    poly = geo.outline(*rect, n=60)
    mask = np.zeros((PH, PW), np.uint8)
    cv2.fillPoly(mask, [np.round(poly * [PW, PH]).astype(np.int32)], 255)
    return mask, poly


def residuals(series, name, mask):
    """Model edge minus camera edge at every usable profile sample."""
    mp, sp = profiles(mask), series.shapes[name]
    out = []
    for e in EDGES:
        m, s = _arr(mp[e]), _arr(sp[e])
        ok = series.good[e] & ~np.isnan(m) & ~np.isnan(s)
        out.append(m[ok] - s[ok])
    return np.concatenate(out)


def score(series, name, actual):
    """RMS (panel units), 90th percentile, IoU (None without warped masks),
    and the model outline."""
    geo, rect = model_for(actual)
    mask, poly = model_mask(geo, rect)
    res = residuals(series, name, mask)
    rms = float(np.sqrt(np.mean(res**2))) if len(res) else float("nan")
    p90 = float(np.percentile(np.abs(res), 90)) if len(res) else float("nan")
    iou = None
    warped = os.path.join(series.dir, "warped", f"{name}.png")
    if os.path.exists(warped):
        meas = cv2.imread(warped, 0) > 0
        iou = float(np.logical_and(meas, mask > 0).sum() / np.logical_or(meas, mask > 0).sum())
    return rms, p90, iou, poly
