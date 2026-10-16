"""Finds the keystone angles the projector actually applied, per frame, by
fitting V and H of the unclamped model to the camera shape. Where the applied
V stops following the set V is the limit (v_limit in geo_model); the ratio of
applied to set H is H_SCALE.

    python limits.py data/pt-rq25k-2026-10-16/limits"""
import sys

import numpy as np
from scipy.optimize import minimize

import geo_model as gm
from series import Series, model_mask, residuals, val


def main():
    gm.CLAMP = False
    s = Series(sys.argv[1])
    for name, a in s.select(lambda a: "GMKS8" in a):
        tr, v, h = val(a, "GMKS0"), val(a, "GMKS8"), val(a, "GMKS9")

        def err(p):
            # geo_model scales H by H_SCALE; undo it so p[1] is the applied H.
            geo, rect = gm.keystone(tr, p[0], p[1] / gm.H_SCALE)
            return float(np.mean(np.square(residuals(s, name, model_mask(geo, rect)[0]))))

        r = minimize(err, [v, h * gm.H_SCALE], method="Nelder-Mead", options={"xatol": 0.05, "fatol": 1e-9})
        print(f"{name:20s} set V {v:5.1f} H {h:5.1f}  applied V {r.x[0]:5.1f} H {r.x[1]:5.1f}  "
              f"rms {np.sqrt(r.fun):.4f}", flush=True)


if __name__ == "__main__":
    main()
