"""Draws the model on the camera frames: each frame warped into panel space,
the panel frame in grey, the model outline and centre cross in blue.

    python overlay.py captures/curved c_base_off out/ [step names...]

Needs the captured PNGs (not kept in the repo) and <dir>/eval.json from
evaluate.py."""
import json
import os
import sys

import cv2
import numpy as np

from analyze import PH, PW, baseline_homography
from series import Series, model_for

W, H, M = 480, 300, 24  # output panel size and margin, px


def main():
    d, base, out = sys.argv[1], sys.argv[2], sys.argv[3]
    names = sys.argv[4:]
    os.makedirs(out, exist_ok=True)
    s = Series(d)
    actual = dict(s.frames)
    hom = baseline_homography(cv2.imread(os.path.join(d, f"{base}.png")))
    to_out = cv2.getPerspectiveTransform(np.float32([[0, 0], [PW, 0], [PW, PH], [0, PH]]),
                                         np.float32([[M, M], [M + W, M], [M + W, M + H], [M, M + H]]))
    for name in names or list(actual):
        img = cv2.warpPerspective(cv2.imread(os.path.join(d, f"{name}.png")), to_out @ hom, (W + 2 * M, H + 2 * M))
        img = cv2.convertScaleAbs(img, alpha=0.75)
        cv2.rectangle(img, (M, M), (M + W, M + H), (110, 110, 110), 1)
        geo, rect = model_for(actual[name])
        lines = [geo.outline(*rect, n=60)] + list(geo.center_lines(*rect))
        for i, pts in enumerate(lines):
            p = np.round((pts * [W, H] + M) * 4).astype(np.int32)
            cv2.polylines(img, [p], i == 0, (255, 170, 40), 2 if i == 0 else 1, cv2.LINE_AA, shift=2)
        cv2.imwrite(os.path.join(out, f"{name}.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 85])
    print("written to", out)


if __name__ == "__main__":
    main()
