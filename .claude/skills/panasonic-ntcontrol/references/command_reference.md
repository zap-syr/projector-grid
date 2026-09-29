# NTCONTROL Command Reference

All responses shown are **after** the `00` prefix is stripped by `_sendSingleCommand`.  
Commands are case-sensitive ASCII. Terminate with `\r` (handled internally).

---

## Query Commands

### Simple value queries (response is the value directly)

| Command | Description | Example response | Notes |
|---------|-------------|-----------------|-------|
| `QID` | Model name | `PT-RZ21K` | Used for discovery |
| `QSN` | Serial number | `SH1234567` | |
| `QPW` | Power status (binary) | `000` or `001` | `000`=standby, `001`=on. App now uses `QVX:POWI1` instead (below) for turning-on/cooling states. |
| `QSH` | Shutter (blank) status | `0` or `1` | `0`=open, `1`=closed |
| `QIN` | Active input source | `HD1`, `DVI1`, `SDI1` | String varies by model |
| `QTM:0` | Intake air temperature (°C) | `025` | Parse as int |
| `QTM:1` | Exhaust air temperature (°C) | `032` | Parse as int |

```dart
// Parsing simple values
final power = await sendRawCommand(ip, port, login, password, 'QPW');
final isOn = power == '001';

final shutter = await sendRawCommand(ip, port, login, password, 'QSH');
final isClosed = shutter == '1';

final temp = await sendRawCommand(ip, port, login, password, 'QTM:0');
final intakeTemp = int.tryParse(temp ?? '');
```

---

### QVX: Extended variable queries (response is `KEY=VALUE`)

The `QVX:` prefix queries extended projector variables. The response always comes back as `KEY=VALUE` — split on `=` and take the right side.

| Command | Description | Example response | Parsed value |
|---------|-------------|-----------------|--------------|
| `QVX:NSGS1` | Input signal name | `NSGS1=1080/60p` | Signal name/format of the main channel. Empty or `ER401` = no signal (also `ER401` while the projector isn't fully on) → the app shows `NO SIGNAL`. Lags the real state by a couple of seconds after power-on / input change. |
| `QVX:POWI1` | Power status (4-state) | `POWI1=+00003` | `+00001`=standby, `+00002`=turning on, `+00003`=on, `+00004`=cooling. Supersedes `QPW` (which only distinguishes standby/on) for the app's power telemetry — see `projector_node.dart`'s `PowerStatus` enum. |
| `QVX:RTMS1` | Projector runtime (hours) | `RTMS1=1234` | Integer hours |
| `QVX:VMOI2` | AC input voltage | `VMOI2=+00120` | Integer volts (leading `+` is safe for `int.parse`) |
| `QVX:ERRS2` | Error status bitmask | `ERRS2=000000000000` | 12-char string; non-zero chars indicate active errors |

```dart
// Parsing QVX: KEY=VALUE responses
String? parseQVX(String? raw) => raw?.split('=').last;

final raw = await sendRawCommand(ip, port, login, password, 'QVX:RTMS1');
final hours = int.tryParse(parseQVX(raw) ?? '');

final rawVoltage = await sendRawCommand(ip, port, login, password, 'QVX:VMOI2');
final volts = int.tryParse(parseQVX(rawVoltage) ?? '');  // int.parse handles leading +

final rawSignal = await sendRawCommand(ip, port, login, password, 'QVX:NSGS1');
final hasSignal = parseQVX(rawSignal) == '1';

final rawErrors = await sendRawCommand(ip, port, login, password, 'QVX:ERRS2');
final errors = parseQVX(rawErrors) ?? '';
final hasError = errors.contains(RegExp(r'[^0]'));
```

### `QVX:LRTS3=00` — light-source runtime (different shape, don't reuse `parseQVX`)

Unlike the `KEY=VALUE` commands above, this one's *query* already carries a sub-index (`=00`,
the light source number — laser projectors report it this way even with one light source), and
its *response* carries the hours after the **last `:`**, not after `=`:

| Command | Description | Example response | Parsed value |
|---------|-------------|-----------------|--------------|
| `QVX:LRTS3=00` | Light-source on-time (hours) | `LRTS3=00:1577` | Integer hours, after the last `:` |

Lamp-based models (no laser light source) reply `ER401` (no `:` present at all) — treat that,
and any reply with no parseable digits after the last `:`, as "unavailable" rather than `0`:

```dart
// workspace_provider.dart's actual parsing — note lastIndexOf(':'), not split('=')
final lightRaw = (telemetry['lightRuntime'] as String?)?.trim();
final lightColon = lightRaw?.lastIndexOf(':') ?? -1;
final lightHours = lightColon < 0
    ? null
    : int.tryParse(lightRaw!.substring(lightColon + 1).trim());
final display = lightHours == null ? '-' : '${lightHours}H';
```

This is a separate telemetry field (`lightRuntime`) from `QVX:RTMS1`'s `runtime` — the app shows
both as distinct Monitoring-table columns ("Runtime" vs "Light Runtime").

---

## Control Commands

| Command | Description | Notes |
|---------|-------------|-------|
| `PON` | Power on | |
| `POF` | Power off (standby) | |
| `OSH:1` | Close shutter (blank on) | |
| `OSH:0` | Open shutter (blank off) | |
| `IIS:{source}` | Select input source | e.g. `IIS:HD1`, `IIS:DVI1`, `IIS:SDI1` |
| `AMT:1` | Mute audio | |
| `AMT:0` | Unmute audio | |

```dart
// Control commands — use sendCommand(), returns bool success
final ok = await sendCommand(ip, port, login, password, 'PON');
final ok = await sendCommand(ip, port, login, password, 'IIS:HD1');
```

---

## Commands used by roadmap features

Confirmed in Panasonic's PT-RQ35K2/RZ34K2 command list (all three series unless noted). The
full list is in `rq35k2_rz34k2_commands.md`. That list is **not exhaustive**: commands the app
already sends and that aren't in it (e.g. the solid-colour test patterns) are verified in use —
don't drop them because the list lacks them.

### Test pattern
| Command | Description | Reply |
|---|---|---|
| `OTS:xx` | Select test pattern (`00` = off) | echo |
| `QTS` | Current test pattern | two-digit code only, e.g. `07` (no `OTS:` prefix) |

Codes (the app's set in `control_bar.dart` `_testPatternOptions` / `osc_service.dart`, plus
extras from the Panasonic list):

| Code | Pattern | Source |
|---|---|---|
| `00` | Off | app + list |
| `01` / `02` | White / Black | app + list |
| `22` / `23` / `24` | Red / Green / Blue (solid) | app |
| `28` / `29` / `30` | Cyan / Magenta / Yellow (solid) | app |
| `05` / `06` | Window / Reversed window | app + list |
| `07` | Cross hatch | app + list |
| `70`–`75` | Cross hatch red / green / blue / cyan / magenta / yellow (the list calls them "Focus <colour>") | app + list |
| `08` | Colour bars vertical | app + list |
| `51` | Colour bars horizontal | app |
| `52` | Colour bar side | list |
| `78` | Focus | app + list |
| `32` / `33` / `34` | Focus level 0 / 50 / 100 % (commented out in the app) | list |
| `59` | Aspect frame (16:9 / 4:3) | app + list |
| `80`–`83` | 3D-1…3D-4 (RZ34K2/RZ330 only) | list |
| `87` | Circle | app + list |

### Lens
| Command | Description | Notes |
|---|---|---|
| `VXX:LNSI2=+nnnnn` / `LNSI3` / `LNSI4` / `LNSI5` | Move shift H / shift V / focus / zoom one step | `+00000` slow+, `+00001` slow−, `+00100` normal+, `+00101` normal−, `+00200` fast+, `+00201` fast− |
| `VXX:LNSI1=+00001` | Lens home position | |
| `QVX:LNSI7` / `LNSI8` / `LNSI9` / `LNSIA` | **Absolute** position H / V / focus / zoom | reply `LNSI7=±nnnnn`; writable with `VXX:` |
| `QVX:LNSSD` | H, V, focus, zoom in one reply | `LNSSD=*H *V *F *Z`; `LNSSB` = H/V, `LNSSC` = H/V/F. Exact separator not confirmed — read a live unit before parsing |
| `VXX:LNMI1=+0000n` | **Load** lens memory n+1 (`+00000`…`+00009` = memory 1…10) | no query |
| `VXX:LNMI2=+0000n` | **Save** current lens position to memory n+1 | no query |
| `VXX:LNMI3=+0000n` | **Delete** lens memory n+1 | no query |
| `QVX:NCGS5`…`NCGS7`, `NCGS9`, `NCGSA`…`NCGSF` | Lens memory 1–10 names (`NCGS8` is skipped — it's the projector name) | reply `NCGS5=<name>`; `VXX:` writes |
| `QVX:LNEI1` / `QVX:LNEI4` / `QVX:LNES5` | Lens type / lens ID / lens name | |

Ranges are "by lens type" (e.g. shift H ±3306, V −4266…+7034, focus 0…3466 on the listed
lens). There is **no query for which lens memory is active** and no way to read a memory's
stored position — only load/save/delete by slot.

### Picture mode
| Command | Reply of `QPM` |
|---|---|
| `VPM:DYN` / `NAT` / `STD` / `CIN` / `GRA` / `DIC` / `USR` | `DYN` … `USR` (dynamic, natural, standard, cinema, graphic, DICOM sim., user) |

### Identity / on-screen display
| Command | Description | Notes |
|---|---|---|
| `QVX:NCGS8` / `VXX:NCGS8=<name>` | Projector name (the one shown in the web UI / network menu) | reply `NCGS8=PROJECTOR1` |
| `OOS:0` / `OOS:1`, `QOS` | On-screen display off / on | hides/shows *all* OSD, not a name overlay |
| `STS` | Remote STATUS key (opens the status screen on the image) | no reply data |
| `RIS:nn`, `RVS:0/1`, `QVY` | Remote-control ID / "ID ALL" | IR remote addressing, **not** a visual identify |

The Panasonic list has no "show device name" command (VSS's *Show Device Name* isn't in it).

### Shutter behaviour
| Command | Description | Notes |
|---|---|---|
| `QVX:SEFS1` / `QVX:SEFS2` | Shutter fade-in / fade-out time | `0.0` (off), `0.5`…`4.0`, `5.0`, `7.0`, `10.0` s; `VXX:` writes |
| `QVX:SEFI3` / `SEFI4` / `SEFI5` | Shutter state at startup / on shut-off / mechanical shutter | |

Any fade time > 0 applies to every `OSH` command, so a shutter "blink" is not instant.

### Extra status queries (candidates for monitoring/alerts)
| Command | Description | Reply |
|---|---|---|
| `QVX:ERRS1` | Self-diagnosis (the app polls `ERRS2`) | `ERRS1=…` |
| `QLS` | Light status | `0` all off, `1` on |
| `QVX:BACI4` | Backup input status | `+00000` inactive, `+00001` **running on backup input** |
| `QVX:DKSI1` | DIGITAL LINK link | `+00000` no link, `1` DIGITAL LINK, `2` LPM, `3` Ethernet |
| `QVX:MPSI2` | Multi Projector Sync link status | `MPSI2=+nnnnn` |
| `QVX:ADRI1` | Auto cooling condition status | `ADRI1=+nnnnn` |
| `QVX:CLTS1` | Continuous lighting time | `CLTS1=<hours>:<minutes>` |
| `QVX:SVRS0` / `QVX:SVRS1` | Main / network firmware version | `SVRS0=1.00.01` |
| `QMA` | MAC address | `AB0102030405` |

### Other controls
| Command | Description |
|---|---|
| `OFZ:0` / `OFZ:1`, `QFZ` | Freeze off / on |
| `VXX:OPEI1=+nnnnn` | Operating mode (`+00000` normal, `+00001` eco, `+00021` quiet, `+00101`…`+00103` user 1–3) |
| `VXX:LOPI2=+nnnnn` | Light output, `+00050` (8 %)…`+01000` (100 %) |

---

## Finding Commands for Unlisted Features

Check `rq35k2_rz34k2_commands.md` first — the PT-RQ35K2/RZ34K2/RZ330 list (≈450 functions);
the basic commands carry over to other Panasonic models. It isn't exhaustive, so also grep
`lib/` for commands the app already sends.

The RS-232C command list for each projector model contains the full command set — it also applies to LAN/NTCONTROL. Panasonic publishes these per model at panasonic.net/cns/projectors (search for your model + "RS232C").

Commands follow these conventions:
- Query: starts with `Q` (e.g. `QPW`, `QIN`, `QVX:XXXX`)
- Control: 3-letter verb, often with `:param` (e.g. `PON`, `OSH:1`, `IIS:HD1`)
- Response to a control: echoes the command or returns `OK`
