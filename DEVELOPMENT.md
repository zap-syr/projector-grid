# Development Guide

This document covers how to set up the development environment, understand the codebase, and contribute to Projector Grid.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) - stable channel (requires Dart SDK `^3.11.1`, bundled with Flutter)
- A desktop target: Windows or macOS

Verify your setup:

```bash
flutter doctor
```

## Getting Started

```bash
# Clone the repository
git clone https://github.com/zap-syr/projector-grid.git
cd projector-grid

# Install dependencies
flutter pub get

# Run code generation (required on first clone)
dart run build_runner build

# Run the app in debug mode
flutter run -d windows   # or macos
```

## Project Structure

```
lib/
├── main.dart                        # Window setup + ProviderScope
├── app/app.dart                     # MyApp widget (theme + root screen)
├── core/
│   ├── docs/
│   │   └── osc_reference_html.dart  # Embedded OSC reference HTML
│   ├── services/
│   │   ├── panasonic_protocol_service.dart   # NTCONTROL TCP protocol
│   │   ├── osc_service.dart                  # OSC command mapping
│   │   └── docs_service.dart                 # Writes OSC reference to config dir
│   └── theme/app_theme.dart                  # Material 3 light/dark themes
└── features/workspace/
    ├── domain/
    │   ├── projector_node.dart      # Freezed - 21-field model (telemetry, position, status)
    │   ├── projector_group.dart     # Freezed - group name, color + OSC address
    │   └── custom_command.dart      # Plain Dart class - user-defined commands
    └── presentation/
        ├── providers/               # Riverpod state (Notifier-based, codegen)
        ├── screens/                 # main_workspace_screen.dart
        └── widgets/                 # widget files
```

## Architecture Overview

### State Management

All state uses Riverpod (`flutter_riverpod` + `riverpod_annotation`). Providers use the `@riverpod` codegen annotation - each provider class extends a generated `_$ClassName` base and has a corresponding `.g.dart` file. **Never edit `.g.dart` files directly.**

Key providers:

| Provider | Responsibility |
|---|---|
| `workspaceProvider` | Projector node list, group assignments, undo/redo stack, polling timers |
| `projectStateProvider` | Current file path, dirty flag, recent projects list |
| `appSettingsProvider` | Theme mode, polling interval, OSC port/enabled |
| `oscProvider` | OSC UDP server/client lifecycle |
| `customCommandsProvider` | User-defined commands with auto-generated OSC slugs |

### Data Models

`ProjectorNode` and `ProjectorGroup` are Freezed immutable classes. When adding fields to either:

1. Edit the `.dart` source file.
2. Regenerate with `dart run build_runner build`.
3. Never touch the generated `.freezed.dart` files.

`CustomCommand` is a plain Dart class (no Freezed) with manual `toJson`/`fromJson`. Extend it directly without running code generation.

### Network Protocols

**NTCONTROL** (`panasonic_protocol_service.dart`): TCP socket per projector. Authentication uses an MD5 hash of a challenge token. Commands are plain-text strings (`PON` = power on, `OSH:1` = shutter close).

**OSC** (`osc_service.dart`): UDP-based. Receives commands on a configurable port and maps OSC addresses to projector actions. Custom commands produce slugs like `/pgrid/custom/dynamic-contrast`. The service also broadcasts projector status outbound (`/pgrid/status/online`, `/pgrid/status/offline`, `/pgrid/status/warning`) to a configurable send IP and port whenever status changes.

### Persistence

Project state is saved as JSON in the platform config directory:

- Windows: `%APPDATA%\ProjectorGrid\`
- macOS: `~/Library/Application Support/ProjectorGrid/`

## Development Workflow

### Code Generation

Riverpod and Freezed both require code generation. Run this after any change to files that contain `@riverpod` or `@freezed` annotations:

```bash
dart run build_runner build
```

During active development, use watch mode to regenerate automatically:

```bash
dart run build_runner watch
```

### Linting and Analysis

The project uses `flutter_lints`. Run the analyzer before committing:

```bash
flutter analyze
```

### Formatting

Format all Dart files with:

```bash
dart format .
```

### Running Tests

```bash
flutter test
```

## Building for Release

```bash
flutter build windows --release
flutter build macos --release
```

Releases are automated via GitHub Actions (`.github/workflows/release.yml`). Pushing a tag in `v*.*.*` format triggers a build for Windows and macOS and creates a GitHub Release with the installer and DMG attached.

## Contributing

All contributions are welcome - bug reports, feature requests, and code changes.

Before opening a pull request, please open an issue first to discuss the change. This avoids duplicate effort and keeps the scope of PRs focused.

### PR Checklist

For new PRs, please go through the following checklist:

- [ ] `flutter analyze` reports no issues.
- [ ] `dart format .` has been run and all changed files are formatted.
- [ ] The branch is clean: commits are logically separated and have descriptive messages.
- [ ] The PR body describes what changed and why.

Once the checklist is complete, request a review from one of the maintainers. We will review as soon as possible.

### Commit Style

Use short, imperative subject lines that describe the change:

```
feat: add lens-shift preset saving
fix: reconnect after TCP timeout
refactor: extract polling logic into separate class
```

Common prefixes: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.

### Code Conventions

- Follow Dart/Flutter idioms and the rules enforced by `flutter_lints`.
- Keep providers and widgets focused - one responsibility per file.
- Use Freezed for `ProjectorNode` and `ProjectorGroup`; other state classes (`AppSettings`, `ProjectState`, `CustomCommand`) are plain Dart. Do not mutate state directly in either case.
- Do not add fallback handling or validation for cases that cannot occur at runtime.
- Comments should explain *why*, not *what* - well-named identifiers already do that.
