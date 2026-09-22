# Quad Pixel Drive — Corner Correction Limits

Research notes backing the per-model Corner Correction limit / Quad Pixel Drive
auto-enable work in `geometry_correction_dialog.dart`. Panasonic's official
RS-232C/LAN command-list PDFs do **not** give concrete numeric ranges for
Corner Correction (every model checked lists only `min.`/`max.` text
placeholders in that table), so the real limits had to be established via live
testing against a physical PT-RQ25K, cross-checked against public spec pages.

## Background

The app's Geometry Correction → Corner mode lets the user drag each of the 4
corners independently, in both H and V, clamped to a protocol range sent as
`VXX:GMFI1-4/6-9`. The original clamp values (`±384`/`±480` H, `±240`/`±300`
V depending on direction) matched the documented range for standard
WUXGA-class projectors. Panasonic's **Quad Pixel Drive** projectors use pixel
shifting to project into a larger virtual canvas than their native panel, and
on at least one such model this measurably widens how far a corner can be
pushed *inward* (not outward — outward is a fixed optical/mechanical limit
that never changes).

## Live test — PT-RQ25K (192.168.0.8)

Confirmed via direct NTCONTROL commands (see conversation; script has since
been deleted per project convention of not keeping one-off `tool/` probes):

```
QVX:GMFI1 (baseline)        -> +00300   (old standard V ceiling)
QVX:GMFI6 (baseline)        -> +00480   (old standard H ceiling)
VXX:GMFI1=+00600            -> accepted, read back as +00600
VXX:GMFI6=+00700            -> accepted, read back as +00700
```

So on PT-RQ25K the protocol genuinely accepts values beyond the WUXGA-class
range. Cross-checked against the projector's own on-screen menu (user
confirmed manual keypad entry independently), inward limits are:

- **Inward**: H `±960`, V `±600` (vs standard `±480`/`±300`)
- **Outward**: H `384`, V `240` — **unchanged**, same as every other model

### `QVX:QPDI1` (Quad Pixel Drive toggle) — behavior discovered live

- Query/write only work while geometry correction mode is `Off`. The instant
  any mode (Keystone/Curved/Corner) is active, `QVX:QPDI1` returns `ER401`
  regardless of the projector's actual Quad Pixel Drive state or model
  capability — confirmed by re-testing with the projector already in Corner
  mode (both `QVX:QPDI1` *and* `VXX:QPDI1=+00001` returned `ER401` in that
  state).
- On quad-pixel-capable models, Quad Pixel Drive must be ON to enter *any*
  non-`Off` geometry mode at all — confirmed via the projector's own menu
  (entering Keystone/Curved/Corner is blocked while QPD is off, menu items
  greyed out / errors).
- Net effect: **`QVX:QPDI1` cannot be used as a reliable capability probe**
  once the dialog might open with geometry correction already active (a
  common case) — there is no way to distinguish "model doesn't support this"
  from "model supports it but the register is temporarily locked because a
  mode is active" without forcing the projector briefly back to `Off`, which
  would visibly reset live geometry correction. Capability detection was
  therefore moved to a static per-model list (see below) instead of reading
  this register.
- The write side (`VXX:QPDI1=+00001`) is presumed idempotent — sending "ON"
  when it's already on is harmless — so the app doesn't need to know the
  current toggle state at all, only whether to send the command once when
  leaving `Off`.

## Full model survey (Product Finder / Lineup + spec pages + command-list PDFs)

Starting list of Quad-Pixel-Drive-spec'd models (per Panasonic's Product
Finder, supplied by the user):

```
PT-RQ45K PT-RQ35K2 PT-RQ35K PT-RQ32K PT-RQ25K PT-RQ22K PT-RQ18K PT-RQ13K
PT-REQ15L PT-REQ12L PT-REQ10L PT-REQ80L PT-RQ7L PT-RQ6L PT-FRQ60 PT-FRQ50
```

These split into **three distinct hardware tiers by output resolution** —
not one uniform bucket:

| Tier | Models | Native panel → output canvas | Corner Correction limits |
|---|---|---|---|
| **A** | PT-RQ25K, PT-RQ45K, PT-RQ35K/RQ35K2, PT-RQ18K, PT-REQ15L, PT-REQ12L, PT-REQ10L, PT-REQ80L | WUXGA (1920×1200) → **3840×2400** | **Confirmed** (PT-RQ25K, live test): inward 960 H / 600 V, outward 384 H / 240 V |
| **B** | PT-RQ32K, PT-RQ22K, PT-RQ13K | WQXGA (2560×1600) → **5120×3200** ("4K+") | **Unconfirmed** — likely wider than Tier A given the larger canvas jump, but no unit available to test. Left at the standard WUXGA-class limits (480/300) rather than guess. |
| **C** | PT-RQ7L, PT-RQ6L, PT-FRQ60, PT-FRQ50 | **3840×2160** (standard 4K UHD, not the 2400-tall canvas) | **Unconfirmed**. PT-FRQ60's command-list PDF has **no `QPDI1` register at all** — Quad Pixel Drive on this tier appears to be a fixed always-on optical technique with no NTCONTROL toggle, architecturally different from Tier A/B. |

Sources checked: Panasonic Product Lineup/Finder, individual product spec
pages under `docs.connect.panasonic.com/projector/products/<model>/spec/`,
and RS-232C/LAN command-list PDFs for the RQ35K/RZ34K family, the
RQ32K/RZ31K/RQ22K/RZ21K/RQ13K family, and PT-FRQ60 standalone. All three
command-list PDFs show only `min.`/`max.` placeholder text for every
`GEOMETRY-CORNER CORRECTION-*` row — no model's official documentation gives
concrete numbers anywhere. The only real numbers we have are the PT-RQ25K
live measurements above.

### Implication for auto-enabling Quad Pixel Drive

Tier A and Tier B both have the `QPDI1` register (confirmed present in their
command-list PDFs) and both require it ON to enter geometry correction —
sending `VXX:QPDI1=+00001` before leaving `Off` is safe and expected on both.
Tier C does **not** reliably have this register (confirmed absent for
PT-FRQ60) — sending it there would likely return `ERR1` (unknown command),
which the app's `sendRawCommand` collapses to `null`, triggering a spurious
"command failed" notification. So Tier C, and any unrecognized model, must
never have this command sent at all.

## Decision (2026-09-22)

- **Tier A only** gets the extended Corner Correction limits (960 H / 600 V
  inward) — these are the only numbers with real live confirmation.
- **Tier A + Tier B** get the Quad Pixel Drive auto-enable-on-leaving-`Off`
  behavior, since both are known to have the register and both are known to
  require it. Tier B keeps the standard (480/300) Corner Correction limits
  until real hardware is available to measure its actual ceiling.
- **Tier C and everything unrecognized** — behavior unchanged from before
  this feature: standard 480/300 limits, no `QPDI1` command ever sent.
- Model detection uses `QID` (already used elsewhere in the app for
  discovery) matched via substring `.contains()` against a truncated model
  list — trailing lens/body-variant letters (`K`, `K2`, `L`) are stripped
  from the match strings, keeping only the numeric model code, since that
  code is what actually determines the optical/resolution class (the
  trailing letter denotes lens/body configuration, not a different canvas):

  ```dart
  static const _tierAModels = [
    'PT-RQ25', 'PT-RQ45', 'PT-RQ35', 'PT-RQ18',
    'PT-REQ15', 'PT-REQ12', 'PT-REQ10', 'PT-REQ80',
  ];
  static const _tierBModels = ['PT-RQ32', 'PT-RQ22', 'PT-RQ13'];
  ```

  Verified no numeric collision between tiers (25/45/35/18 vs 32/22/13 vs
  7/6, plus the unrelated `FRQ60`/`FRQ50` prefix), so this truncation is safe
  against the currently-known model set. Residual risk: a hypothetical future
  Panasonic model reusing one of these numeric codes for an unrelated tier
  would be misclassified — accepted as a reasonable trade-off given Panasonic's
  current naming pattern.

## Open follow-ups (not blocking this implementation)

- Tier B's real Corner Correction ceiling is unmeasured. If a PT-RQ32K,
  PT-RQ22K, or PT-RQ13K becomes available, live-test the same way as
  PT-RQ25K and add a dedicated limit tier instead of reusing Tier A's numbers
  (the 5120×3200 canvas is proportionally larger than Tier A's 3840×2400, so
  Tier A's 960/600 is very likely still too conservative for Tier B, not a
  safe drop-in).
- Tier C's actual Quad Pixel Drive behavior (fixed always-on vs genuinely
  absent) is inferred only from PT-FRQ60's command list lacking `QPDI1`. Not
  verified live on any Tier C unit.
