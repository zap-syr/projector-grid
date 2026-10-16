"""Runs a series plan: for each step, sends its NTCONTROL commands, waits for
the projector to settle, saves one averaged camera frame, and reads back what
the projector kept (it may clamp a value without an error).

    python capture.py plans/keystone.py captures/keystone [settle_s]

Writes <out>/<step>.png and appends one JSON line per step to <out>/log.json.
"""
import json
import os
import runpy
import sys

import cv2

import camera
import ntc


def main():
    plan = runpy.run_path(sys.argv[1])["PLAN"]
    out = sys.argv[2]
    settle = float(sys.argv[3]) if len(sys.argv) > 3 else 2.5
    os.makedirs(out, exist_ok=True)
    cap = camera.open_camera()
    try:
        with open(os.path.join(out, "log.json"), "a") as log:
            for name, cmds in plan:
                replies = [(c, ntc.send(c)) for c in cmds]
                bad = [r for r in replies if r[1].startswith("ER")]
                frame = camera.averaged(cap, settle)
                cv2.imwrite(os.path.join(out, f"{name}.png"), frame)
                keys = [c[4:].split("=")[0] for c in cmds if c.startswith("VXX:")]
                actual = {k: ntc.qvx(k) for k in keys}
                log.write(json.dumps({"name": name, "cmds": replies, "actual": actual}) + "\n")
                log.flush()
                print(name, f"ERR {bad}" if bad else "ok", actual, flush=True)
    finally:
        cap.release()


if __name__ == "__main__":
    main()
