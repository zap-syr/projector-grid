"""Webcam access shared by the capture scripts (DirectShow, Windows).

    python camera.py list            # camera names by index
    python camera.py snap out.png    # one frame, to check framing and exposure
"""
import sys
import time

import cv2
import numpy as np

# Edit for your setup: the index from `camera.py list`, and a manual exposure
# (log2 seconds) dark enough that the white test pattern doesn't clip.
CAM_INDEX = 5
EXPOSURE = -9


def open_camera():
    cap = cv2.VideoCapture(CAM_INDEX, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)  # DirectShow: 0.25 = manual
    cap.set(cv2.CAP_PROP_EXPOSURE, EXPOSURE)
    cap.set(cv2.CAP_PROP_AUTOFOCUS, 0)
    for _ in range(30):
        cap.read()
    return cap


def averaged(cap, settle_s, count=8):
    """Mean of `count` frames taken after `settle_s`. Draining first makes sure
    the frames postdate the last command; averaging hides the rolling-shutter
    bands the projector's refresh leaves on single frames."""
    t = time.time()
    while time.time() - t < settle_s:
        cap.read()
    frames = []
    while len(frames) < count:
        ok, f = cap.read()
        if ok:
            frames.append(f.astype(np.float32))
    return np.mean(frames, axis=0).astype(np.uint8)


if __name__ == "__main__":
    if sys.argv[1:2] == ["list"]:
        from pygrabber.dshow_graph import FilterGraph

        for i, name in enumerate(FilterGraph().get_input_devices()):
            print(i, name)
    elif sys.argv[1:2] == ["snap"]:
        cap = open_camera()
        frame = averaged(cap, 1.0)
        cap.release()
        cv2.imwrite(sys.argv[2], frame)
        print(sys.argv[2], frame.shape)
    else:
        print(__doc__)
