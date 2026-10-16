"""Keystone limits series: where the projector caps the applied angle, per
throw ratio (it accepts and reads back up to 40 everywhere)."""
from ntc import fmt_deg, fmt_int, fmt_throw


def ks(tr, v=0.0, h=0.0):
    return [f"VXX:GMKS0={fmt_throw(tr)}", f"VXX:GMKS8={fmt_deg(v)}", f"VXX:GMKS9={fmt_deg(h)}",
            f"VXX:GMKI4={fmt_int(0)}", f"VXX:GMKI7={fmt_int(0)}"]


def tag(x):
    return ("m" if x < 0 else "p") + f"{abs(x):g}".replace(".", "_")


PLAN = [("l_base_off", ["VXX:GMMI0=+00000"]),
        ("l_zero", ["VXX:QPDI1=+00001", "VXX:GMMI0=+00001"] + ks(1.0))]
for tr in (0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 2.0):
    for v in (20, 25, 30, 35, 40):
        PLAN.append((f"l_tr{tag(tr)}_v{tag(v)}", ks(tr, v=v)))
    PLAN.append((f"l_tr{tag(tr)}_h{tag(15)}", ks(tr, h=15)))
    PLAN.append((f"l_tr{tag(tr)}_v40_h15", ks(tr, v=40, h=15)))
    PLAN.append((f"l_tr{tag(tr)}_v20_h8", ks(tr, v=20, h=8)))
