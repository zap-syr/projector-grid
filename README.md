# Projector Grid

A Windows desktop app for controlling and monitoring multiple projectors over a local network using the Panasonic NTCONTROL/TCP protocol.

## Features

- **Multi-projector workspace** — infinite canvas with draggable projector cards, zoom, marquee selection, and grid snapping
- **Real-time monitoring** — table view with live telemetry: power status, shutter, input, signal name, runtime, temperatures, voltage, and error codes
- **Group control** — organize projectors into named groups and send commands to a group or all projectors simultaneously
- **Controls panel** — power on/off, shutter open/close, OSD, input selection, lens shift, focus, zoom, and test patterns
- **Brightness control** — light output adjustment (8–100%) with real-time feedback
- **Color correction** — color matching (3-color, 7-color, measured) and color temperature control (preset or custom Kelvin with white balance fine-tuning)
- **OSC integration** — receive commands from external systems over UDP and broadcast live status (online/offline/warning counts)
- **Persistent projects** — save, load, and reopen workspace layouts with projector positions

## Protocol

Communicates over raw TCP using the Panasonic NTCONTROL protocol with MD5 authentication. Each command opens a dedicated socket connection. Default port: 1024.
