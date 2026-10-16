"""Maps every frame of a capture into panel coordinates (0..1 on both axes)
through the uncorrected baseline frame, so the camera's own angle drops out,
then extracts corners and edge profiles.

    python analyze.py captures/keystone k_base_off

Writes <dir>/shapes.json and <dir>/warped/<step>.png (the image mask in panel
space)."""
import glob
import json
import os
import sys

import cv2
import numpy as np

PW, PH = 1600, 1000  # warped panel raster, 16:10 like the panel
SAMPLES = 33


def mask_of(img):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    g = cv2.GaussianBlur(g, (5, 5), 0)
    # The surround is near black while the image has a strong hotspot, so
    # Otsu lands inside the image; a fraction of it marks the lit edge.
    otsu, _ = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    _, m = cv2.threshold(g, max(20.0, otsu * 0.35), 255, cv2.THRESH_BINARY)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    _, labels, stats, _ = cv2.connectedComponentsWithStats(m)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    m = np.where(labels == biggest, 255, 0).astype(np.uint8)
    # Fill holes left by dark print on the projection surface.
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    filled = np.zeros_like(m)
    cv2.drawContours(filled, cnts, -1, 255, -1)
    return filled


def _contour(mask):
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    return max(cnts, key=cv2.contourArea).reshape(-1, 2).astype(np.float64)


def quad_corners(mask):
    """Extreme points along the diagonals: TL, TR, BR, BL."""
    pts = _contour(mask)
    s, d = pts.sum(1), pts[:, 0] - pts[:, 1]
    return np.array([pts[np.argmin(s)], pts[np.argmax(d)], pts[np.argmax(s)], pts[np.argmin(d)]])


def line_corners(mask):
    """Corners as intersections of lines fitted to the middle of each side,
    steadier than extreme points on a soft camera edge."""
    tl, tr, br, bl = quad_corners(mask)
    pts = _contour(mask)

    def side(a, b):
        ab = b - a
        n = np.linalg.norm(ab)
        rel = pts - a
        t = (rel @ ab) / n**2
        dist = np.abs(ab[0] * rel[:, 1] - ab[1] * rel[:, 0]) / n
        sel = pts[(t > 0.1) & (t < 0.9) & (dist < 6)]
        vx, vy, x0, y0 = cv2.fitLine(sel.astype(np.float32), cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
        return np.array([x0, y0]), np.array([vx, vy])

    lines = [side(tl, tr), side(tr, br), side(br, bl), side(bl, tl)]

    def meet(l1, l2):
        (p, u), (q, v) = l1, l2
        t = np.linalg.solve(np.array([u, -v]).T, q - p)
        return p + t[0] * u

    return np.array([meet(lines[3], lines[0]), meet(lines[0], lines[1]),
                     meet(lines[1], lines[2]), meet(lines[2], lines[3])])


def baseline_homography(baseline_img):
    src = line_corners(mask_of(baseline_img)).astype(np.float32)
    dst = np.float32([[0, 0], [PW, 0], [PW, PH], [0, PH]])
    return cv2.getPerspectiveTransform(src, dst)


def profiles(pmask):
    """Edge positions in panel units at SAMPLES points along each side."""
    h, w = pmask.shape
    xs = np.linspace(0.02, 0.98, SAMPLES)
    ys = np.linspace(0.02, 0.98, SAMPLES)
    top, bottom, left, right = [], [], [], []
    # A column that only grazes a stray speck or the image's very edge isn't a
    # real crossing; require it to span a good part of the panel.
    for x in xs:
        col = np.nonzero(pmask[:, int(x * (w - 1))])[0]
        ok = len(col) > 0.3 * h
        top.append(col[0] / h if ok else None)
        bottom.append((col[-1] + 1) / h if ok else None)
    for y in ys:
        row = np.nonzero(pmask[int(y * (h - 1)), :])[0]
        ok = len(row) > 0.3 * w
        left.append(row[0] / w if ok else None)
        right.append((row[-1] + 1) / w if ok else None)
    return {"xs": xs.tolist(), "ys": ys.tolist(), "top": top, "bottom": bottom,
            "left": left, "right": right}


def main():
    d, base = sys.argv[1], sys.argv[2]
    H = baseline_homography(cv2.imread(os.path.join(d, f"{base}.png")))
    os.makedirs(os.path.join(d, "warped"), exist_ok=True)
    out = {"baseline": base, "shapes": {}}
    for path in sorted(glob.glob(os.path.join(d, "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        m = mask_of(cv2.imread(path))
        pm = cv2.warpPerspective(m, H, (PW, PH), flags=cv2.INTER_NEAREST)
        cv2.imwrite(os.path.join(d, "warped", f"{name}.png"), pm)

        def to_panel(c):
            p = cv2.perspectiveTransform(c.astype(np.float32).reshape(-1, 1, 2), H)
            return p.reshape(-1, 2) / np.array([PW, PH])

        try:
            corners = to_panel(line_corners(m))
        except (cv2.error, np.linalg.LinAlgError):
            corners = to_panel(quad_corners(m))
        out["shapes"][name] = {"corners": np.round(corners, 4).tolist(), **profiles(pm)}
        print(name, " ".join(f"({x:.3f},{y:.3f})" for x, y in corners))
    with open(os.path.join(d, "shapes.json"), "w") as f:
        json.dump(out, f)


if __name__ == "__main__":
    main()
