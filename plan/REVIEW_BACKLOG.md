# Review backlog

Findings from the pre-2.0.0 `/code-review` passes over `lib/core/services/`,
`presentation/providers/` and `domain/` (2026-10-25) that were left for after
the release. P1s and the chosen P2s are already fixed. Items marked
**verified** were checked against the code; the rest are as the review
reported them, so confirm before fixing. Line numbers are from that date.

## P2: noticeable at a show, rare

### 1. Signal lost raised for a dropout that has already ended
`signal_watch_provider.dart:283`. `_confirmLoss` records an open `SignalLoss`
once `QVX:POWI1` says `on`, without checking whether a newer `NSGS1` reading
showed the signal back while the confirmation was in flight. A slow POWI1
reply plus a present signal on the next 2 s query gives a critical alert
(notification, sound) that recovers on the next reading as "Back after 0 s".
Fix: drop the confirmation if a reading newer than the one that started it
saw the signal.

### 2. Event log keeps growing when rows fold
`event_log_rows.dart:326`. `capLogRows` caps *rows* (5000), not events. A
batch command to 100 projectors is one row of about 100 events, and repeats
fold into one row, so the event list can grow far past 5000 and every new
event rebuilds all rows (`buildLogRows` over the whole list). Shows up over
a multi-day run with a show controller sending batch commands often. Fix:
also cap the event count, or keep the rows and update them incrementally.

### 3. PON then POF leaves a power loop that can't be cancelled (**verified**)
`workspace_provider.dart:1266`. The power-transition loop has no generation
check: if POF is sent while the PON loop's POWI1 query is in flight, the old
loop resumes and `scheduleNext()` overwrites the new loop's timer in
`_powerTransitionTimers`. Two loops then poll POWI1 every 2 s for up to
2 min, `isNodeBusy` goes false while one is still querying, and
`_forgetNode` can't cancel the leaked one. Fix: a per-node generation
counter checked after each await.

### 4. A poll from before an IP edit writes the old projector's serial
`workspace_provider.dart:769`. A poll in flight when Edit Projector changes
the IP or credentials still applies its result by node id: old serial,
`polled: true`, `connected`. Later polls then skip QSN, so the wrong serial
stays until the projector next goes offline. Fix: drop a poll result whose
IP or credentials no longer match the node.

### 5. Pre-show: the first read overwrites a change made during it
`pre_show_provider.dart:35`. `_load()` writes its `QVX:PSMI1` result without
checking `_gen`. Clicking Pre-show right after the preview opens shows "off"
while the projector goes into Pre-show, until `set()`'s confirm loop ends.
Fix: check `_gen` after the await, as `set()` does.

### 6. Web preview feed after an IP or password edit
`web_preview_feeds.dart:128`. The feed subscribed with the IP and
credentials at open time, but `_status()` reads the node's current ones, so
after an edit every workspace change `ref.read`s auto-dispose family members
nobody listens to: a WebSocket and an HTTP fetch to the new IP, opened and
disposed each poll tick. Fix: read with the values the feed subscribed with,
or restart the feed when they change.

### 7. Nodes busy with Alignment or overlapping commands look idle
`workspace_provider.dart:1068`. `_dispatching` is a `Set`, so the first of
two overlapping dispatches to one node clears it while the second is in
flight; Alignment's `_capture` and `_syncLoop` never mark nodes at all. The
signal watch can then add `QVX:NSGS1` on top, past the connection limit
`isNodeBusy` is meant to keep. Fix: a per-node count, and mark Alignment's
sends.

### 8. A slow projector holds a signal watch slot for about 4.7 s
`panasonic_protocol_service.dart:331`. `sendQuickQuery` promises about 3 s,
but its 1.5 s timeouts apply separately to connect, handshake and reply,
plus a 200 ms close wait. One sick projector delays signal checks for the
healthy ones. Fix: one overall deadline around the whole exchange.

### 9. Trackpad: pinch while panning stops the pan
`projector_workspace.dart:925`. Every pinch update calls `_setZoom`, whose
post-frame `jumpTo` on both scroll controllers cancels the trackpad drag in
progress, so the rest of a combined pinch and two-finger pan (and its fling)
is lost. Fix: move the offsets without cancelling the drag, or defer the
`jumpTo` until the gesture ends.

## P2: input, interface, network

### 10. Status bar says "All offline" before the first poll
`status_bar_view.dart:257`. `offlineTooltip` counts nodes with
`polled == false`, which the Offline alert and `monitoringStatusOf`
deliberately skip. Right after a project opens the tooltip reads "All 40
offline, Check the network connection" until the first poll pass finishes.

### 11. Geometry preview recomputed on every rebuild
`geometry_preview.dart:235`. `keystonePreview` / `curvedPreview` run
Nelder-Mead (up to 400 iterations of a 22-step bisection over 52 points)
on every call, and `geometry_correction_dialog.dart` calls them from
`build()`. Any rebuild (typing, hover, a slider drag, telemetry) recomputes.
Fix: memoize on the input tuple, or compute in the dialog state when inputs
change.

### 12. PIN check runs on the UI isolate
`web_auth.dart:112`. Each login runs up to two PBKDF2 checks (10,000 rounds
of pure-Dart HMAC-SHA256) synchronously, and anyone on the LAN can trigger
it without a session. Logins from several IPs make the canvas and polling
stutter. Fix: `Isolate.run` for `verifyPin`.

### 13. `external_links.dart` passes the URL through cmd.exe unquoted
`external_links.dart:19`. `Process.run('cmd', ['/c', 'start', url])` runs
`&`, `|` and `^` in the URL as shell syntax. Callers build the URL from
`node.ipAddress`, which a loaded `.pgrid` doesn't validate, so a crafted
project file can run a command when *Web UI* is clicked; a harmless URL
with `&` in its query is cut off too. Fix: `start "" "<url>"` with proper
quoting, or `rundll32 url.dll,FileProtocolHandler`, and validate IPs on load.

### 14. OSC listener reads the field, not its own socket
`osc_service.dart:278`. The listener uses `_socket!` instead of the local
`socket` it was attached to. A read event right after `stop()` throws a
null check error; after a quick restart it drains a datagram from the new
socket. Fix: capture the local socket in the closure.

## P3: cleanup

- `web_api.dart:276`: `_operatorPost` reads the body outside the
  `FormatException` try, so a non-UTF-8 body gives 500 instead of 400.
- `log_files.dart:78`: `ErrorRepeatGate._entries` gets one key per distinct
  message and first frame and never drops any.
- `group_naming.dart:337`: `groupOscAddress` keeps leading and trailing
  hyphens (`Stage 1!` → `/group/stage-1-`) unlike `CustomCommand.slugOf`.
  Switching needs a migration or fallback match for saved `oscAddress`.
- Month and weekday names, the DST-rounded day offset and `HH:mm` parsing are
  copied across `schedule_next_run.dart`, `schedule_labels.dart`,
  `alerts.dart`, `event_log_view.dart`, `schedule_due.dart` and
  `task_draft.dart`.
- `workspace_provider.dart:1151`: `_pollSpecificTelemetry` and
  `_refreshSignalAfterPowerOn` re-implement `stripSignalKey` / `formatSignal`
  and always assign a new list, so every POWI1 read during a power transition
  rebuilds all workspace listeners even when nothing changed.
- `projector_card.dart:33`: `kCanvasDragDevices` is a canvas-wide policy that
  `projector_workspace.dart` also uses; move it out of the card file.
- `tool/projector_simulator.dart:554`: `catchError((_) {})` hides every
  socket error, not only the ECONNRESET / EPIPE from the reachability probe.
