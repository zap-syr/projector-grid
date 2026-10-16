"""Reference model of Keystone and Curved Correction (the app's preview is a
Dart port of this file, lib/features/workspace/domain/geometry_preview.dart).

Screen: a surface of circular arcs (curvature kh across, kv down; 0 = flat),
parametrised by arc lengths (X, Y), tilted by the keystone angles
(R = Rx(-V) @ Ry(H)), centred at distance f in front of the lens. Balance
shifts the optical axis on the panel (ox, oy). The image is the largest
screen-space rectangle (b / a = panel aspect when the aspect is kept; a and b
free otherwise) whose projection stays inside the panel. Panel coordinates are
0..1 on both axes. Plan: plan/GEOMETRY_PREVIEW_PLAN.md."""
import numpy as np
from scipy.optimize import minimize

ASPECT = 1200 / 1920
HW, HH = 0.5, ASPECT / 2
N = 25

# Fitted on PT-RQ25K, 2026-10-16 (fit.py).
KS_F = (1.0094, 1.2111)  # Keystone: f = a * TR^p
CV_F = (1.0, 0.9858)  # Curved: f = a * TR^p
CV_C = 0.01508  # curvature per Arc step, 1 / panel width
BAL_Y, BAL_X = 0.00601, -0.00907  # optical axis shift per Balance step
H_SCALE = 1.05  # Keystone mode applies H about 5 % above the set value
CLAMP = True  # apply v_limit; limits.py turns it off to find the real angle


def v_limit(tr, h):
    """Largest Vertical Keystone the projector applies in Keystone mode; it
    accepts and reads back up to 40 at any throw ratio."""
    base = 27.0 if tr < 0.85 else 33.0 if tr < 1.25 else 40.0
    return base - 0.13 * abs(h)


def _bend(s, k):
    if abs(k) < 1e-9:
        return s, np.zeros_like(s)
    return np.sin(k * s) / k, (1 - np.cos(k * s)) / k


def _rot(v_deg, h_deg):
    a, b = np.radians(-v_deg), np.radians(h_deg)
    rx = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])
    ry = np.array([[np.cos(b), 0, np.sin(b)], [0, 1, 0], [-np.sin(b), 0, np.cos(b)]])
    return rx @ ry


class Geo:
    def __init__(self, f, v=0.0, h=0.0, kh=0.0, kv=0.0, vb=0.0, hb=0.0):
        self.f, self.R, self.kh, self.kv = f, _rot(v, h), kh, kv
        self.ox, self.oy = BAL_X * hb, BAL_Y * vb

    def panel(self, X, Y):
        """Screen arc-length coordinates -> panel coordinates."""
        x, dz1 = _bend(X, self.kh)
        y, dz2 = _bend(Y, self.kv)
        P = np.stack([x, y, -(dz1 + dz2)], 1) @ self.R.T + np.array([0, 0, self.f])
        u = 0.5 + self.ox + self.f * P[:, 0] / P[:, 2]
        v = 0.5 + (self.oy + self.f * P[:, 1] / P[:, 2]) / ASPECT
        return np.stack([u, v], 1)

    def outline(self, cx, cy, a, b, n=N):
        """Clockwise from the top-left corner, n points per edge."""
        t = np.linspace(-1, 1, n)
        X = np.concatenate([cx + t * a, np.full(n, cx + a), cx - t * a, np.full(n, cx - a)])
        Y = np.concatenate([np.full(n, cy - b), cy + t * b, np.full(n, cy + b), cy - t * b])
        return self.panel(X, Y)

    def center_lines(self, cx, cy, a, b, n=N):
        """The image's middle row and middle column (the preview's cross)."""
        t = np.linspace(-1, 1, n)
        row = self.panel(cx + t * a, np.full(n, cy))
        col = self.panel(np.full(n, cx), cy + t * b)
        return row, col

    def fits(self, cx, cy, a, b):
        p = self.outline(cx, cy, a, b, n=13)
        return np.all(p >= -1e-9) and np.all(p <= 1 + 1e-9)

    def _max_scale(self, cx, cy, ra, rb):
        lo, hi = 0.0, 3.0
        for _ in range(22):
            s = (lo + hi) / 2
            lo, hi = (s, hi) if self.fits(cx, cy, s * ra, s * rb) else (lo, s)
        return lo

    def image(self, keep_aspect=True):
        """Largest rectangle: (cx, cy, a, b) in screen units."""
        # Start from the screen point that lands on the panel centre: with a
        # large Balance the screen centre itself falls outside the panel.
        c0 = minimize(lambda c: np.square(self.panel(np.array([c[0]]), np.array([c[1]]))[0] - 0.5).sum(),
                      [0.0, 0.0], method="Nelder-Mead", options={"xatol": 1e-6, "fatol": 1e-12}).x
        if keep_aspect:
            simplex = [c0, c0 + [0.05, 0], c0 + [0, 0.05]]
            best = minimize(lambda c: -self._max_scale(c[0], c[1], HW, HH), c0, method="Nelder-Mead",
                            options={"xatol": 1e-4, "fatol": 1e-6, "initial_simplex": simplex})
            cx, cy = best.x
            s = self._max_scale(cx, cy, HW, HH)
            return cx, cy, s * HW, s * HH
        # Without the aspect: width and height widened in turn from the largest
        # uniform scale (starting at full height collapses the width of a
        # concave arc).
        cx, cy = c0
        s = self._max_scale(cx, cy, HW, HH)
        a, b = s * HW, s * HH
        for _ in range(4):
            a = self._fit_axis(cx, cy, a, b, "a")
            b = self._fit_axis(cx, cy, a, b, "b")
        return cx, cy, a, b

    def _fit_axis(self, cx, cy, a, b, which):
        lo, hi = 0.0, 3 * (HW if which == "a" else HH)
        for _ in range(22):
            m = (lo + hi) / 2
            ok = self.fits(cx, cy, m, b) if which == "a" else self.fits(cx, cy, a, m)
            lo, hi = (m, hi) if ok else (lo, m)
        return lo


def keystone(tr, v, h, vb=0, hb=0):
    if CLAMP:
        v = float(np.clip(v, -v_limit(tr, h), v_limit(tr, h)))
    g = Geo(KS_F[0] * tr ** KS_F[1], v=v, h=h * H_SCALE, vb=vb, hb=hb)
    return g, g.image(True)


def curved(tr, v_arc, h_arc, v=0.0, h=0.0, vb=0, hb=0, keep_aspect=True):
    # Keystone inside Curved was measured up to V 30 at TR 1.5 only: no limit
    # and no H scale are known for it, so none are applied.
    g = Geo(CV_F[0] * tr ** CV_F[1], v=v, h=h, kh=CV_C * h_arc, kv=CV_C * v_arc, vb=vb, hb=hb)
    return g, g.image(keep_aspect)
