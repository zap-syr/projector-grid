---
name: panasonic-ntcontrol
description: Expert guide for implementing and debugging Panasonic NTCONTROL (Protocol 2) TCP commands in the projector-grid Flutter app. Use this skill whenever you need to add a new projector control or query command, figure out what a command returns and how to parse its response, extend PanasonicProtocolService with new telemetry fields, or debug ERR responses. Triggers on phrases like "add a command to query X", "how do I get the lens position", "what does QPW return", "why is my command returning ERR", "add telemetry for X", "what's the command for shutter/input/power/temperature".
---

# Panasonic NTCONTROL Protocol 2 — Implementation Guide

This skill covers **Protocol 2 (NTCONTROL)**, which is what projector-grid uses exclusively. Protocol 1 (PDPCONTROL) is for plasma/LCD displays — ignore it.

All implementation lives in `lib/core/services/panasonic_protocol_service.dart`.

---

## Wire Format

### 1. Connect
TCP to `{ip}:{port}`. Default port is **1024**. Connect timeout: 4s.

### 2. Handshake — what the projector sends first
```
NTCONTROL 1 a3f2b8c1\r   ← protected mode (password is set)
NTCONTROL 0\r             ← non-protected mode
```
The 8-char hex token after `1` is the random challenge used for auth.

### 3. Build the command prefix

**Protected mode** — MD5 of `{username}:{password}:{token}`:
```dart
final hashStr = '$login:$password:$token';
commandPrefix = '${md5.convert(utf8.encode(hashStr))}00';
// Result: 32-char hex hash + literal "00" → 34 chars total
```

**Non-protected mode:**
```dart
commandPrefix = '00';
```

### 4. Send a command
```
{commandPrefix}{COMMAND}\r
```
Examples:
```
// Protected:     "da39a3ee5e6b4b0d3255bfef95601890ac00PON\r"
// Non-protected: "00PON\r"
```

### 5. Parse the response
Response format: `00{data}\r`

`_sendSingleCommandEx` strips exactly the first 2 chars when the trimmed response starts with
`00` — it does **not** search for `00` inside the string (an earlier version did, via
`indexOf('00')`, which could match inside a model name and strip the wrong amount):
```dart
final trimmed = response.trim();
final result = trimmed.startsWith('00') && trimmed.length > 2
    ? trimmed.substring(2)
    : trimmed;
// "00001" → "001"
// "00PT-RZ21K" → "PT-RZ21K"
// "00RTMS1=1234" → "RTMS1=1234"
```

### 6. Connection lifetime
Every projector in this app **closes the TCP connection after each command response**. `_sendSingleCommand` handles this — it opens a fresh socket, exchanges one command, then destroys the socket. Never try to reuse a socket across multiple commands.

The projector closes ~1 ms after the reply (PT-RQ35K, 2026-10-05); a second command on the same socket gets nothing. The side that closes first keeps the socket in TIME_WAIT (Windows: 16,384 ephemeral ports, ~120 s). Destroying our socket right after the reply won the race ~5 times in 20 and left those on the PC, so `_sendSingleCommandEx` waits up to 200 ms for the projector's close (`onDone`) before `destroy()`, which leaves none on our side. Keep that wait when changing the send path: with 150 projectors polled every 2 s (Signal watch) the difference is ~0 vs ~3,200 occupied ports.

---

## Error Codes

| Response | Meaning | What to do |
|----------|---------|------------|
| `ERR1` | Unknown command string | Check spelling/capitalisation |
| `ERR2` | Parameter out of range | Check the parameter value |
| `ERR3` | Projector busy or unavailable right now | Retry after a short delay |
| `ERR4` | Timeout or unavailable period | Projector may be warming/cooling |
| `ERR5` | Invalid data length | Command string malformed |
| `ERRA` | Auth failed — wrong password/username | Check credentials |
| `ER401` | Command processing error | Usually a firmware issue |

All error codes start with `ER`, so the existing check `response.startsWith('ER')` catches them all.

These are *command* errors. The projector's own fault codes (`U200`, `F305`, `H001`…) are a
different thing: they come back as data in the `QVX:ERRS2` reply. Their meanings are in
`references/command_reference.md` → **Self-diagnosis codes**.

---

## Connection Concurrency Limits

Every command opens its own TCP connection and closes it when done (see "Connection lifetime"
above), so firing several queries at once via `Future.wait` means several simultaneous
connections to the same projector. Empirically (real PT-RQ25KE, see
`references/concurrency_limits.md` for the full stress-test data and methodology):

- Raw TCP connections aren't the limit — the projector accepts 30+ simultaneous sockets fine.
- **One-shot bursts**: reliable (100% success, <200ms) up to ~10 concurrent full command
  cycles; at 12+ it still succeeds but ~5% of requests stall ~1s waiting for a processing slot.
  **Batch bursts at ≤8** (see `_loadCorner()` in `geometry_correction_dialog.dart`).
- **Sustained/polling load**: throughput peaks around 3 concurrent and *halves* at 5, with p95
  latency jumping ~10x. **Cap steady-state per-projector concurrency at 3** — dropping to 2 once
  a project has >40 nodes, so total in-flight sockets across all projectors don't grow unbounded
  (`WorkspaceNotifier._telemetryConcurrencyFor`).

Cheaper models likely degrade at lower concurrency than this flagship did — re-run
`tool/projector_stress_test.dart` against a specific model before raising these caps for it.

---

## Which Method to Use

| Situation | Method | Returns |
|-----------|--------|---------|
| Fire-and-forget control (power, shutter, input) | `sendCommand()` | `bool` success |
| Query a single value, ER-code = "couldn't get it" | `sendRawCommand()` | `String?` (null on any failure, incl. `ERxxx`) |
| Query a value where an `ERxxx` reply is itself meaningful data (e.g. `ER401` = "no signal right now") | `sendRawCommandPreservingErrorCodes()` | `String?` (null only on a genuine transport failure — timeout/handshake error, never a real `ERxxx`) |
| Add to the monitoring table | add the command inside `pollProjectorTelemetry()`'s bounded-concurrency query list | see below |
| Discovery / auth probe | `_sendSingleCommandEx()` with `QID` | handled internally |

`sendRawCommand` and `sendRawCommandPreservingErrorCodes` both call `_sendSingleCommand`
internally and differ only in which responses they collapse to `null`:
`_isFailureResponse` (used by `sendRawCommand`) treats `'Timeout'`, any `'Error: …'` sentinel,
*and* any `ERxxx` projector code as failure. `_isTransportFailure` (used by the
"preserving" variant) treats only `'Timeout'`/`'Error: …'` as failure, so a real `ERxxx` reply
comes through as data for the caller to branch on.

---

## Adding a New Command

### Control command (no return value needed)
```dart
// Example: mute audio
await sendCommand(ip, port, login, password, 'AMT:1');
```

### Query command (single value)
```dart
final raw = await sendRawCommand(ip, port, login, password, 'QLN');
if (raw == null) return; // error or timeout
// parse raw as needed
```

### Add to telemetry polling
`pollProjectorTelemetry()` (see full walkthrough below) sends one `QID` probe, then a fixed list
of queries via `_runBounded`. To add a field, add the command to that list and give it a
matching `telemetry['yourKey'] = valueOrNull(results[N])` line at the matching index — get the
index right, since `results` is positional, not keyed:
```dart
final results = await _runBounded<String>([
  () => _sendSingleCommand(ip, port, login, password, 'QSN'),
  // ...existing queries...
  () => _sendSingleCommand(ip, port, login, password, 'QCMD'), // new
], concurrency);
// ...
telemetry['yourKey'] = valueOrNull(results[11]); // index matches position above
```
Then consume the new key wherever `pollProjectorTelemetry` results are processed
(`workspace_provider.dart`'s `_pollSingleProjector`), and add the field to `ProjectorNode`
(Freezed — re-run `build_runner`) if it needs to reach the UI.

---

## How `pollProjectorTelemetry()` Actually Works

This is the method behind the Monitoring table's polling, and it has absorbed logic that used
to live in a separate `probeProjector()` method — that method is gone; everything below happens
in one call now.

1. **One `QID` probe** classifies reachability/auth before anything else:
   - `'Error: Unrecognized Auth Token'` or `'ERRA'` → `ProbeResult.unauthorized`, `telemetry: null`
     (protected projector, but the challenge token didn't parse or auth was rejected).
   - `'Timeout'`, contains `'Error'`, empty, or starts with `'ER'` → `ProbeResult.offline`,
     `telemetry: null`.
   - Otherwise `QID`'s response is the model name, stored as `telemetry['modelName']`.
2. **11 more queries run through `_runBounded`** (a small fixed-size worker-pool helper — not
   `Future.wait`) at the caller-supplied `concurrency` (see the concurrency section above for why
   it's bounded, and `WorkspaceNotifier._telemetryConcurrencyFor` for how the caller picks the
   number). Order matters — `results` is positional:

   | # | Command | Telemetry key |
   |---|---------|---------------|
   | 0 | `QSN` | `serialNumber` |
   | 1 | `QVX:POWI1` | `power` |
   | 2 | `QSH` | `shutter` |
   | 3 | `QIN` | `input` |
   | 4 | `QVX:NSGS1` | `signal` |
   | 5 | `QVX:RTMS1` | `runtime` |
   | 6 | `QVX:LRTS3=00` | `lightRuntime` |
   | 7 | `QTM:0` | `intakeTemp` |
   | 8 | `QTM:1` | `exhaustTemp` |
   | 9 | `QVX:VMOI2` | `acVoltage` |
   | 10 | `QVX:ERRS2` | `errors` (fault codes, see Self-diagnosis codes) |

3. **If every one of those 11 fails** (`_isFailureResponse` on all of them), the whole call
   returns `ProbeResult.offline` even though `QID` itself answered — a projector that answers one
   probe by fluke but can't sustain a real telemetry cycle (overwhelmed TCP stack, dropping
   mid-cycle) should read as offline, not as "connected" with a table row full of `Timeout`.
4. **Otherwise each field goes through `valueOrNull`**, which is `_isTransportFailure` — narrower
   than `_isFailureResponse`. A field whose query merely dropped at the transport level becomes
   `null` (so `workspace_provider.dart` falls back to the node's last-known value instead of
   parsing a stray `'Timeout'` string as data). But a real `ERxxx` reply — e.g. `QVX:RTMS1`
   answering `ER401` when there's genuinely no signal — is **kept as the field's value**, because
   several parsers in `workspace_provider.dart` branch on that exact code (see `runtimeRaw ==
   'ER401'` in `_pollSingleProjector`).
5. **Final status**: `ProbeResult.online` if the projector is in protected mode, otherwise
   `ProbeResult.unprotected`. `workspace_provider.dart` maps this to `ConnectionStatus.connected`
   / `.unprotected` and logs "Came online" / "Went offline" / "Authentication failed" transitions.

`QVX:LRTS3=00` doesn't follow the plain `QVX:KEY=VALUE` → take-the-value-after-`=` pattern used
by the other `QVX:` commands above — see `references/command_reference.md` for its
`LRTS3=00:<hours>` response shape (parse after the *last* `:`, not `=`) before copying the
generic `QVX:` parsing snippet for it.

---

## Response Formats Reference

See `references/command_reference.md` for the known commands, their raw response strings, and parsing code snippets. Always check there first before guessing a command string.

`references/rq35k2_rz34k2_commands.md` is Panasonic's official PT-RQ35K2/RZ34K2/RZ330 list
(≈450 functions, one table row each). It's large, so **grep it** by command key (`LNMI`, `QTS`,
`SEFS`) or function name rather than reading it whole. It isn't exhaustive — commands already
sent from `lib/` are verified even when missing from it.

---

## When a Command Isn't in the Reference

If the user asks for a feature whose command string isn't in `references/command_reference.md`, `references/rq35k2_rz34k2_commands.md` or already used in `lib/`, **do not guess or invent a command string**. The RS-232C/LAN command set varies by projector model and firmware, and a wrong command silently fails or returns `ERR1`.

Instead, ask the user for one of:
- The exact command string (e.g. from their projector's RS-232C spec or a working system)
- A reference document to add to the skill (RS-232C PDF, command list, etc.)

Example response when a command is unknown:
> "I don't have the command string for lens zoom position in the reference. Could you share the command from your projector's RS-232C manual, or drop the command list document here so I can add it? The wire format and parsing will follow exactly the same pattern as the other `QVX:` commands."

Once the user provides the command, apply it using the existing patterns (wire format, `QVX:` parsing, error handling) and suggest adding it to `references/command_reference.md` for future use.
