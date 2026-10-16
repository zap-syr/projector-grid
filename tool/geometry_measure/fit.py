"""Refits the constants of geo_model from analysed series, one stage at a time.

    python fit.py <keystone_dir> <curved_dir> [focal|balance|curved]

Stages (each takes a few minutes):
  focal    KS_F from the Keystone frames without Balance
  balance  BAL_Y, BAL_X from the Keystone frames with Balance
  curved   CV_C, CV_F from the Curved frames with only the arcs set
Prints the fitted values; copy them into geo_model.py and into the Dart port.
v_limit and H_SCALE come from limits.py instead."""
import sys

import numpy as np
from scipy.optimize import minimize

import geo_model as gm
from series import Series, model_for, model_mask, residuals, val


def loss(series, frames):
    errs = [residuals(series, n, model_mask(*model_for(a))[0]) for n, a in frames]
    return float(np.mean(np.square(np.concatenate(errs))))


def run(series, frames, setter, x0, label):
    def f(p):
        setter(p)
        return loss(series, frames)

    r = minimize(f, x0, method="Nelder-Mead", options={"xatol": 1e-4, "fatol": 1e-9, "maxiter": 60})
    setter(r.x)
    print(f"{label}: {np.round(r.x, 5).tolist()}  rmse {np.sqrt(r.fun):.4f}  ({len(frames)} frames)", flush=True)


def main():
    ks, cv = Series(sys.argv[1]), Series(sys.argv[2])
    stages = sys.argv[3:] or ["focal", "balance", "curved"]
    if "focal" in stages:
        frames = ks.select(lambda a: not val(a, "GMKI4") and not val(a, "GMKI7"))
        run(ks, frames, lambda p: setattr(gm, "KS_F", (p[0], p[1])), list(gm.KS_F), "KS_F (a, p)")
    if "balance" in stages:
        frames = ks.select(lambda a: val(a, "GMKI4") or val(a, "GMKI7"))

        def set_bal(p):
            gm.BAL_Y, gm.BAL_X = p

        run(ks, frames, set_bal, [gm.BAL_Y, gm.BAL_X], "BAL_Y, BAL_X")
    if "curved" in stages:
        frames = cv.select(lambda a: not any(val(a, k) for k in ("GMCS8", "GMCS9", "GMCI2", "GMCI6")))

        def set_cv(p):
            gm.CV_C, gm.CV_F = p[0], (1.0, p[1])

        run(cv, frames, set_cv, [gm.CV_C, gm.CV_F[1]], "CV_C, CV_F p")


if __name__ == "__main__":
    main()
