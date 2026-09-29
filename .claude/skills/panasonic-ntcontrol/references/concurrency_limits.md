# Connection Concurrency Limits

Empirical results from `tool/projector_stress_test.dart`, run against a real **PT-RQ25KE**
(flagship 3-chip model — treat these as a *ceiling*; cheaper models with weaker embedded
TCP stacks, e.g. PT-VMZ/PT-MZ series, will likely degrade at lower concurrency). Tested
2026-09-07 at `192.168.0.8:1024`.

Every probe was the read-only `QID` query — a full NTCONTROL cycle (connect → handshake →
MD5 auth → command → response → close), matching exactly what
`PanasonicProtocolService._sendSingleCommandEx` does per command.

Re-run before trusting these numbers on a different model:
```
dart run tool/projector_stress_test.dart <ip> <login> <password>
```

---

## Phase A — raw simultaneous TCP connections

Opened N sockets at once (no NTCONTROL exchange), held them open ~1.2s, counted survivors.

| N | ok | refused | timeout |
|---|---|---|---|
| up to 30 | all | 0 | 0 |

**The raw socket/accept-backlog ceiling is not the bottleneck** — the projector accepted 30
simultaneous bare TCP connections with zero refusals. Whatever limits concurrency is the
NTCONTROL command processor itself, not the TCP stack's connection cap.

---

## Phase B — concurrent full command cycles, one-shot burst

Simulates something like `geometry_correction_dialog.dart` opening and firing N queries at once.

| conc | ok% | p50 (ms) | p95 (ms) | max (ms) |
|---|---|---|---|---|
| 1 | 100 | 14 | 15 | 15 |
| 5 | 100 | 37 | 59 | 65 |
| 8 | 100 | 57 | 102 | 158 |
| 10 | 100 | 69 | 119 | 175 |
| **12** | 100 | 81 | **1038** | 1080 |
| 15 | 100 | 97 | **1100** | 1119 |
| 20 | 100 | 122 | **1104** | 1125 |

No failures at *any* level up to 20 — but there's a sharp knee between 10 and 12 concurrent:
below it, every request lands in under ~200ms; at 12+, the median stays low (~80-120ms) but
roughly 1 in 20 requests stalls ~1s (the projector is serializing the overflow behind a queue
slot, not rejecting it). A burst of 15 (what `geometry_correction_dialog.dart` used to send)
"works" on this model but risks a ~1s dialog-load stall on the tail, and on a weaker model the
overflow is more likely to come back as `ERR3` instead of just queuing.

**→ batch bursts at ≤8** to stay reliably under 200ms on any model.

---

## Phase C — sustained load (45s per level)

Simulates steady-state polling: as many full cycles as fit in 45 wall-clock seconds at each
concurrency level.

| conc | cycles/45s | throughput | ok% | p50 (ms) | p95 (ms) | max (ms) |
|---|---|---|---|---|---|---|
| 2 | 4134 | ~92/s | 100 | 19 | 24 | 52 |
| **3** | 3690 | ~82/s | 100 | 27 | 38 | 78 |
| 5 | 1790 | **~40/s** | 100 | 47 | **378** | **2022** |

Going from 3 → 5 concurrent **halves total throughput** (fewer cycles completed despite more
in flight — contention, not parallelism) and blows p95 latency out to 378ms (max over 2s).
No outright failures even at 5, but the projector is clearly thrashing.

**→ cap sustained per-projector concurrency at 3.** 2 is safer still and barely costs
throughput (92/s vs 82/s).

---

## Applied in code

- `PanasonicProtocolService.pollProjectorTelemetry` concurrency, via
  `WorkspaceNotifier._telemetryConcurrencyFor` — **3** for projects with ≤40 nodes, dropping to
  **2** above that (keeps total in-flight sockets for a poll cycle, roughly
  `min(totalNodes, networkBatchSize) * concurrency`, from growing unbounded as project size
  scales — see `OPTIMIZATION_PLAN.md` item 3.1).
- `geometry_correction_dialog.dart` `_loadCorner()` — 15 `QVX:GMFIx` queries now run in
  **batches of 8** instead of all at once.

If you add a new burst-style loader (`Future.wait` over several `sendRawCommand`/`sendCommand`
calls to the *same* projector), batch it the same way rather than firing everything at once —
see `_loadCorner()` for the pattern (`sublist` chunks of ≤8, sequential `await Future.wait`
per chunk).
