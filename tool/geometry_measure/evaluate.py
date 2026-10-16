"""Scores geo_model on every frame of an analysed series.

    python evaluate.py data/pt-rq25k-2026-10-16/keystone

Prints RMS / 90th percentile (panel units) and IoU per frame, then a summary.
Writes <dir>/eval.json with the model outlines (overlay.py draws them)."""
import json
import os
import sys

import numpy as np

from series import Series, score


def main():
    s = Series(sys.argv[1])
    out = {}
    for name, actual in s.frames:
        rms, p90, iou, poly = score(s, name, actual)
        out[name] = {"rms": rms, "p90": p90, "iou": iou, "outline": np.round(poly, 4).tolist()}
        iou_s = "" if iou is None else f"  iou {iou:.4f}"
        print(f"{name:32s} rms {rms:.4f}  p90 {p90:.4f}{iou_s}", flush=True)
    json.dump(out, open(os.path.join(s.dir, "eval.json"), "w"))
    r = np.array([v["rms"] for v in out.values()])
    print(f"frames {len(r)}  median rms {np.nanmedian(r):.4f}  mean {np.nanmean(r):.4f}  "
          f"worst {np.nanmax(r):.4f}  over 2 %: {(r > 0.02).sum()}")


if __name__ == "__main__":
    main()
