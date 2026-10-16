"""Curved series: arcs at three throw ratios with the aspect kept and not,
both arcs together, Keystone and Balance inside Curved."""
from ntc import fmt_deg, fmt_int, fmt_throw


def cv(tr, va=0, ha=0, v=0.0, h=0.0, vb=0, hb=0, aspect=1):
    return [f"VXX:GMCS0={fmt_throw(tr)}", f"VXX:GMCI3={fmt_int(va)}", f"VXX:GMCI7={fmt_int(ha)}",
            f"VXX:GMCS8={fmt_deg(v)}", f"VXX:GMCS9={fmt_deg(h)}",
            f"VXX:GMCI2={fmt_int(vb)}", f"VXX:GMCI6={fmt_int(hb)}", f"VXX:GMCIA={fmt_int(aspect)}"]


def tag(x):
    return ("m" if x < 0 else "p") + f"{abs(x):g}".replace(".", "_")


PLAN = [("c_base_off", ["VXX:GMMI0=+00000"]),
        ("c_zero", ["VXX:QPDI1=+00001", "VXX:GMMI0=+00002"] + cv(1.5))]

for tr in (0.7, 1.5, 3.0):
    for asp in (1, 0):
        for a in (-40, -30, -20, -10, 10, 20, 30, 40):
            PLAN.append((f"c_tr{tag(tr)}_a{asp}_va{tag(a)}", cv(tr, va=a, aspect=asp)))
            PLAN.append((f"c_tr{tag(tr)}_a{asp}_ha{tag(a)}", cv(tr, ha=a, aspect=asp)))

for va in (-40, -20, 20, 40):
    for ha in (-40, 40):
        PLAN.append((f"c_tr1_5_a1_va{tag(va)}_ha{tag(ha)}", cv(1.5, va=va, ha=ha)))

for v in (-30, -15, 15, 30):
    PLAN.append((f"c_tr1_5_a1_v{tag(v)}", cv(1.5, v=v)))
    PLAN.append((f"c_tr1_5_a1_va30_v{tag(v)}", cv(1.5, va=30, v=v)))
for h in (-15, -8, 8, 15):
    PLAN.append((f"c_tr1_5_a1_h{tag(h)}", cv(1.5, h=h)))
    PLAN.append((f"c_tr1_5_a1_ha30_h{tag(h)}", cv(1.5, ha=30, h=h)))

for vb in (-60, -30, 30, 60):
    PLAN.append((f"c_tr1_5_a1_vb{tag(vb)}", cv(1.5, vb=vb)))
    PLAN.append((f"c_tr1_5_a1_va30_vb{tag(vb)}", cv(1.5, va=30, vb=vb)))
    PLAN.append((f"c_tr1_5_a1_v20_vb{tag(vb)}", cv(1.5, v=20, vb=vb)))
for hb in (-30, -15, 15, 30):
    PLAN.append((f"c_tr1_5_a1_hb{tag(hb)}", cv(1.5, hb=hb)))
    PLAN.append((f"c_tr1_5_a1_ha30_hb{tag(hb)}", cv(1.5, ha=30, hb=hb)))
    PLAN.append((f"c_tr1_5_a1_h10_hb{tag(hb)}", cv(1.5, h=10, hb=hb)))

PLAN.append(("c_end_zero", cv(1.5)))
