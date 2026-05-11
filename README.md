[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0) [![Gumroad](https://img.shields.io/badge/GUMROAD-36a9ae?style=for-the-badge&logo=gumroad&logoColor=white)](https://projectorhub.gumroad.com/l/projectorgrid)

# Projector Grid

Projector Grid is a desktop application for controlling and monitoring multiple Panasonic projectors over a local network.

With Projector Grid, you can manage an entire projector rig from one place - monitor live status, send commands, adjust image settings, and automate your workflow through OSC integration.

## Download the latest release

- [Download for Windows](https://github.com/zap-syr/projector-grid/releases/latest/download/ProjectorGrid_Setup.exe)
- [Download for macOS (Universal)](https://github.com/zap-syr/projector-grid/releases/latest/download/ProjectorGrid-macOS.dmg)

## Main features

- **Multi-projector workspace** - an infinite canvas where projectors are represented as draggable cards. Arrange them to match your physical setup, select multiple at once, and send commands to the whole rig in a click.

- **Real-time monitoring** - a live table view showing power state, shutter, input, temperatures, runtime, voltage, and errors for every projector at a glance.

- **Group control** - organize projectors into named groups and target commands at a group or all projectors simultaneously.

- **Full control panel** - power, shutter, OSD, input selection, lens shift, focus, zoom, test patterns, picture modes, and other system settings - all in one panel.

- **Brightness and color** - adjust light output with operating mode profiles (Normal/Eco/Quiet/User), fine-tune color matching (3-color, 7-color), and dial in color temperature with white balance controls.

- **Geometry correction** - correct image distortion with keystone, curved, and corner correction modes. Corner mode offers an interactive canvas with draggable handles and arrow-key fine-tuning. Includes linearity and pincushion.

- **OSC integration** - receive commands from show control systems over UDP and broadcast live projector status back. Works with any OSC-capable tool (Qlab, TouchDesigner, Resolume, etc.).

- **Persistent projects** - save and reopen workspace layouts, with undo/redo, dirty tracking, and a recent projects list.

- **Auto-discovery** - scan your local subnet to find projectors automatically without entering IPs manually.

![Control Window](https://github.com/zap-syr/projector-grid/blob/main/.github/aux-images/control.png)

![App Overview](https://github.com/zap-syr/projector-grid/blob/main/.github/aux-images/app-overview.png)

## Contributing

All contributions are welcome - bug reports, feature requests, or code.

If you'd like to contribute code, please open an issue to discuss before submitting a pull request.

Information about the project setup can be found in the [development documentation](./DEVELOPMENT.md)

## Issues

Found a bug, have a feature request, or noticed that a command doesn't work on your projector model? [Open an issue](https://github.com/zap-syr/projector-grid/issues/new). Most commands are shared across Panasonic projector models, so model-specific compatibility reports are especially welcome.

## License

This project is licensed under the terms of the GNU GPL v3.
