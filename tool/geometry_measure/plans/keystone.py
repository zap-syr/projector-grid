"""Keystone series: single-axis sweeps at four throw ratios, V x H, Balance.
Every step sets all five registers, so steps don't depend on each other."""
from ntc import fmt_deg, fmt_int, fmt_throw


def ks(tr, v=0.0, h=0.0, vb=0, hb=0):
    return [f"VXX:GMKS0={fmt_throw(tr)}", f"VXX:GMKS8={fmt_deg(v)}", f"VXX:GMKS9={fmt_deg(h)}",
            f"VXX:GMKI4={fmt_int(vb)}", f"VXX:GMKI7={fmt_int(hb)}"]


def tag(x):
    return ("m" if x < 0 else "p") + f"{abs(x):g}".replace(".", "_")


# The first frame (correction off) is the baseline every frame is mapped by.
# QPDI1 = Quad Pixel Drive; models that need it refuse geometry modes without it.
PLAN = [("k_base_off", ["VXX:GMMI0=+00000"]),
        ("k_zero", ["VXX:QPDI1=+00001", "VXX:GMMI0=+00001"] + ks(0.7))]

for tr in (0.7, 1.5, 3.0, 8.0):
    for v in (-40, -30, -20, -10, -5, 5, 10, 20, 30, 40):
        PLAN.append((f"k_tr{tag(tr)}_v{tag(v)}", ks(tr, v=v)))
    for h in (-15, -10, -5, 5, 10, 15):
        PLAN.append((f"k_tr{tag(tr)}_h{tag(h)}", ks(tr, h=h)))

for v in (-40, -20, 20, 40):
    for h in (-15, -8, 8, 15):
        PLAN.append((f"k_tr1_5_v{tag(v)}_h{tag(h)}", ks(1.5, v=v, h=h)))

for vb in (-60, -30, 30, 60):
    PLAN.append((f"k_tr1_5_vb{tag(vb)}", ks(1.5, vb=vb)))
    PLAN.append((f"k_tr1_5_v20_vb{tag(vb)}", ks(1.5, v=20, vb=vb)))
    PLAN.append((f"k_tr1_5_h10_vb{tag(vb)}", ks(1.5, h=10, vb=vb)))
for hb in (-30, -15, 15, 30):
    PLAN.append((f"k_tr1_5_hb{tag(hb)}", ks(1.5, hb=hb)))
    PLAN.append((f"k_tr1_5_h10_hb{tag(hb)}", ks(1.5, h=10, hb=hb)))
    PLAN.append((f"k_tr1_5_v20_hb{tag(hb)}", ks(1.5, v=20, hb=hb)))
for vb, hb in ((60, 30), (-60, -30)):
    PLAN.append((f"k_tr1_5_v20_h10_vb{tag(vb)}_hb{tag(hb)}", ks(1.5, v=20, h=10, vb=vb, hb=hb)))

PLAN.append(("k_end_zero", ks(1.5)))
